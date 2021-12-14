"""Defines buf_lint_test rule"""

load("@rules_proto//proto:defs.bzl", "ProtoInfo")
load(":common.bzl", "protoc_plugin_test")

BufLintInfo = provider(
    fields = {
        "error_file": "File containing lint errors",
    },
)

_TOOLCHAIN = str(Label("//tools/protoc-gen-buf-lint:toolchain_type"))

def _buf_lint_aspect_impl(target, ctx):
    if ctx.rule.kind == "proto_library":
        proto_info = target[ProtoInfo]

        args = ctx.actions.args()

        args.add_joined(
            ["--plugin", "protoc-gen-buf-lint", ctx.toolchains[_TOOLCHAIN].cli],
            join_with = "=",
        )
        args.add_all(
            ["--descriptor_set_in"],
        )
        descriptor_sets = proto_info.transitive_descriptor_sets.to_list()
        descriptor_sets.append(proto_info.direct_descriptor_set)
        args.add_joined(
            descriptor_sets,
            join_with = ":",
        )

        args.add("--buf-lint_out=.")
        args.add_all(proto_info.direct_sources)
        out = ctx.actions.declare_file("lint.txt")

        inputs = [ctx.toolchains[_TOOLCHAIN].cli] + descriptor_sets

        ctx.actions.run(
            outputs = [out],
            inputs = inputs,
            executable = ctx.executable._protoc,
            arguments = [args],
        )

        return [
            BufLintInfo(
                error_file = out,
            ),
        ]

    return [BufLintInfo(error_file = "")]

buf_lint_aspect = aspect(
    implementation = _buf_lint_aspect_impl,
    attr_aspects = ["deps"],
    attrs = {
        "_protoc": attr.label(
            default = "@com_github_protocolbuffers_protobuf//:protoc",
            executable = True,
            cfg = "exec",
        ),
    },
    toolchains = [_TOOLCHAIN],
)

def _buf_lint_rule_impl(ctx):
    files = []
    for dep in ctx.attr.deps:
        files.append(dep[BufLintInfo].error_file)

    return DefaultInfo(
        files = depset(files),
    )

buf_lint_rule = rule(
    implementation = _buf_lint_rule_impl,
    attrs = {
        "deps": attr.label_list(
            aspects = [buf_lint_aspect],
            providers = [ProtoInfo],
            mandatory = True,
        ),
    },
)

def _buf_lint_test_impl(ctx):
    proto_infos = [t[ProtoInfo] for t in ctx.attr.targets]
    config = json.encode({
        "input_config": {
            "version": "v1",
            "lint": {
                "use": ctx.attr.use_rules,
                "except": ctx.attr.except_rules,
                "enum_zero_value_suffix": ctx.attr.enum_zero_value_suffix,
                "allow_comment_ignores": ctx.attr.allow_comment_ignores,
                "rpc_allow_same_request_response": ctx.attr.rpc_allow_same_request_response,
                "rpc_allow_google_protobuf_empty_requests": ctx.attr.rpc_allow_google_protobuf_empty_requests,
                "rpc_allow_google_protobuf_empty_responses": ctx.attr.rpc_allow_google_protobuf_empty_responses,
                "service_suffix": ctx.attr.service_suffix,
                "ignore": ctx.attr.ignore,
                "ignore_only": ctx.attr.ignore_only,
            },
        },
    })

    return protoc_plugin_test(ctx, proto_infos, ctx.executable._protoc, ctx.toolchains[_TOOLCHAIN].cli, config)

buf_lint_test = rule(
    implementation = _buf_lint_test_impl,
    doc = """
This lints protocol buffers using `buf lint`. For an overview of linting using buf please refer: https://docs.buf.build/lint/overview.

Example:
    This rule works alongside `proto_library` rule.

    load("@rules_buf//buf:defs.bzl", "buf_lint_test")
    load("@rules_proto//proto:defs.bzl", "proto_library")

    proto_library(
        name = "foo_proto",
        srcs = ["pet.proto"],
        deps = ["@go_googleapis//google/type:datetime_proto"],
    )

    buf_lint_test(
        name = "foo_proto_lint",
        except_rules = [
            "PACKAGE_VERSION_SUFFIX",
            "FIELD_LOWER_SNAKE_CASE",
        ],
        targets = [":foo_proto"],
        use_rules = ["DEFAULT"],
    )
    
    """,
    attrs = {
        "_protoc": attr.label(
            default = "@com_github_protocolbuffers_protobuf//:protoc",
            executable = True,
            cfg = "exec",
        ),
        "targets": attr.label_list(
            providers = [ProtoInfo],
            mandatory = True,
            doc = "`proto_library` targets that should be linted",
        ),
        # buf config attrs
        "use_rules": attr.string_list(
            default = ["DEFAULT"],
            doc = "https://docs.buf.build/lint/configuration#use",
        ),
        "except_rules": attr.string_list(
            default = [],
            doc = "https://docs.buf.build/lint/configuration#except",
        ),
        "allow_comment_ignores": attr.bool(
            default = True,
            doc = "https://docs.buf.build/lint/configuration#allow_comment_ignores",
        ),
        "enum_zero_value_suffix": attr.string(
            default = "_UNSPECIFIED",
            doc = "https://docs.buf.build/lint/configuration#enum_zero_value_suffix",
        ),
        "rpc_allow_same_request_response": attr.bool(
            doc = "https://docs.buf.build/lint/configuration#rpc_allow_",
        ),
        "rpc_allow_google_protobuf_empty_requests": attr.bool(
            doc = "https://docs.buf.build/lint/configuration#rpc_allow_",
        ),
        "rpc_allow_google_protobuf_empty_responses": attr.bool(
            doc = "https://docs.buf.build/lint/configuration#rpc_allow_",
        ),
        "service_suffix": attr.string(
            default = "Service",
            doc = "https://docs.buf.build/lint/configuration#service_suffix",
        ),
        "ignore": attr.string_list(
            default = [],
            doc = "https://docs.buf.build/lint/configuration#ignore",
        ),
        "ignore_only": attr.string_list_dict(
            doc = "https://docs.buf.build/lint/configuration#ignore_only",
        ),
    },
    toolchains = [_TOOLCHAIN],
    test = True,
)