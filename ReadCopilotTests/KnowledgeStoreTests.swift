import XCTest
import SwiftData
@testable import ReadCopilot

@MainActor
final class KnowledgeStoreTests: XCTestCase {

    private func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: KnowledgeItem.self, configurations: config)
    }

    private func makeNote(id: String, book: String = "测试书", source: String = "原文", note: String = "") -> ReadingNote {
        ReadingNote(
            id: id,
            bookID: "book-\(book)",
            bookTitle: book,
            kind: note.isEmpty ? .highlight : .thought,
            sourceText: source,
            noteText: note
        )
    }

    func testImportPersistsAndReloads() throws {
        let container = try makeInMemoryContainer()
        let store = KnowledgeStore(container: container)

        let imported = store.importNotes([
            makeNote(id: "n1"),
            makeNote(id: "n2", note: "我的想法")
        ])

        XCTAssertEqual(imported, 2)
        XCTAssertEqual(store.entries.count, 2)
        XCTAssertEqual(store.highlightCount, 1)
        XCTAssertEqual(store.thoughtCount, 1)

        // 新 store 从同一容器读取，验证真正落盘（内存容器内共享）
        let reopened = KnowledgeStore(container: container)
        XCTAssertEqual(reopened.entries.count, 2)
    }

    func testImportDeduplicatesById() throws {
        let container = try makeInMemoryContainer()
        let store = KnowledgeStore(container: container)

        XCTAssertEqual(store.importNotes([makeNote(id: "dup")]), 1)
        XCTAssertEqual(store.importNotes([makeNote(id: "dup"), makeNote(id: "new")]), 1)
        XCTAssertEqual(store.entries.count, 2)
    }

    func testSearchFiltersAcrossFields() throws {
        let container = try makeInMemoryContainer()
        let store = KnowledgeStore(container: container)
        store.importNotes([
            makeNote(id: "a", book: "思考快与慢", source: "系统一负责直觉"),
            makeNote(id: "b", book: "原则", source: "极度透明", note: "适用于团队管理")
        ])

        store.searchText = "直觉"
        XCTAssertEqual(store.filteredEntries.count, 1)
        XCTAssertEqual(store.filteredEntries.first?.bookTitle, "思考快与慢")

        store.searchText = "团队"
        XCTAssertEqual(store.filteredEntries.count, 1)

        store.searchText = "原则"
        XCTAssertEqual(store.filteredEntries.count, 1)

        store.searchText = ""
        XCTAssertEqual(store.filteredEntries.count, 2)
    }

    func testEntriesGroupedByBook() throws {
        let container = try makeInMemoryContainer()
        let store = KnowledgeStore(container: container)
        store.importNotes([
            makeNote(id: "1", book: "甲"),
            makeNote(id: "2", book: "甲"),
            makeNote(id: "3", book: "乙")
        ])

        let groups = store.entriesByBook
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.first?.title, "甲")
        XCTAssertEqual(groups.first?.entries.count, 2)
        XCTAssertEqual(store.sourceBookCount, 2)
    }
}
