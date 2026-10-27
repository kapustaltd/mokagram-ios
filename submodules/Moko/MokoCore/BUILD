load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library", "swift_test")

# Foundation-only core of mokaGram: app-group storage, the settings registry, .mokaset files and
# the string table. Shared by TelegramCore, the app and its extensions.
swift_library(
    name = "MokoCore",
    module_name = "MokoCore",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)

# Host (macOS) test. Run with
# `./build-input/bazel-9.2.0-darwin-arm64 test //submodules/Moko/MokoCore:MokoCoreTests --test_output=errors`.
swift_test(
    name = "MokoCoreTests",
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    data = glob([
        "Tests/Fixtures/**",
    ], allow_empty = True),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        ":MokoCore",
        "//submodules/SSignalKit/SwiftSignalKit",
    ],
)
