load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library", "swift_test")

# mokaGram music without UI: SoundCloud client, downloader, lyrics, library and queue.
# Ported from Desktop Telegram/SourceFiles/mokagram/music/.
swift_library(
    name = "MokoMusic",
    module_name = "MokoMusic",
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
# `./build-input/bazel-9.2.0-darwin-arm64 test //submodules/Moko/MokoMusic:MokoMusicTests --test_output=errors`.
swift_test(
    name = "MokoMusicTests",
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    data = glob([
        "Tests/Fixtures/**",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        ":MokoMusic",
        "//submodules/SSignalKit/SwiftSignalKit",
    ],
)
