import Foundation
@testable import SwiftyNotes
import Testing

struct UpdateCheckerTests {
    private func fetcher(tag: String, htmlURL: String = "https://github.com/x/y/releases/tag/v1") -> @Sendable () async throws -> GitHubLatestRelease {
        { GitHubLatestRelease(tagName: tag, htmlURL: URL(string: htmlURL)!) }
    }

    @Test
    func `reports up to date when remote tag equals current version`() async throws {
        let checker = UpdateChecker(
            currentVersion: "1.2.3",
            forceUpdateAvailable: false,
            fetchLatestRelease: fetcher(tag: "v1.2.3"),
        )
        let result = await checker.check()
        guard case .upToDate = result else {
            Issue.record("Expected upToDate, got \(result)")
            return
        }
    }

    @Test
    func `reports up to date when remote tag is older than current`() async throws {
        let checker = UpdateChecker(
            currentVersion: "1.5.0",
            forceUpdateAvailable: false,
            fetchLatestRelease: fetcher(tag: "1.4.9"),
        )
        let result = await checker.check()
        guard case .upToDate = result else {
            Issue.record("Expected upToDate, got \(result)")
            return
        }
    }

    @Test
    func `reports updateAvailable when remote tag is strictly newer`() async throws {
        let url = "https://github.com/makoni/swifty-notes-gtk/releases/tag/v1.2.4"
        let checker = UpdateChecker(
            currentVersion: "1.2.3",
            forceUpdateAvailable: false,
            fetchLatestRelease: fetcher(tag: "v1.2.4", htmlURL: url),
        )
        let result = await checker.check()
        guard case let .updateAvailable(version, releaseURL) = result else {
            Issue.record("Expected updateAvailable, got \(result)")
            return
        }
        #expect(version == "1.2.4")
        #expect(releaseURL.absoluteString == url)
    }

    @Test
    func `force flag reports updateAvailable even when current already newer`() async throws {
        let url = "https://github.com/makoni/swifty-notes-gtk/releases/tag/v0.0.1"
        let checker = UpdateChecker(
            currentVersion: "9.9.9",
            forceUpdateAvailable: true,
            fetchLatestRelease: fetcher(tag: "v0.0.1", htmlURL: url),
        )
        let result = await checker.check()
        guard case let .updateAvailable(version, releaseURL) = result else {
            Issue.record("Expected forced updateAvailable, got \(result)")
            return
        }
        #expect(version == "0.0.1")
        #expect(releaseURL.absoluteString == url)
    }

    @Test
    func `force flag still reports error when network fetch fails`() async throws {
        struct Boom: Error {}
        let checker = UpdateChecker(
            currentVersion: "1.0.0",
            forceUpdateAvailable: true,
            fetchLatestRelease: { throw Boom() },
        )
        let result = await checker.check()
        guard case .error = result else {
            Issue.record("Expected error, got \(result)")
            return
        }
    }

    @Test
    func `reports error when fetcher throws`() async throws {
        struct Boom: Error {}
        let checker = UpdateChecker(
            currentVersion: "1.0.0",
            forceUpdateAvailable: false,
            fetchLatestRelease: { throw Boom() },
        )
        let result = await checker.check()
        guard case .error = result else {
            Issue.record("Expected error, got \(result)")
            return
        }
    }

    @Test
    func `reports error when remote tag is not parseable as semver`() async throws {
        let checker = UpdateChecker(
            currentVersion: "1.0.0",
            forceUpdateAvailable: false,
            fetchLatestRelease: fetcher(tag: "release-with-no-version"),
        )
        let result = await checker.check()
        guard case .error = result else {
            Issue.record("Expected error for unparseable tag, got \(result)")
            return
        }
    }

    @Test
    func `reports error when current version is not parseable as semver`() async throws {
        let checker = UpdateChecker(
            currentVersion: "not-a-version",
            forceUpdateAvailable: false,
            fetchLatestRelease: fetcher(tag: "v1.0.0"),
        )
        let result = await checker.check()
        guard case .error = result else {
            Issue.record("Expected error for unparseable current version, got \(result)")
            return
        }
    }

    @Test
    func `parses GitHub release JSON payload`() throws {
        let json = #"""
        {
          "tag_name": "v1.4.2",
          "html_url": "https://github.com/owner/repo/releases/tag/v1.4.2",
          "name": "Release 1.4.2"
        }
        """#.data(using: .utf8)!
        let release = try GitHubLatestRelease.decode(from: json)
        #expect(release.tagName == "v1.4.2")
        #expect(release.htmlURL.absoluteString == "https://github.com/owner/repo/releases/tag/v1.4.2")
    }
}
