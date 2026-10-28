load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# mokaGram music screens and the SoundCloud playlist for the app's media player.
swift_library(
    name = "MokoMusicUI",
    module_name = "MokoMusicUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Moko/MokoCore",
        "//submodules/Moko/MokoMusic",
        "//submodules/Moko/MokoSettingsUI",
        "//submodules/AccountContext:AccountContext",
        "//submodules/Display:Display",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/MediaPlayer:UniversalMediaPlayer",
        "//submodules/MusicAlbumArtResources:MusicAlbumArtResources",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/UndoUI:UndoUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
