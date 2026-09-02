import XCTest
import SwiftData
@testable import ReadCopilot

// MARK: - AnalysisService 配置与纯函数

final class AnalysisServiceTests: XCTestCase {

    func testMakeClientThrowsWithoutConfig() {
        let service = AnalysisService(keyStore: InMemoryKeyStore())
        XCTAssertThrowsError(try service.makeClient()) { error in
            XCTAssertTrue(error is AnalysisService.ConfigError)
        }
    }

    func testMakeClientAllowsEmptyKeyForOllama() throws {
        let service = AnalysisService(keyStore: InMemoryKeyStore([
            .llmBaseURL: "http://127.0.0.1:11434/v1",
            .llmModel: "qwen2.5"
        ]))
        let client = try service.makeClient()
        XCTAssertEqual(client.apiKey, "")
        XCTAssertEqual(client.model, "qwen2.5")
    }

    func testMakeClientReadsFullConfig() throws {
        let service = AnalysisService(keyStore: InMemoryKeyStore([
            .llmAPIKey: "sk-test",
            .llmBaseURL: "https://api.deepseek.com/v1",
            .llmModel: "deepseek-chat"
        ]))
        let client = try service.makeClient()
        XCTAssertEqual(client.apiKey, "sk-test")
        XCTAssertEqual(client.baseURL, "https://api.deepseek.com/v1")
    }
}

// MARK: - WeReadNotesService Key 校验

final class WeReadNotesServiceTests: XCTestCase {

    func testFetchThrowsWithoutValidKey() async {
        let book = LibraryBook(
            id: "b1", title: "书", author: "", cover: "", category: "",
            finished: false, secret: false, readUpdateTime: 0, isAlbum: false
        )
        let service = WeReadNotesService(keyStore: InMemoryKeyStore())
        do {
            _ = try await service.fetchAllNotes(for: book)
            XCTFail("应抛出 missingKey")
        } catch WeReadError.missingKey {
            // 预期
        } catch {
            XCTFail("应抛出 missingKey，实际 \(error)")
        }
    }
}

// MARK: - TopicExtractionService 纯函数

final class TopicExtractionServiceTests: XCTestCase {

    private func makeEntry(id: String, book: String = "测试书", topics: [String] = []) -> KnowledgeEntry {
        KnowledgeEntry(
            id: id, bookID: "book", bookTitle: book, kind: .highlight,
            sourceText: "原文内容", noteText: "", importedAt: Date(), topics: topics
        )
    }

    func testParseTopicsFromCleanJSON() {
        let reply = #"{"topics":{"n1":["决策心理","认知偏差"],"n2":["团队管理"]}}"#
        let parsed = TopicExtractionService.parseTopics(from: reply)
        XCTAssertEqual(parsed["n1"], ["决策心理", "认知偏差"])
        XCTAssertEqual(parsed["n2"], ["团队管理"])
    }

    func testParseTopicsToleratesSurroundingText() {
        let reply = """
        好的，以下是提取结果：
        {"topics":{"n1":[" 时间观 "]}}
        希望对你有帮助。
        """
        let parsed = TopicExtractionService.parseTopics(from: reply)
        XCTAssertEqual(parsed["n1"], ["时间观"])
    }

    func testParseTopicsReturnsEmptyOnGarbage() {
        XCTAssertTrue(TopicExtractionService.parseTopics(from: "模型拒绝回答").isEmpty)
        XCTAssertTrue(TopicExtractionService.parseTopics(from: "{broken json").isEmpty)
    }

    func testBatchPromptContainsIdAndBook() {
        let prompt = TopicExtractionService.buildBatchPrompt([
            makeEntry(id: "entry-1", book: "思考快与慢")
        ])
        XCTAssertTrue(prompt.contains("entry-1"))
        XCTAssertTrue(prompt.contains("思考快与慢"))
    }
}

// MARK: - KnowledgeStore 主题持久化

@MainActor
final class KnowledgeTopicTests: XCTestCase {

    func testTopicsPersistAndAggregate() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: KnowledgeItem.self, configurations: config)
        let store = KnowledgeStore(container: container)

        store.importNotes([
            ReadingNote(id: "t1", bookID: "b", bookTitle: "书", kind: .highlight, sourceText: "a", noteText: ""),
            ReadingNote(id: "t2", bookID: "b", bookTitle: "书", kind: .highlight, sourceText: "b", noteText: "")
        ])
        XCTAssertEqual(store.pendingTopicCount, 2)

        // 直接写入主题模拟提取结果
        let context = ModelContext(container)
        for item in try context.fetch(FetchDescriptor<KnowledgeItem>()) {
            item.topics = item.id == "t1" ? ["决策心理"] : ["决策心理", "习惯养成"]
        }
        try context.save()
        store.reload()

        XCTAssertEqual(store.pendingTopicCount, 0)
        let topics = store.allTopics
        XCTAssertEqual(topics.first?.topic, "决策心理")
        XCTAssertEqual(topics.first?.count, 2)

        // 主题过滤
        store.selectedTopic = "习惯养成"
        XCTAssertEqual(store.filteredEntries.count, 1)
        XCTAssertEqual(store.filteredEntries.first?.id, "t2")

        store.selectedTopic = nil
        XCTAssertEqual(store.filteredEntries.count, 2)
    }
}
