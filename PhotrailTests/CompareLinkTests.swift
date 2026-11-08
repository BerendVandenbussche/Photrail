import XCTest
@testable import Photrail

/// The compare link carries someone's countries in its fragment; it comes from outside the
/// app, so parsing has to be strict.
final class CompareLinkTests: XCTestCase {

    func testRoundTrip() {
        let payload = ComparePayload(name: "Berend", emoji: "🦊", countryCodes: ["BE", "FR", "JP"])
        let url = CompareLink.url(for: payload)
        XCTAssertTrue(url.absoluteString.hasPrefix("https://\(CompareLink.host)/compare/#"),
                      "trailing slash, so the website doesn't redirect")
        XCTAssertNil(url.query, "the data belongs in the fragment, never the query")
        XCTAssertEqual(CompareLink.parse(url), payload)
    }

    func testLinkWithoutTrailingSlashStillParses() {
        let url = URL(string: "https://\(CompareLink.host)/compare#v=1&e=x&c=BE")!
        XCTAssertEqual(CompareLink.parse(url)?.countryCodes, ["BE"])
    }

    func testAppSchemeLinkParses() {
        let url = URL(string: "photrail://compare/#v=1&e=%F0%9F%A6%8A&n=Anne&c=BEFR")!
        let parsed = CompareLink.parse(url)
        XCTAssertEqual(parsed?.name, "Anne")
        XCTAssertEqual(parsed?.countryCodes, ["BE", "FR"])
    }

    func testOtherAppSchemeHostIsRejected() {
        XCTAssertNil(CompareLink.parse(URL(string: "photrail://trip/#v=1&e=x&c=BE")!))
        XCTAssertNil(CompareLink.parse(URL(string: "http://\(CompareLink.host)/compare/#v=1&e=x&c=BE")!),
                     "plain http isn't ours")
    }

    func testNameWithReservedCharactersSurvives() {
        let payload = ComparePayload(name: "Anne & Tom = 2+1 ü", emoji: "👩‍👩‍👧", countryCodes: ["NL"])
        XCTAssertEqual(CompareLink.parse(CompareLink.url(for: payload)), payload)
    }

    func testUnknownCodesAreDropped() {
        let parsed = CompareLink.parse(fragment: "v=1&e=x&c=BEZZFR")
        XCTAssertEqual(parsed?.countryCodes, ["BE", "FR"])
    }

    func testLowercaseCodesAreAccepted() {
        XCTAssertEqual(CompareLink.parse(fragment: "v=1&e=x&c=befr")?.countryCodes, ["BE", "FR"])
    }

    func testNameIsCapped() {
        let long = String(repeating: "a", count: 200)
        let parsed = CompareLink.parse(fragment: "v=1&e=x&n=\(long)&c=BE")
        XCTAssertEqual(parsed?.name?.count, CompareLink.maxNameLength)
    }

    func testEmojiIsOneCharacter() {
        XCTAssertEqual(CompareLink.parse(fragment: "v=1&e=hello&c=BE")?.emoji, "h")
    }

    func testInvalidInputGivesNil() {
        XCTAssertNil(CompareLink.parse(fragment: "garbage"))
        XCTAssertNil(CompareLink.parse(fragment: "v=1&e=x&c=ZZ"), "no known country")
        XCTAssertNil(CompareLink.parse(fragment: "v=2&e=x&c=BE"), "unknown version")
        XCTAssertNil(CompareLink.parse(URL(string: "https://example.com/compare#v=1&c=BE")!),
                     "another host")
    }

    func testEmptyNameIsNil() {
        XCTAssertNil(CompareLink.parse(fragment: "v=1&e=x&n=%20%20&c=BE")?.name)
    }
}
