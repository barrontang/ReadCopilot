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
        let highlights = (bookmarks["updated"] as? [[String: Any]] ?? []).compactMap { item -> ReadingNote? in
            guard let text = item["markText"] as? String, !text.isEmpty else { return nil }
            let rawID = item["bookmarkId"] as? String ?? UUID().uuidString
            let timestamp = timestamp(from: item, keys: ["createTime", "updateTime", "timestamp", "time"])
            let chapter = item["chapterTitle"] as? String ?? item["chapterUid"] as? String ?? ""
            let location = int(from: item, keys: ["range", "position", "start"])
            return ReadingNote(
                id: "\(book.id)-highlight-\(rawID)",
                bookID: book.id,
                bookTitle: book.title,
                kind: .highlight,
                sourceText: text,
                noteText: "",
                eventTime: timestamp,
                chapterTitle: chapter,
                location: location
            )
        }
        let thoughts = (reviews["reviews"] as? [[String: Any]] ?? []).compactMap { item -> ReadingNote? in
            guard let review = item["review"] as? [String: Any],
                  let content = review["content"] as? String,
                  !content.isEmpty else { return nil }
            let source = review["abstract"] as? String ?? ""
            let rawID = review["reviewId"] as? String ?? UUID().uuidString
            let timestamp = timestamp(from: review, keys: ["createTime", "updateTime", "timestamp", "time"])
                ?? timestamp(from: item, keys: ["createTime", "updateTime", "timestamp", "time"])
            let chapter = review["chapterTitle"] as? String ?? ""
            let location = int(from: review, keys: ["range", "position", "start"])
            return ReadingNote(
                id: "\(book.id)-thought-\(rawID)",
                bookID: book.id,
                bookTitle: book.title,
                kind: .thought,
                sourceText: source.isEmpty ? "（无对应原文）" : source,
                noteText: content,
                eventTime: timestamp,
                chapterTitle: chapter,
                location: location
            )
        }
        let merged = highlights + thoughts
        return merged.enumerated().map { index, note in
            ReadingNote(
                id: note.id,
                bookID: note.bookID,
                bookTitle: note.bookTitle,
                kind: note.kind,
                sourceText: note.sourceText,
                noteText: note.noteText,
                eventTime: note.eventTime,
                chapterTitle: note.chapterTitle,
                location: note.location,
                sourceOrder: index
            )
        }
    }

    private static func timestamp(from payload: [String: Any], keys: [String]) -> Date? {
        for key in keys {
            if let raw = payload[key] {
                if let int = raw as? Int, int > 0 {
                    let sec = int > 1_000_000_000_000 ? Double(int) / 1000.0 : Double(int)
                    return Date(timeIntervalSince1970: sec)
                }
                if let str = raw as? String, let int = Int(str), int > 0 {
                    let sec = int > 1_000_000_000_000 ? Double(int) / 1000.0 : Double(int)
                    return Date(timeIntervalSince1970: sec)
                }
            }
        }
        return nil
    }

    private static func int(from payload: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = payload[key] as? Int { return value }
            if let value = payload[key] as? String, let parsed = Int(value) { return parsed }
        }
        return nil
    }
}
