import Foundation

/// Generates GitHub-style heading slugs with dedup suffixes.
///
/// Pipeline:
///  1. Lowercase (preserves Unicode letters so Cyrillic / accented
///     headings still get readable slugs).
///  2. Map any non-alphabetic, non-digit scalar to `-`.
///  3. Collapse consecutive dashes; trim leading/trailing dashes.
///  4. Fall back to `section` if nothing remains (heading was empty or
///     contained only punctuation).
///  5. Dedup via the caller-owned `occurrences` table: first occurrence
///     keeps the bare slug, subsequent ones append `-2`, `-3`, …
///     Dedup compares the *normalized* slug, not the raw heading text,
///     so `Hello World` and `Hello, World!` still collide.
enum HeadingSlug {
    static func slug(_ text: String, occurrences: inout [String: Int]) -> String {
        let normalized = normalize(text)
        let base = normalized.isEmpty ? "section" : normalized
        let count = occurrences[base, default: 0] + 1
        occurrences[base] = count
        return count == 1 ? base : "\(base)-\(count)"
    }

    private static func normalize(_ text: String) -> String {
        var result = ""
        var lastWasDash = true // start true so leading dashes are trimmed
        for scalar in text.lowercased().unicodeScalars {
            if scalar.properties.isAlphabetic || ("0"..."9").contains(scalar) {
                result.unicodeScalars.append(scalar)
                lastWasDash = false
            } else if !lastWasDash {
                result.append("-")
                lastWasDash = true
            }
        }
        while result.hasSuffix("-") { result.removeLast() }
        return result
    }
}
