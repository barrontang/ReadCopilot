import Foundation
import SwiftData

// MARK: - 知识条目（SwiftData 持久化模型）
// 每条知识保留划线原文、读者笔记与来源图书，可追溯、可查询。

@Model
final class KnowledgeItem {
    @Attribute(.unique) var id: String
    var bookID: String
    var bookTitle: String
    var kind: String            // ReadingNote.Kind.rawValue
    var sourceText: String
    var noteText: String
    var importedAt: Date
    var topics: [String] = []   // LLM 提取的主题标签

    init(note: ReadingNote, importedAt: Date = Date()) {
        id = note.id
        bookID = note.bookID
        bookTitle = note.bookTitle
        kind = note.kind.rawValue
        sourceText = note.sourceText
        noteText = note.noteText
        self.importedAt = importedAt
    }

    func toEntry() -> KnowledgeEntry {
        KnowledgeEntry(
            id: id,
            bookID: bookID,
            bookTitle: bookTitle,
            kind: ReadingNote.Kind(rawValue: kind) ?? .highlight,
            sourceText: sourceText,
            noteText: noteText,
            importedAt: importedAt,
            topics: topics
        )
    }
}

// MARK: - UI 展示用值类型

struct KnowledgeEntry: Identifiable, Codable, Hashable {
    let id: String
    let bookID: String
    let bookTitle: String
    let kind: ReadingNote.Kind
    let sourceText: String
    let noteText: String
    let importedAt: Date
    var topics: [String] = []
}

// MARK: - 知识库 Store（SwiftData 单一数据源）

@MainActor
final class KnowledgeStore: ObservableObject {
    @Published private(set) var entries: [KnowledgeEntry] = []
    @Published var searchText: String = ""
    @Published var selectedTopic: String?
    @Published private(set) var extractingTopics = false

    private let container: ModelContainer
    private static let legacyStorageKey = "com.readcopilot.knowledge.entries"

    var highlightCount: Int {
        entries.count { $0.kind == .highlight }
    }

    var thoughtCount: Int {
        entries.count { !$0.noteText.isEmpty }
    }

    var sourceBookCount: Int {
        Set(entries.map(\.bookID)).count
    }

    /// 搜索 + 主题过滤后的条目
    var filteredEntries: [KnowledgeEntry] {
        var result = entries
        if let topic = selectedTopic {
            result = result.filter { $0.topics.contains(topic) }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return result }
        return result.filter {
            $0.sourceText.localizedCaseInsensitiveContains(query)
                || $0.noteText.localizedCaseInsensitiveContains(query)
                || $0.bookTitle.localizedCaseInsensitiveContains(query)
        }
    }

    /// 全部主题及条目数（按热度降序）
    var allTopics: [(topic: String, count: Int)] {
        var counts: [String: Int] = [:]
        for entry in entries {
            for topic in entry.topics {
                counts[topic, default: 0] += 1
            }
        }
        return counts.map { (topic: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    /// 尚未提取主题的条目数
    var pendingTopicCount: Int {
        entries.count { $0.topics.isEmpty }
    }

    var entriesByBook: [(title: String, entries: [KnowledgeEntry])] {
        Dictionary(grouping: filteredEntries, by: \.bookTitle)
            .map { (title: $0.key, entries: $0.value) }
            .sorted { $0.entries.count > $1.entries.count }
    }

    init(container: ModelContainer = PersistenceManager.modelContainer) {
        self.container = container
        migrateLegacyEntriesIfNeeded()
        reload()
    }

    @discardableResult
    /// 批量导入笔记并按 ID 去重，返回实际新增条目数。
    func importNotes(_ notes: [ReadingNote]) -> Int {
        let context = ModelContext(container)
        let existingIDs = (try? context.fetch(FetchDescriptor<KnowledgeItem>()))
            .map { Set($0.map(\.id)) } ?? []
        let newNotes = notes.filter { !existingIDs.contains($0.id) }
        guard !newNotes.isEmpty else { return 0 }

        for note in newNotes {
            context.insert(KnowledgeItem(note: note))
        }
        do {
            try context.save()
        } catch {
            assertionFailure("知识库保存失败：\(error)")
            return 0
        }
        reload()
        return newNotes.count
    }

    /// 从 SwiftData 重新加载全部知识条目并按导入时间倒序更新内存状态。
    func reload() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<KnowledgeItem>(
            sortBy: [SortDescriptor(\.importedAt, order: .reverse)]
        )
        entries = ((try? context.fetch(descriptor)) ?? []).map { $0.toEntry() }
    }

    /// 用 LLM 为尚无主题的条目提取主题标签并持久化。返回更新条目数。
    @discardableResult
    func extractTopics(using service: TopicExtractionService = TopicExtractionService()) async throws -> Int {
        let pending = entries.filter { $0.topics.isEmpty }
        guard !pending.isEmpty else { return 0 }

        extractingTopics = true
        defer { extractingTopics = false }

        let topicMap = try await service.extractTopics(for: pending)
        guard !topicMap.isEmpty else { return 0 }

        let context = ModelContext(container)
        let items = (try? context.fetch(FetchDescriptor<KnowledgeItem>())) ?? []
        var updated = 0
        for item in items {
            if let topics = topicMap[item.id], !topics.isEmpty {
                item.topics = topics
                updated += 1
            }
        }
        try context.save()
        reload()
        return updated
    }

    /// 一次性迁移：把旧 UserDefaults JSON 数据搬进 SwiftData 后清除。
    /// 用独立结构解码，避免 KnowledgeEntry 未来加字段导致旧数据解码失败。
    private struct LegacyEntry: Decodable {
        let id: String
        let bookID: String
        let bookTitle: String
        let kind: ReadingNote.Kind
        let sourceText: String
        let noteText: String
        let importedAt: Date
    }

    private func migrateLegacyEntriesIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: Self.legacyStorageKey),
              let legacy = try? JSONDecoder().decode([LegacyEntry].self, from: data),
              !legacy.isEmpty else { return }

        let context = ModelContext(container)
        let existingIDs = (try? context.fetch(FetchDescriptor<KnowledgeItem>()))
            .map { Set($0.map(\.id)) } ?? []
        for entry in legacy where !existingIDs.contains(entry.id) {
            let note = ReadingNote(
                id: entry.id,
                bookID: entry.bookID,
                bookTitle: entry.bookTitle,
                kind: entry.kind,
                sourceText: entry.sourceText,
                noteText: entry.noteText
            )
            context.insert(KnowledgeItem(note: note, importedAt: entry.importedAt))
        }
        guard (try? context.save()) != nil else { return }
        UserDefaults.standard.removeObject(forKey: Self.legacyStorageKey)
    }
}
