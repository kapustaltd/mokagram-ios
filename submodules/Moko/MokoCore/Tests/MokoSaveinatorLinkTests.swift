import Foundation
import XCTest
import MokoCore

final class MokoSaveinatorLinkTests: XCTestCase {
    func testSupportedHostsAndSubdomains() {
        for host in ["youtube.com", "m.youtube.com", "youtu.be", "www.tiktok.com", "vm.tiktok.com", "x.com", "twitter.com", "instagram.com", "instagr.am", "old.reddit.com", "redd.it", "pin.it", "open.spotify.com", "soundcloud.com", "on.soundcloud.com", "vk.com", "vk.ru", "vkontakte.ru", "twitch.tv", "clips.twitch.tv", "music.yandex.ru", "music.yandex.com", "pinterest.com", "pinterest.co.uk", "ru.pinterest.com"] {
            XCTAssertTrue(MokoSaveinatorLink.isSupportedHost(host), host)
        }
    }

    func testUnsupportedHosts() {
        for host in ["example.com", "notyoutube.com", "youtube.com.evil.org", "evilx.com", "yandex.ru", "music.example.com", ""] {
            XCTAssertFalse(MokoSaveinatorLink.isSupportedHost(host), host)
        }
    }

    func testNormalizedAddsSchemeAndKeepsLink() {
        XCTAssertEqual(MokoSaveinatorLink.normalized("https://youtu.be/xyz"), "https://youtu.be/xyz")
        XCTAssertEqual(MokoSaveinatorLink.normalized("youtu.be/xyz"), "https://youtu.be/xyz")
        XCTAssertEqual(MokoSaveinatorLink.normalized("http://m.youtube.com/watch?v=1"), "http://m.youtube.com/watch?v=1")
    }

    func testNormalizedDropsTrailingPunctuation() {
        XCTAssertEqual(MokoSaveinatorLink.normalized("https://youtu.be/xyz."), "https://youtu.be/xyz")
        XCTAssertEqual(MokoSaveinatorLink.normalized("https://youtu.be/xyz)!?"), "https://youtu.be/xyz")
    }

    func testNormalizedRejects() {
        XCTAssertNil(MokoSaveinatorLink.normalized(""))
        XCTAssertNil(MokoSaveinatorLink.normalized("..."))
        XCTAssertNil(MokoSaveinatorLink.normalized("https://example.com/video"))
        XCTAssertNil(MokoSaveinatorLink.normalized("ftp://youtube.com/video"))
        XCTAssertNil(MokoSaveinatorLink.normalized("hello"))
    }

    func testLoneLink() {
        XCTAssertEqual(MokoSaveinatorLink.loneLink(in: "  https://youtu.be/xyz\n"), "https://youtu.be/xyz")
        XCTAssertNil(MokoSaveinatorLink.loneLink(in: "смотри https://youtu.be/xyz"))
        XCTAssertNil(MokoSaveinatorLink.loneLink(in: "https://youtu.be/xyz https://youtu.be/abc"))
        XCTAssertNil(MokoSaveinatorLink.loneLink(in: "https://example.com/x"))
        XCTAssertNil(MokoSaveinatorLink.loneLink(in: "   "))
    }

    func testPlatformAndMedia() {
        XCTAssertEqual(MokoSaveinatorLink.platform(host: "m.youtube.com"), .youtube)
        XCTAssertEqual(MokoSaveinatorLink.platform(host: "music.yandex.ru"), .yandexMusic)
        XCTAssertNil(MokoSaveinatorLink.platform(host: "example.com"))
        XCTAssertEqual(MokoSaveinatorLink.availableMedia(for: "https://youtu.be/x"), [1, 2])
        XCTAssertEqual(MokoSaveinatorLink.availableMedia(for: "https://open.spotify.com/track/1"), [2])
        XCTAssertEqual(MokoSaveinatorLink.availableMedia(for: "https://vk.com/audio1_2"), [2])
        XCTAssertEqual(MokoSaveinatorLink.availableMedia(for: "https://vk.com/video1_2"), [1, 2])
        XCTAssertEqual(MokoSaveinatorLink.availableMedia(for: "https://www.instagram.com/p/x"), [0, 1, 2, 3])
    }

    func testChoice() {
        XCTAssertEqual(MokoSaveinatorChoice.make(media: 0, quality: 0), MokoSaveinatorChoice(media: "auto", maxHeight: 0))
        XCTAssertEqual(MokoSaveinatorChoice.make(media: 1, quality: 2), MokoSaveinatorChoice(media: "video", maxHeight: 720))
        XCTAssertEqual(MokoSaveinatorChoice.make(media: 2, quality: 2), MokoSaveinatorChoice(media: "audio", maxHeight: 0))
        XCTAssertEqual(MokoSaveinatorChoice.make(media: 9, quality: 9), MokoSaveinatorChoice(media: "photos", maxHeight: 0))
    }

    func testSettingDefaultsOn() {
        let entry = MokoBuiltinSettings.entries.first { $0.key == "saveinator.enabled" }
        XCTAssertEqual(entry?.defaultValue, .bool(true))
    }
}
