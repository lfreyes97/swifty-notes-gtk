import Foundation
@testable import SwiftyNotes
import Testing

struct SemanticVersionTests {
    @Test
    func `parses canonical x.y.z`() throws {
        let v = try #require(SemanticVersion("1.2.3"))
        #expect(v.major == 1)
        #expect(v.minor == 2)
        #expect(v.patch == 3)
        #expect(v.preRelease == nil)
    }

    @Test
    func `accepts leading v prefix from GitHub tags`() throws {
        #expect(SemanticVersion("v1.2.3") == SemanticVersion("1.2.3"))
        #expect(SemanticVersion("V1.2.3") == SemanticVersion("1.2.3"))
    }

    @Test
    func `pads missing patch with zero so 1_2 equals 1_2_0`() throws {
        #expect(SemanticVersion("1.2") == SemanticVersion("1.2.0"))
        #expect(SemanticVersion("1") == SemanticVersion("1.0.0"))
    }

    @Test
    func `ignores build metadata in equality and ordering`() throws {
        let a = try #require(SemanticVersion("1.2.3+build.42"))
        let b = try #require(SemanticVersion("1.2.3+other.99"))
        #expect(a == b)
        #expect(!(a < b))
        #expect(!(b < a))
    }

    @Test
    func `rejects non-numeric or garbage strings`() throws {
        #expect(SemanticVersion("") == nil)
        #expect(SemanticVersion("not-a-version") == nil)
        #expect(SemanticVersion("1.x.3") == nil)
        #expect(SemanticVersion("-1.0.0") == nil)
        #expect(SemanticVersion("1.0.0.0") == nil)
    }

    @Test
    func `orders by major then minor then patch`() throws {
        let v100 = try #require(SemanticVersion("1.0.0"))
        let v101 = try #require(SemanticVersion("1.0.1"))
        let v110 = try #require(SemanticVersion("1.1.0"))
        let v200 = try #require(SemanticVersion("2.0.0"))
        #expect(v100 < v101)
        #expect(v101 < v110)
        #expect(v110 < v200)
        #expect(!(v200 < v100))
    }

    @Test
    func `pre-release version is lower than the same release`() throws {
        let release = try #require(SemanticVersion("1.0.0"))
        let alpha = try #require(SemanticVersion("1.0.0-alpha"))
        let beta = try #require(SemanticVersion("1.0.0-beta"))
        let rc = try #require(SemanticVersion("1.0.0-rc.1"))
        #expect(alpha < release)
        #expect(beta < release)
        #expect(rc < release)
        #expect(alpha < beta)
        #expect(beta < rc)
    }

    @Test
    func `numeric pre-release identifiers compare numerically not lexically`() throws {
        let a = try #require(SemanticVersion("1.0.0-alpha.2"))
        let b = try #require(SemanticVersion("1.0.0-alpha.10"))
        #expect(a < b)
    }

    @Test
    func `numeric pre-release identifier is lower than alphanumeric`() throws {
        let numeric = try #require(SemanticVersion("1.0.0-1"))
        let alpha = try #require(SemanticVersion("1.0.0-alpha"))
        #expect(numeric < alpha)
    }

    @Test
    func `shorter pre-release identifier list is lower when prefix is equal`() throws {
        let short = try #require(SemanticVersion("1.0.0-alpha"))
        let long = try #require(SemanticVersion("1.0.0-alpha.1"))
        #expect(short < long)
    }

    @Test
    func `equality is symmetric across construction paths`() throws {
        #expect(SemanticVersion("1.2.0") == SemanticVersion("1.2"))
        #expect(SemanticVersion("v1.2.3+abc") == SemanticVersion("1.2.3"))
    }

    @Test
    func `update is available only when remote is strictly greater`() throws {
        let current = try #require(SemanticVersion("1.2.3"))
        let same = try #require(SemanticVersion("1.2.3"))
        let older = try #require(SemanticVersion("1.2.2"))
        let newer = try #require(SemanticVersion("1.2.4"))
        #expect(!(same > current))
        #expect(!(older > current))
        #expect(newer > current)
    }
}
