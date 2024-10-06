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

load("@@rules_cc+//cc:action_names.bzl", "CPP_LINK_EXECUTABLE_ACTION_NAME")
load("@@rules_cc+//cc:toolchain_utils.bzl", "find_cpp_toolchain")

def get_linker_and_args(ctx, cc_toolchain, feature_configuration, rpaths, output_file):
    user_link_flags = ctx.fragments.cpp.linkopts
    link_variables = cc_common.create_link_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        is_linking_dynamic_library = False,
        runtime_library_search_directories = rpaths,
        user_link_flags = user_link_flags,
        output_file = output_file,
    )
    link_args = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = CPP_LINK_EXECUTABLE_ACTION_NAME,
        variables = link_variables,
    )
    link_env = cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = CPP_LINK_EXECUTABLE_ACTION_NAME,
        variables = link_variables,
    )
    ld = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = CPP_LINK_EXECUTABLE_ACTION_NAME,
    )

    return ld, link_args, link_env

def cc_module_link_action(ctx, objs, linking_context, exe):
    cc_toolchain = find_cpp_toolchain(ctx)

    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    compilation_outputs = cc_common.create_compilation_outputs(
        objects = depset(objs),
    )

    ld, link_args, link_env = get_linker_and_args(ctx, cc_toolchain, feature_configuration, 
                                                  depset(), exe.path)

    linkopts = getattr(ctx.attr, "linkopts", [])

    args = ctx.actions.args()
    args.add_all(link_args)
    args.add_all(linkopts)
    args.add_all(objs)
    
    inputs = []
    for linker_inputs in linking_context.linker_inputs.to_list():
      for lib in linker_inputs.libraries:
        if lib.static_library:
          args.add(lib.static_library)
          inputs.append(lib.static_library)
        if lib.objects:
          args.add(lib.objects)
          inputs += lib.objects
      args.add_all(linker_inputs.user_link_flags)

    ctx.actions.run(
        executable = ld,
        arguments = [args],
        env = link_env,
        use_default_shell_env = True,
        inputs = depset(
            direct = objs + inputs,
            transitive = [cc_toolchain.all_files],
        ),
        outputs = [exe],
    )
