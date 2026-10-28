load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MusicAlbumArtResources",
    module_name = "MusicAlbumArtResources",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
    	"//submodules/TelegramCore:TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/UrlEscaping:UrlEscaping",
        "//submodules/Moko/MokoCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
