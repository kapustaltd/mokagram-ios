load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# The mokaGram settings screen, drawn from the MokoCore registry.
swift_library(
    name = "MokoSettingsUI",
    module_name = "MokoSettingsUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Moko/MokoCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/Display:Display",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/LegacyMediaPickerUI:LegacyMediaPickerUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/UndoUI:UndoUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
