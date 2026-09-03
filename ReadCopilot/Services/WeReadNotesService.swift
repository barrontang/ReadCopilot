import Foundation

// MARK: - 微信读书笔记服务
// 职责：取某书全量划线与想法（分页拉全）并解析为 ReadingNote。
// 解析逻辑为纯函数，便于单测。

struct WeReadNotesService {
    let keyStore: any KeyStore
    var gatewayFactory: (String) -> WeReadGateway

    init(
        keyStore: any KeyStore = KeychainKeyStore(),
        gatewayFactory: @escaping (String) -> WeReadGateway = { WeReadGateway(apiKey: $0) }
    ) {
        self.keyStore = keyStore
        self.gatewayFactory = gatewayFactory
    }

    /// 取某书全量笔记：划线一次取全，想法按 synckey 分页拉全。
    func fetchAllNotes(for book: LibraryBook) async throws -> [ReadingNote] {
        guard let apiKey = keyStore.get(.wereadAPIKey), apiKey.hasPrefix("wrk-") else {
            throw WeReadError.missingKey
        }
        let gateway = gatewayFactory(apiKey)

        async let bookmarks = gateway.bookmarks(bookId: book.id)

        var allReviews: [[String: Any]] = []
        var synckey = 0
        for _ in 0..<20 {
            let response = try await gateway.myReviews(bookId: book.id, synckey: synckey, count: 100)
            let page = response["reviews"] as? [[String: Any]] ?? []
            allReviews.append(contentsOf: page)
            let nextSynckey = response["synckey"] as? Int ?? 0
            let hasMore = (response["hasMore"] as? Int ?? 0) == 1
            guard hasMore, nextSynckey != synckey, !page.isEmpty else { break }
            synckey = nextSynckey
        }

        let bookmarkResponse = try await bookmarks
        return Self.parseNotes(book: book, bookmarks: bookmarkResponse, reviews: ["reviews": allReviews])
    }

    /// 纯函数：原始 JSON → ReadingNote
    static func parseNotes(
        book: LibraryBook,
        bookmarks: [String: Any],
        reviews: [String: Any]
    ) -> [ReadingNote] {
        let highlights = (bookmarks["updated"] as? [[String: Any]] ?? []).enumerated().compactMap { index, item -> ReadingNote? in
            guard let text = item["markText"] as? String, !text.isEmpty else { return nil }
            let rawID = item["bookmarkId"] as? String ?? UUID().uuidString
            return ReadingNote(
                id: "\(book.id)-highlight-\(rawID)",
                bookID: book.id,
                bookTitle: book.title,
                bookCategory: book.category,
                kind: .highlight,
                sourceText: text,
                noteText: "",
                chapterTitle: stringValue(in: item, keys: ["chapterTitle", "chapterName", "chapterUid"]),
                location: intValue(in: item, keys: ["range", "position", "start", "offset"]),
                recordedAt: timestamp(in: item, keys: ["createTime", "updateTime", "markTime", "bookmarkTime"]),
                syncedAt: Date(),
                sequenceHint: index
            )
        }
        let thoughts = (reviews["reviews"] as? [[String: Any]] ?? []).enumerated().compactMap { index, item -> ReadingNote? in
            guard let review = item["review"] as? [String: Any],
                  let content = review["content"] as? String,
                  !content.isEmpty else { return nil }
            let source = review["abstract"] as? String ?? ""
            let rawID = review["reviewId"] as? String ?? UUID().uuidString
            return ReadingNote(
                id: "\(book.id)-thought-\(rawID)",
                bookID: book.id,
                bookTitle: book.title,
                bookCategory: book.category,
                kind: .thought,
                sourceText: source.isEmpty ? "（无对应原文）" : source,
                noteText: content,
                chapterTitle: stringValue(in: review, fallback: item, keys: ["chapterTitle", "chapterName", "chapterUid"]),
                location: intValue(in: review, fallback: item, keys: ["range", "position", "start", "offset"]),
                recordedAt: timestamp(in: review, fallback: item, keys: ["createTime", "updateTime", "reviewTime", "time"]),
                syncedAt: Date(),
                sequenceHint: index
            )
        }
        return highlights + thoughts
    }

    private static func stringValue(in primary: [String: Any], fallback: [String: Any]? = nil, keys: [String]) -> String {
        for key in keys {
            if let value = primary[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
            if let value = fallback?[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return ""
    }

    private static func intValue(in primary: [String: Any], fallback: [String: Any]? = nil, keys: [String]) -> Int? {
        for key in keys {
            if let value = integer(primary[key]) ?? integer(fallback?[key]) {
                return value
            }
        }
        return nil
    }

    private static func timestamp(in primary: [String: Any], fallback: [String: Any]? = nil, keys: [String]) -> Date? {
        for key in keys {
            if let value = integer(primary[key]) ?? integer(fallback?[key]), value > 0 {
                return date(fromTimestamp: value)
            }
        }
        return nil
    }

    private static func integer(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string)
        default:
            return nil
        }
    }

    private static func date(fromTimestamp timestamp: Int) -> Date {
        if timestamp > 1_000_000_000_000 {
            return Date(timeIntervalSince1970: TimeInterval(timestamp) / 1_000)
        }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
}
