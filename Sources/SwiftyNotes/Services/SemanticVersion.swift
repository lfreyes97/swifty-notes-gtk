import Foundation

/// Minimal SemVer 2.0.0 implementation, plus two affordances for the real
/// world: an optional `v` prefix (GitHub release tags) and an implicit
/// `.0` patch component (the app currently ships as `MARKETING_VERSION = 1.0`).
///
/// Used by the in-app update checker to decide whether the latest GitHub
/// release is strictly newer than the running build.
struct SemanticVersion: Equatable, Comparable {
    let major: Int
    let minor: Int
    let patch: Int
    let preRelease: [PreReleaseIdentifier]?

    enum PreReleaseIdentifier: Equatable {
        case numeric(Int)
        case alphanumeric(String)
    }

    init?(_ raw: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if let first = s.first, first == "v" || first == "V" {
            s = String(s.dropFirst())
        }
        // Strip build metadata (everything after the first '+'). Per spec,
        // build metadata is ignored for equality and precedence.
        if let plus = s.firstIndex(of: "+") {
            s = String(s[..<plus])
        }
        // Split pre-release suffix off the core version.
        let pre: String?
        if let dash = s.firstIndex(of: "-") {
            pre = String(s[s.index(after: dash)...])
            s = String(s[..<dash])
        } else {
            pre = nil
        }
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else { return nil }
        var ints: [Int] = []
        for part in parts {
            guard !part.isEmpty,
                part.allSatisfy(\.isASCII),
                part.allSatisfy({ $0.isNumber }),
                let n = Int(part), n >= 0 else { return nil }
            ints.append(n)
        }
        while ints.count < 3 { ints.append(0) }
        self.major = ints[0]
        self.minor = ints[1]
        self.patch = ints[2]
        if let pre {
            let identifiers = pre.split(separator: ".", omittingEmptySubsequences: false)
            guard !identifiers.isEmpty, identifiers.allSatisfy({ !$0.isEmpty }) else { return nil }
            self.preRelease = identifiers.map { id -> PreReleaseIdentifier in
                if id.allSatisfy({ $0.isNumber }), let n = Int(id) {
                    return .numeric(n)
                }
                return .alphanumeric(String(id))
            }
        } else {
            self.preRelease = nil
        }
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        // Pre-release vs non-pre-release: a pre-release has lower precedence.
        switch (lhs.preRelease, rhs.preRelease) {
        case (nil, nil):
            return false
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case let (l?, r?):
            return Self.comparePreRelease(l, r) == .orderedAscending
        }
    }

    private static func comparePreRelease(_ lhs: [PreReleaseIdentifier], _ rhs: [PreReleaseIdentifier]) -> ComparisonResult {
        for (l, r) in zip(lhs, rhs) {
            switch (l, r) {
            case let (.numeric(a), .numeric(b)):
                if a != b { return a < b ? .orderedAscending : .orderedDescending }
            case (.numeric, .alphanumeric):
                return .orderedAscending
            case (.alphanumeric, .numeric):
                return .orderedDescending
            case let (.alphanumeric(a), .alphanumeric(b)):
                if a != b { return a < b ? .orderedAscending : .orderedDescending }
            }
        }
        if lhs.count != rhs.count {
            return lhs.count < rhs.count ? .orderedAscending : .orderedDescending
        }
        return .orderedSame
    }
}
