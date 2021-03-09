# Copyright 2019 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load("@rules_cc//cc:action_names.bzl", "CPP_COMPILE_ACTION_NAME")
load("@rules_cc//cc:toolchain_utils.bzl", "find_cpp_toolchain")
load("//cc_module/private:provider.bzl", "ModuleCompileInfo")


def replace_extension(f, new_ext):
  ext = f.extension
  return f.basename[:-len(ext)]  + new_ext

def cc_module_compile_action(ctx, src, compilation_context, module_out=None):
    cc_toolchain = find_cpp_toolchain(ctx)

    obj = ctx.actions.declare_file(replace_extension(src, "o"))

    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    c_compiler_path = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = CPP_COMPILE_ACTION_NAME,
    )
    cc = compilation_context.compilation_context
    c_compile_variables = cc_common.create_compile_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        user_compile_flags = ctx.fragments.cpp.copts + ctx.fragments.cpp.conlyopts + ["-fmodules-ts", "-std=c++20"],
        include_directories = cc.includes,
        quote_include_directories = cc.quote_includes,
        system_include_directories = cc.system_includes,
        source_file = src.path,
        output_file = obj.path,
    )
    command_line = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = CPP_COMPILE_ACTION_NAME,
        variables = c_compile_variables,
    )
    command_line = command_line + ["-fmodule-mapper=%s" % compilation_context.module_mapper.path]
    command_line += ["-iquote", "."]

    env = cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = CPP_COMPILE_ACTION_NAME,
        variables = c_compile_variables,
    )

    copy_files = []
    outputs = [obj]
    if module_out:
      outputs.append(module_out.module_file)


    ctx.actions.run(
        executable = ctx.executable._process_wrapper,
        arguments = copy_files + ["--", c_compiler_path] + command_line,
        env = env,
        inputs = depset(
            [src],
            transitive = [compilation_context.module_inputs, cc_toolchain.all_files],
        ),
        outputs = outputs,
    )
    return [obj]

def cc_header_module_compile_action(ctx, src, compilation_context, module_out):
    cc_toolchain = find_cpp_toolchain(ctx)

    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    c_compiler_path = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = CPP_COMPILE_ACTION_NAME,
    )
    cc = compilation_context.compilation_context
    c_compile_variables = cc_common.create_compile_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        user_compile_flags = ctx.fragments.cpp.copts + ctx.fragments.cpp.conlyopts + \
            ["-x", "c++-header", "-fmodules-ts", "-std=c++20"],
        include_directories = cc.includes,
        quote_include_directories = cc.quote_includes,
        system_include_directories = cc.system_includes,
        source_file = src.path,
    )
    command_line = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = CPP_COMPILE_ACTION_NAME,
        variables = c_compile_variables,
    )
    command_line = command_line + ["-fmodule-mapper=%s" % compilation_context.module_mapper.path]
    command_line += ["-iquote", "."]

    env = cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = CPP_COMPILE_ACTION_NAME,
        variables = c_compile_variables,
    )

    outputs = [module_out.module_file]

    ctx.actions.run(
        executable = ctx.executable._process_wrapper,
        arguments = ["--", c_compiler_path] + command_line,
        env = env,
        inputs = depset(
            [src],
            transitive = [compilation_context.module_inputs, cc_toolchain.all_files],
        ),
        outputs = outputs,
    )
