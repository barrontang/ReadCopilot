import XCTest
import Foundation
@testable import ReadCopilot

// MARK: - Mock URLSession for Testing

final class MockURLSession: NetworkSession {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    var lastRequest: URLRequest?
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        
        if let error = mockError {
            throw error
        }
        
        guard let data = mockData, let response = mockResponse else {
            throw URLError(.unknown)
        }
        
        return (data, response)
    }
}

// MARK: - WeReadGateway Tests

class WeReadGatewayTests: XCTestCase {
    var gateway: WeReadGateway!
    var mockSession: MockURLSession!
    
    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        gateway = WeReadGateway(apiKey: "wrk-test-key", session: mockSession)
    }
    
    override func tearDown() {
        gateway = nil
        mockSession = nil
        super.tearDown()
    }
    
    func testValidateKeySuccess() async throws {
        // Setup mock response
        let mockResponseJSON: [String: Any] = [
            "totalReadTime": 3600,
            "readDays": 30,
            "registTime": 1000000,
            "readStat": []
        ]
        let mockData = try JSONSerialization.data(withJSONObject: mockResponseJSON)
        mockSession.mockData = mockData
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://i.weread.qq.com/api/agent/gateway")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // Test
        let result = try await gateway.validateKey()
        XCTAssertTrue(result)
    }
    
    func testValidateKeyMissingKey() async {
        let invalidGateway = WeReadGateway(apiKey: "invalid-key", session: mockSession)
        
        do {
            _ = try await invalidGateway.validateKey()
            XCTFail("Should throw missingKey error")
        } catch WeReadError.missingKey {
            // Expected
        } catch {
            XCTFail("Should throw missingKey, got \(error)")
        }
    }
    
    func testGatewayErrorResponse() async throws {
        let mockResponseJSON: [String: Any] = [
            "errcode": 401,
            "errmsg": "Invalid API key"
        ]
        let mockData = try JSONSerialization.data(withJSONObject: mockResponseJSON)
        mockSession.mockData = mockData
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://i.weread.qq.com/api/agent/gateway")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        do {
            _ = try await gateway.readData()
            XCTFail("Should throw gateway error")
        } catch WeReadError.gateway(let code, let msg) {
            XCTAssertEqual(code, 401)
            XCTAssertEqual(msg, "Invalid API key")
        } catch {
            XCTFail("Expected gateway error, got \(error)")
        }
    }
    
    func testAuthorizationHeaderIncludesKey() async throws {
        let mockData = try JSONSerialization.data(withJSONObject: [:])
        mockSession.mockData = mockData
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://i.weread.qq.com/api/agent/gateway")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        _ = try? await gateway.readData()
        
        // Verify Authorization header contains the key
        guard let authHeader = mockSession.lastRequest?.value(forHTTPHeaderField: "Authorization") else {
            XCTFail("No Authorization header found")
            return
        }
        
        XCTAssertTrue(authHeader.contains("wrk-test-key"), "Authorization header should contain API key")
    }
}

// MARK: - Diagnosis Model Tests

@MainActor
class DiagnosisModelTests: XCTestCase {
    var diagnosisModel: DiagnosisModel!
    
    override func setUp() {
        super.setUp()
        diagnosisModel = DiagnosisModel()
    }
    
    override func tearDown() {
        diagnosisModel = nil
        super.tearDown()
    }
    
    func testPromptBuilding() {
        let book1 = LibraryBook(
            id: "book1",
            title: "Swift 教程",
            author: "Apple",
            cover: "",
            category: "编程",
            finished: false,
            secret: false,
            readUpdateTime: 0,
            isAlbum: false
        )
        
        let note1 = ReadingNote(
            id: "note1",
            bookID: "book1",
            bookTitle: "Swift 教程",
            kind: .highlight,
            sourceText: "Optional 是 Swift 的创新",
            noteText: ""
        )
        
        let note2 = ReadingNote(
            id: "note2",
            bookID: "book1",
            bookTitle: "Swift 教程",
            kind: .thought,
            sourceText: "类型安全很重要",
            noteText: "我认为这对大型项目特别有益"
        )
        
        let prompt = AnalysisService.buildPrompt(books: [book1], notes: [note1, note2])
        
        XCTAssertTrue(prompt.contains("【分析范围】1 本书"))
        XCTAssertTrue(prompt.contains("Swift 教程"))
        XCTAssertTrue(prompt.contains("Apple"))
        XCTAssertTrue(prompt.contains("编程"))
        XCTAssertTrue(prompt.contains("Optional 是 Swift 的创新"))
        XCTAssertTrue(prompt.contains("我认为这对大型项目特别有益"))
    }
    
