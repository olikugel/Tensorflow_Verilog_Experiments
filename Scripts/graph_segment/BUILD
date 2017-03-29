# Description:
#   Tensorflow C++ inference example for labeling images.

package(default_visibility = ["//tensorflow:internal"])

licenses(["notice"])  # Apache 2.0

exports_files(["LICENSE"])

cc_binary(
    name = "run_graph_parts",
    srcs = [
        "main.cc",
    ],
    linkopts = ["-lm"],
    deps = [
        "//tensorflow/cc:cc_ops",
        "//tensorflow/core:framework_internal",
        "//tensorflow/core:tensorflow",
    ],
)

cc_binary(
    name = "run_full_graph",
    srcs = [
        "main_orig.cc",
    ],
    linkopts = ["-lm"],
    deps = [
        "//tensorflow/cc:cc_ops",
        "//tensorflow/core:framework_internal",
        "//tensorflow/core:tensorflow",
    ],
)

cc_binary(
    name = "analyzer",
    srcs = [
            "analyzer.cc",
    ],
    linkopts = ["-lm"],
    deps = [
        "//tensorflow/cc:cc_ops",
        "//tensorflow/core:framework_internal",
        "//tensorflow/core:tensorflow",
    ],
)

filegroup(
    name = "all_files",
    srcs = glob(
        ["**/*"],
        exclude = [
            "**/METADATA",
            "**/OWNERS",
            "bin/**",
            "gen/**",
        ],
    ),
    visibility = ["//tensorflow:__subpackages__"],
)
