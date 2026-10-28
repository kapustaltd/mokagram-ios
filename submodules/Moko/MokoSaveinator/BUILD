load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library", "swift_test")

# Saveinator API client: turns a link to a supported service into downloaded media files.
# Ported from Desktop Telegram/SourceFiles/mokagram/saveinator/. No UI.
swift_library(
    name = "MokoSaveinator",
    module_name = "MokoSaveinator",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Moko/MokoCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)

# Host (macOS) test. Run with
# `./build-input/bazel-9.2.0-darwin-arm64 test //submodules/Moko/MokoSaveinator:MokoSaveinatorTests --test_output=errors`.
swift_test(
    name = "MokoSaveinatorTests",
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        ":MokoSaveinator",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Moko/MokoCore",
    ],
)