    func testParseNotesFromBookmarks() {
        let book = LibraryBook(
            id: "book1",
            title: "Test Book",
            author: "Author",
            cover: "",
            category: "Test",
            finished: false,
            secret: false,
            readUpdateTime: 0,
            isAlbum: false
        )
        
        let bookmarksJSON: [String: Any] = [
            "updated": [
                [
                    "bookmarkId": "bm1",
                    "markText": "重要的句子"
                ],
                [
                    "bookmarkId": "bm2",
                    "markText": "另一个重点"
                ]
            ]
        ]
        
        let reviewsJSON: [String: Any] = [
            "reviews": [
                [
                    "review": [
                        "reviewId": "rv1",
                        "content": "我的想法",
                        "abstract": "作者说..."
                    ]
                ]
            ]
        ]
        
        let notes = WeReadNotesService.parseNotes(book: book, bookmarks: bookmarksJSON, reviews: reviewsJSON)
        
        XCTAssertEqual(notes.count, 3)
        XCTAssertEqual(notes.filter { $0.kind == .highlight }.count, 2)
        XCTAssertEqual(notes.filter { $0.kind == .thought }.count, 1)
    }
    
    func testStateTransitions() {
        XCTAssertEqual(diagnosisModel.state, .idle)
        
        diagnosisModel.state = .fetchingNotes
        XCTAssertEqual(diagnosisModel.state, .fetchingNotes)
        
        diagnosisModel.state = .generating
        XCTAssertEqual(diagnosisModel.state, .generating)
        
        diagnosisModel.state = .done
        XCTAssertEqual(diagnosisModel.state, .done)
    }
    
    func testExtractOneLinerFromReport() {
        let report = """
        # 分析报告
        
        ## 思考模式
        你的笔记很好
        
        ## 一句话总结
        这是一个很好的总结。
        
        ## 建议
        继续努力
        """
        
        let oneLiner = AnalysisService.extractOneLiner(from: report)
        XCTAssertEqual(oneLiner, "这是一个很好的总结。")
    }
}

// MARK: - LibraryStore Tests

@MainActor
class LibraryStoreTests: XCTestCase {
    func testCategoryDistribution() {
        let books = [
            LibraryBook(id: "1", title: "Book1", author: "", cover: "", category: "编程", finished: false, secret: false, readUpdateTime: 0, isAlbum: false),
            LibraryBook(id: "2", title: "Book2", author: "", cover: "", category: "编程", finished: false, secret: false, readUpdateTime: 0, isAlbum: false),
            LibraryBook(id: "3", title: "Book3", author: "", cover: "", category: "文学", finished: false, secret: false, readUpdateTime: 0, isAlbum: false),
            LibraryBook(id: "4", title: "Book4", author: "", cover: "", category: "心理学", finished: false, secret: false, readUpdateTime: 0, isAlbum: false),
        ]
        
        let store = LibraryStore()
        store.books = books
        
        let dist = store.categoryDistribution
        XCTAssertEqual(dist.count, 3)
        XCTAssertEqual(dist[0].category, "编程")
        XCTAssertEqual(dist[0].count, 2)
    }
    
    func testDurationFormatting() {
        XCTAssertEqual(LibraryStore.fmtDuration(3661), "1小时1分钟")
        XCTAssertEqual(LibraryStore.fmtDuration(300), "5分钟")
        XCTAssertEqual(LibraryStore.fmtDuration(7200), "2小时0分钟")
    }
}
