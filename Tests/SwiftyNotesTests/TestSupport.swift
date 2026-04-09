import Foundation
import Testing
@testable import SwiftyNotes
import Adwaita
import CAdwaita

actor SaveRecorder {
    private var values: [Int] = []

    func append(_ value: Int) {
        values.append(value)
    }

    func snapshot() -> [Int] {
        values
    }
}

@MainActor
final class URLRecorder {
    private var value: URL?

    func set(_ url: URL) {
        value = url
    }

    func snapshot() -> URL? {
        value
    }
}

struct CLITestSummary: Decodable {
    let id: String
    let title: String
    let filename: String
    let createdAt: Date
    let updatedAt: Date
}

struct CLITestDocument: Decodable {
    let id: String
    let title: String
    let filename: String
    let createdAt: Date
    let updatedAt: Date
    let content: String
}

extension JSONDecoder {
    static var swiftyNotesCLI: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

@MainActor
func drainMainContext(iterations: Int = 8) {
    guard let context = g_main_context_default() else { return }
    for _ in 0..<max(iterations, 1) {
        while g_main_context_pending(context) != 0 {
            _ = g_main_context_iteration(context, 0)
        }
        _ = g_main_context_iteration(context, 0)
    }
}
