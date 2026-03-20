import XCTest
@testable import MyDynamicIsland

final class YouTubeURLParserTests: XCTestCase {

    // MARK: - extractVideoID

    func testStandardWatchURL() {
        let result = YouTubeURLParser.extractVideoID(from: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        XCTAssertEqual(result, "dQw4w9WgXcQ")
    }

    func testStandardWatchURLWithExtraParams() {
        let result = YouTubeURLParser.extractVideoID(from: "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=30&list=PLxxx")
        XCTAssertEqual(result, "dQw4w9WgXcQ")
    }

    func testShortURL() {
        let result = YouTubeURLParser.extractVideoID(from: "https://youtu.be/dQw4w9WgXcQ")
        XCTAssertEqual(result, "dQw4w9WgXcQ")
    }

    func testShortURLWithStartTime() {
        let result = YouTubeURLParser.extractVideoID(from: "https://youtu.be/dQw4w9WgXcQ?t=42")
        XCTAssertEqual(result, "dQw4w9WgXcQ")
    }

    func testEmbedURL() {
        let result = YouTubeURLParser.extractVideoID(from: "https://www.youtube.com/embed/dQw4w9WgXcQ")
        XCTAssertEqual(result, "dQw4w9WgXcQ")
    }

    func testShortsURL() {
        let result = YouTubeURLParser.extractVideoID(from: "https://youtube.com/shorts/dQw4w9WgXcQ")
        XCTAssertEqual(result, "dQw4w9WgXcQ")
    }

    func testLiveURL() {
        let result = YouTubeURLParser.extractVideoID(from: "https://youtube.com/live/dQw4w9WgXcQ")
        XCTAssertEqual(result, "dQw4w9WgXcQ")
    }

    func testMusicYouTubeURL() {
        let result = YouTubeURLParser.extractVideoID(from: "https://music.youtube.com/watch?v=dQw4w9WgXcQ")
        XCTAssertEqual(result, "dQw4w9WgXcQ")
    }

    func testNocookieEmbedURL() {
        let result = YouTubeURLParser.extractVideoID(from: "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ")
        XCTAssertEqual(result, "dQw4w9WgXcQ")
    }

    func testRaw11CharID() {
        let result = YouTubeURLParser.extractVideoID(from: "dQw4w9WgXcQ")
        XCTAssertEqual(result, "dQw4w9WgXcQ")
    }

    func testIDWithUnderscoreAndDash() {
        let result = YouTubeURLParser.extractVideoID(from: "_test-ID123")
        XCTAssertEqual(result, "_test-ID123")
    }

    func testInvalidURL() {
        XCTAssertNil(YouTubeURLParser.extractVideoID(from: "not a url"))
    }

    func testEmptyString() {
        XCTAssertNil(YouTubeURLParser.extractVideoID(from: ""))
    }

    func testTooShortID() {
        XCTAssertNil(YouTubeURLParser.extractVideoID(from: "abc"))
    }

    func testTooLongID() {
        XCTAssertNil(YouTubeURLParser.extractVideoID(from: "dQw4w9WgXcQtoolong"))
    }

    func testNonYouTubeDomain() {
        XCTAssertNil(YouTubeURLParser.extractVideoID(from: "https://vimeo.com/dQw4w9WgXcQ"))
    }

    func testWhitespaceTrimed() {
        let result = YouTubeURLParser.extractVideoID(from: "  https://youtu.be/dQw4w9WgXcQ  ")
        XCTAssertEqual(result, "dQw4w9WgXcQ")
    }

    // MARK: - isValidVideoID

    func testValidVideoID() {
        XCTAssertTrue(YouTubeURLParser.isValidVideoID("dQw4w9WgXcQ"))
    }

    func testValidVideoIDWithSpecialChars() {
        XCTAssertTrue(YouTubeURLParser.isValidVideoID("_test-ID123"))
    }

    func testInvalidVideoIDTooShort() {
        XCTAssertFalse(YouTubeURLParser.isValidVideoID("bad"))
    }

    func testInvalidVideoIDTooLong() {
        XCTAssertFalse(YouTubeURLParser.isValidVideoID("dQw4w9WgXcQextra"))
    }

    func testInvalidVideoIDWithSpaces() {
        XCTAssertFalse(YouTubeURLParser.isValidVideoID("dQw4 9WgXcQ"))
    }

    func testEmptyVideoID() {
        XCTAssertFalse(YouTubeURLParser.isValidVideoID(""))
    }

    // MARK: - youtubeURL / embedURL

    func testYouTubeURLGeneration() {
        let url = YouTubeURLParser.youtubeURL(for: "dQw4w9WgXcQ")
        XCTAssertEqual(url?.absoluteString, "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    }

    func testEmbedURLGeneration() {
        let url = YouTubeURLParser.embedURL(for: "dQw4w9WgXcQ")
        XCTAssertEqual(url?.absoluteString, "https://www.youtube.com/embed/dQw4w9WgXcQ")
    }

    func testURLGenerationInvalidID() {
        XCTAssertNil(YouTubeURLParser.youtubeURL(for: "bad"))
        XCTAssertNil(YouTubeURLParser.embedURL(for: "bad"))
    }

    // MARK: - extractStartTime

    func testStartTimeSeconds() {
        let t = YouTubeURLParser.extractStartTime(from: "https://youtu.be/dQw4w9WgXcQ?t=90")
        XCTAssertEqual(t, 90)
    }

    func testStartTimeHoursMinutesSeconds() {
        let t = YouTubeURLParser.extractStartTime(from: "https://youtu.be/dQw4w9WgXcQ?t=1h2m3s")
        XCTAssertEqual(t, 3723) // 3600 + 120 + 3
    }

    func testStartTimeMinutesOnly() {
        let t = YouTubeURLParser.extractStartTime(from: "https://youtu.be/dQw4w9WgXcQ?t=5m30s")
        XCTAssertEqual(t, 330) // 300 + 30
    }

    func testStartParamAlias() {
        let t = YouTubeURLParser.extractStartTime(from: "https://www.youtube.com/watch?v=dQw4w9WgXcQ&start=45")
        XCTAssertEqual(t, 45)
    }

    func testNoStartTime() {
        let t = YouTubeURLParser.extractStartTime(from: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        XCTAssertNil(t)
    }

    func testZeroStartTime() {
        let t = YouTubeURLParser.extractStartTime(from: "https://youtu.be/dQw4w9WgXcQ?t=0")
        XCTAssertNil(t) // 0 is treated as "no start time"
    }

    // MARK: - PlaybackRequest

    func testPlaybackRequestFromWatchURLIncludesStartTimeAndCanonicalURL() {
        let request = YouTubeURLParser.playbackRequest(from: " https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=1m30s ")

        XCTAssertEqual(request?.videoID, "dQw4w9WgXcQ")
        XCTAssertEqual(request?.startTime, 90)
        XCTAssertEqual(request?.canonicalURL?.absoluteString, "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=90")
    }

    func testPlaybackRequestFromRawVideoIDUsesCanonicalWatchURLWithoutStartTime() {
        let request = YouTubeURLParser.playbackRequest(from: "dQw4w9WgXcQ")

        XCTAssertEqual(request?.videoID, "dQw4w9WgXcQ")
        XCTAssertEqual(request?.startTime, 0)
        XCTAssertEqual(request?.canonicalURL?.absoluteString, "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    }

    func testPlaybackRequestReturnsNilForInvalidInput() {
        XCTAssertNil(YouTubeURLParser.playbackRequest(from: "not a youtube url"))
    }

    // MARK: - ParseResult convenience

    func testParseResult() {
        let result = YouTubeURLParser.parse("https://youtu.be/dQw4w9WgXcQ")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.videoID, "dQw4w9WgXcQ")
        XCTAssertNotNil(result?.watchURL)
        XCTAssertNotNil(result?.embedURL)
        XCTAssertNotNil(result?.thumbnailURL)
    }

    func testParseResultInvalid() {
        let result = YouTubeURLParser.parse("not a youtube url")
        XCTAssertNil(result)
    }

    // MARK: - AppBuildVariant feature gates

    func testDirectBuildVariantSupportsAll() {
        // These tests verify feature gate logic; in CI both variants should
        // be reachable. We test the logic itself here.
        let directVariant = AppBuildVariant.direct
        XCTAssertTrue(directVariant.supportsPrivateSystemIntegrations)
        XCTAssertTrue(directVariant.supportsAdvancedMediaControls)
        XCTAssertTrue(directVariant.supportsGlobalKeyboardShortcuts)
        XCTAssertTrue(directVariant.supportsLockScreenIndicators)
        XCTAssertEqual(directVariant.releaseChannelName, "Direct")
    }

    func testAppStoreBuildVariantRestrictsFeatures() {
        let storeVariant = AppBuildVariant.appStore
        XCTAssertFalse(storeVariant.supportsPrivateSystemIntegrations)
        XCTAssertFalse(storeVariant.supportsAdvancedMediaControls)
        XCTAssertFalse(storeVariant.supportsGlobalKeyboardShortcuts)
        XCTAssertFalse(storeVariant.supportsLockScreenIndicators)
        XCTAssertEqual(storeVariant.releaseChannelName, "App Store")
    }
}
