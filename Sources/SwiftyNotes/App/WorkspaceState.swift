import Foundation

public enum NotesSortMode: String, Codable, CaseIterable, Sendable {
    case newestFirst
    case oldestFirst
    case title

    public var displayName: String {
        switch self {
        case .newestFirst:
            "Newest first"
        case .oldestFirst:
            "Oldest first"
        case .title:
            "Title"
        }
    }

    public func sort(notes: [Note]) -> [Note] {
        notes.sorted { lhs, rhs in
            switch self {
            case .newestFirst:
                if lhs.createdAt == rhs.createdAt {
                    return lhs.stableID > rhs.stableID
                }
                return lhs.createdAt > rhs.createdAt
            case .oldestFirst:
                if lhs.createdAt == rhs.createdAt {
                    return lhs.stableID < rhs.stableID
                }
                return lhs.createdAt < rhs.createdAt
            case .title:
                let comparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                if comparison == .orderedSame {
                    return lhs.createdAt > rhs.createdAt
                }
                return comparison == .orderedAscending
            }
        }
    }
}

public enum EditorViewMode: String, Codable, CaseIterable, Sendable {
    case editor
    case split
    case preview

    var isPreviewVisible: Bool {
        self != .editor
    }
}

public struct WorkspaceState: Codable, Equatable, Sendable {
    public static let legacyDefaultPreviewWidth = 440
    public static let defaultPreviewWidth = 560

    public var selectedNoteID: UUID?
    public var isSidebarVisible: Bool
    public var viewMode: EditorViewMode
    public var searchQuery: String
    public var sortMode: NotesSortMode
    public var windowWidth: Int
    public var windowHeight: Int
    public var previewWidth: Int

    public var isPreviewVisible: Bool {
        viewMode.isPreviewVisible
    }

    public init(
        selectedNoteID: UUID? = nil,
        isSidebarVisible: Bool = true,
        isPreviewVisible: Bool = true,
        viewMode: EditorViewMode? = nil,
        searchQuery: String = "",
        sortMode: NotesSortMode = .newestFirst,
        windowWidth: Int = 1200,
        windowHeight: Int = 800,
        previewWidth: Int = WorkspaceState.defaultPreviewWidth
    ) {
        self.selectedNoteID = selectedNoteID
        self.isSidebarVisible = isSidebarVisible
        self.viewMode = viewMode ?? (isPreviewVisible ? .split : .editor)
        self.searchQuery = searchQuery
        self.sortMode = sortMode
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
        self.previewWidth = previewWidth
    }

    public static let `default` = WorkspaceState()

    private enum CodingKeys: String, CodingKey {
        case selectedNoteID
        case isSidebarVisible
        case viewMode
        case isPreviewVisible
        case searchQuery
        case sortMode
        case windowWidth
        case windowHeight
        case previewWidth
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedNoteID = try container.decodeIfPresent(UUID.self, forKey: .selectedNoteID)
        isSidebarVisible = try container.decodeIfPresent(Bool.self, forKey: .isSidebarVisible) ?? true
        if let viewMode = try container.decodeIfPresent(EditorViewMode.self, forKey: .viewMode) {
            self.viewMode = viewMode
        } else {
            self.viewMode = (try container.decodeIfPresent(Bool.self, forKey: .isPreviewVisible) ?? true) ? .split : .editor
        }
        searchQuery = try container.decodeIfPresent(String.self, forKey: .searchQuery) ?? ""
        sortMode = try container.decodeIfPresent(NotesSortMode.self, forKey: .sortMode) ?? .newestFirst
        windowWidth = try container.decodeIfPresent(Int.self, forKey: .windowWidth) ?? 1200
        windowHeight = try container.decodeIfPresent(Int.self, forKey: .windowHeight) ?? 800
        previewWidth = try container.decodeIfPresent(Int.self, forKey: .previewWidth) ?? WorkspaceState.defaultPreviewWidth
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(selectedNoteID, forKey: .selectedNoteID)
        try container.encode(isSidebarVisible, forKey: .isSidebarVisible)
        try container.encode(viewMode, forKey: .viewMode)
        try container.encode(isPreviewVisible, forKey: .isPreviewVisible)
        try container.encode(searchQuery, forKey: .searchQuery)
        try container.encode(sortMode, forKey: .sortMode)
        try container.encode(windowWidth, forKey: .windowWidth)
        try container.encode(windowHeight, forKey: .windowHeight)
        try container.encode(previewWidth, forKey: .previewWidth)
    }
}
