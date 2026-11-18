import Foundation

// MARK: - 微信读书笔记服务
// 职责：取某书全量划线与想法（分页拉全），保留章节、时间与引用关系。
// 解析逻辑为纯函数，便于单测。

struct NotebookCorpus {
    let book: LibraryBook
    let chapterTitles: [String]
    let notes: [ReadingNote]
}

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

    /// 取某书语料：划线与想法、章节标题、时间与引用关系。
    func fetchCorpus(for book: LibraryBook) async throws -> NotebookCorpus {
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
        let chapterTitles = Self.chapterTitles(from: bookmarkResponse)
        let notes = Self.parseNotes(
            book: book,
            bookmarks: bookmarkResponse,
            reviews: ["reviews": allReviews]
        )
        return NotebookCorpus(book: book, chapterTitles: chapterTitles, notes: notes)
    }

    /// 兼容旧调用：只返回笔记。
    func fetchAllNotes(for book: LibraryBook) async throws -> [ReadingNote] {
        try await fetchCorpus(for: book).notes
    }

    // MARK: - 纯函数

    /// 章节目录（按 chapterUid 排序）。
    static func chapterTitles(from bookmarks: [String: Any]) -> [String] {
        let chapters = bookmarks["chapters"] as? [[String: Any]] ?? []
        return chapters
            .sorted { ($0["chapterUid"] as? Int ?? 0) < ($1["chapterUid"] as? Int ?? 0) }
            .compactMap { item in
                (item["title"] as? String) ?? (item["chapterTitle"] as? String)
            }
    }

    /// 原始 JSON → ReadingNote，并尽力把想法挂到对应划线上。
    static func parseNotes(
        book: LibraryBook,
        bookmarks: [String: Any],
        reviews: [String: Any]
    ) -> [ReadingNote] {
        let chapterByUID = chapterMap(from: bookmarks)

        var highlights: [ReadingNote] = []
        for item in bookmarks["updated"] as? [[String: Any]] ?? [] {
            guard let text = item["markText"] as? String, !text.isEmpty else { continue }
            let rawID = item["bookmarkId"] as? String ?? UUID().uuidString
            let uid = item["chapterUid"] as? Int ?? 0
            let chapter = chapterByUID[uid]
                ?? (item["chapterTitle"] as? String)
                ?? ""
            highlights.append(
                ReadingNote(
                    id: "\(book.id)-highlight-\(rawID)",
                    bookID: book.id,
                    bookTitle: book.title,
                    kind: .highlight,
                    sourceText: text,
                    noteText: "",
                    chapter: chapter,
                    createdAt: item["createTime"] as? Int ?? 0
                )
            )
        }

        var thoughts: [ReadingNote] = []
        for item in reviews["reviews"] as? [[String: Any]] ?? [] {
            let review = item["review"] as? [String: Any] ?? item
            guard let content = review["content"] as? String, !content.isEmpty else { continue }
            let abstract = review["abstract"] as? String ?? ""
            let rawID = review["reviewId"] as? String ?? UUID().uuidString
            let uid = review["chapterUid"] as? Int ?? 0
            let chapter = chapterByUID[uid]
                ?? (review["chapterTitle"] as? String)
                ?? ""
            thoughts.append(
                ReadingNote(
                    id: "\(book.id)-thought-\(rawID)",
                    bookID: book.id,
                    bookTitle: book.title,
                    kind: .thought,
                    sourceText: abstract.isEmpty ? "（无对应原文）" : abstract,
                    noteText: content,
                    chapter: chapter,
                    createdAt: review["createTime"] as? Int ?? 0,
                    star: review["star"] as? Int ?? 0
                )
            )
        }

        link(&thoughts, to: highlights)
        return highlights + thoughts
    }

    private static func chapterMap(from bookmarks: [String: Any]) -> [Int: String] {
        let chapters = bookmarks["chapters"] as? [[String: Any]] ?? []
        var map: [Int: String] = [:]
        for item in chapters {
            guard let uid = item["chapterUid"] as? Int else { continue }
            if let title = item["title"] as? String ?? item["chapterTitle"] as? String {
                map[uid] = title
            }
        }
        return map
    }

    /// 尽力匹配：abstract 与划线原文的前 40 字精确匹配，再做前缀包含匹配。
    private static func link(_ thoughts: inout [ReadingNote], to highlights: [ReadingNote]) {
        var index: [String: String] = [:]
        for highlight in highlights {
            let key = normalized(highlight.sourceText)
            guard !key.isEmpty else { continue }
            index[String(key.prefix(40))] = highlight.id
        }

        for indexOfThought in thoughts.indices {
            let abstract = normalized(thoughts[indexOfThought].sourceText)
            guard !abstract.isEmpty, abstract != "（无对应原文）" else { continue }
            let key = String(abstract.prefix(40))
            if let highlightID = index[key] {
                thoughts[indexOfThought].quoteID = highlightID
                continue
            }
            for (candidate, highlightID) in index where candidate.count > 12 {
                if abstract.hasPrefix(String(candidate.prefix(16)))
                    || candidate.hasPrefix(String(abstract.prefix(16))) {
                    thoughts[indexOfThought].quoteID = highlightID
                    break
                }
            }
        }
    }

    private static func normalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .lowercased()
    }
}
