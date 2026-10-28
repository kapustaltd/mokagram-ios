load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# The send-time offer to download a lone link through Saveinator, its progress toast and the
# hand-off of the downloaded files to the normal media send path.
swift_library(
    name = "MokoSaveinatorUI",
    module_name = "MokoSaveinatorUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Moko/MokoCore",
        "//submodules/Moko/MokoSaveinator",
        "//submodules/Moko/MokoSettingsUI",
        "//submodules/AccountContext:AccountContext",
        "//submodules/Display:Display",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/UndoUI:UndoUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
