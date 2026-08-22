import Foundation
import UserNotifications

// MARK: - 诊断引擎:拉单本书笔记 → 组 prompt → 调 LLM → 后台运行，完成通知用户

@MainActor
final class DiagnosisModel: ObservableObject {
    @Published var state: State = .idle
    @Published var report: String = ""
    @Published var notes: [ReadingNote] = []
    @Published var completedBooks = 0
    @Published var totalBooks = 0

    enum State: Equatable {
        case idle
        case fetchingNotes
        case generating
        case done
        case failed(String)
    }

    // MARK: 主入口 — 后台运行，UI 不需要等待
    func run(book: LibraryBook, template: AnalysisTemplate = .coach) {
        run(books: [book], template: template)
    }

    func run(books: [LibraryBook], template: AnalysisTemplate) {
        report = ""
        notes = []
        completedBooks = 0
        totalBooks = books.count
        state = .fetchingNotes

        guard let wrKey = Keychain.get(.wereadAPIKey), wrKey.hasPrefix("wrk-") else {
            state = .failed("未设置微信读书 Key，请到设置页填入 wrk- 开头的 Key")
            return
        }
        guard let llmKey = Keychain.get(.llmAPIKey), !llmKey.isEmpty,
              let llmBase = Keychain.get(.llmBaseURL), !llmBase.isEmpty,
              let llmModel = Keychain.get(.llmModel), !llmModel.isEmpty else {
            state = .failed("未设置 LLM Key，请到设置页填写并点击「测试连接并保存」")
            return
        }

        // 在独立 Task 里跑，调用方无需 await — 用户可随时切走
        Task {
            await diagnose(
                books: books,
                template: template,
                wrKey: wrKey,
                llmKey: llmKey,
                llmBase: llmBase,
                llmModel: llmModel
            )
        }
    }

    // MARK: 实际异步执行（@MainActor 保证 Published 在主线程更新）
    private func diagnose(
        books: [LibraryBook],
        template: AnalysisTemplate,
        wrKey: String, llmKey: String, llmBase: String, llmModel: String
    ) async {
        guard !books.isEmpty else {
            state = .failed("请选择至少一本书。")
            return
        }
        do {
            let gw = WeReadGateway(apiKey: wrKey)
            var collected: [ReadingNote] = []
            for book in books {
                async let bmJSON = gw.bookmarks(bookId: book.id)
                async let rvJSON = gw.myReviews(bookId: book.id, synckey: 0, count: 100)
                let (bm, rv) = try await (bmJSON, rvJSON)
                collected.append(contentsOf: parseNotes(book: book, bookmarks: bm, reviews: rv))
                completedBooks += 1
            }
            notes = collected

            guard !collected.isEmpty else {
                let msg = "所选范围内暂无划线或想法记录，无法生成分析。"
                state = .failed(msg)
                await notify(title: "分析失败", body: msg, isError: true)
                return
            }

            state = .generating
            let prompt = buildPrompt(books: books, notes: collected)
            let client = LLMClient(apiKey: llmKey, baseURL: llmBase, model: llmModel)
            let result = try await client.chat(
                system: template.systemPrompt,
                user: prompt,
                maxTokens: template == .bookReview ? 3200 : 2200,
                timeout: 180
            )
            report = result
            state  = .done

            // ✅ 成功通知
            await notify(
                title: "阅读分析完成",
                body: extractOneLiner(from: result) ?? "\(books.count) 本书的分析报告已生成，点击查看。"
            )

        } catch {
            let msg = error.localizedDescription
            state = .failed(msg)
            await notify(title: "阅读分析失败", body: msg, isError: true)
        }
    }

    // MARK: 发本地通知
    private func notify(title: String, body: String, isError: Bool = false) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = isError ? .defaultCritical : .default

        let req = UNNotificationRequest(
            identifier: "diagnosis-\(UUID().uuidString)",
            content: content,
            trigger: nil   // 立即发送
        )
        try? await center.add(req)
    }

    // 从报告里提取「一句话总结」作为通知 body
    private func extractOneLiner(from report: String) -> String? {
        let lines = report.components(separatedBy: .newlines)
        var capture = false
        for line in lines {
            if line.contains("一句话总结") { capture = true; continue }
            if capture {
                let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "#>*_"))
                    .trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { return t }
            }
        }
        return nil
    }

    private func parseNotes(
        book: LibraryBook,
        bookmarks: [String: Any],
        reviews: [String: Any]
    ) -> [ReadingNote] {
        let highlights = (bookmarks["updated"] as? [[String: Any]] ?? []).compactMap { item -> ReadingNote? in
            guard let text = item["markText"] as? String, !text.isEmpty else { return nil }
            let rawID = item["bookmarkId"] as? String ?? UUID().uuidString
            return ReadingNote(
                id: "\(book.id)-highlight-\(rawID)",
                bookID: book.id,
                bookTitle: book.title,
                kind: .highlight,
                sourceText: text,
                noteText: ""
            )
        }
        let thoughts = (reviews["reviews"] as? [[String: Any]] ?? []).compactMap { item -> ReadingNote? in
            guard let review = item["review"] as? [String: Any],
                  let content = review["content"] as? String,
                  !content.isEmpty else { return nil }
            let source = review["abstract"] as? String ?? ""
            let rawID = review["reviewId"] as? String ?? UUID().uuidString
            return ReadingNote(
                id: "\(book.id)-thought-\(rawID)",
                bookID: book.id,
                bookTitle: book.title,
                kind: .thought,
                sourceText: source.isEmpty ? "（无对应原文）" : source,
                noteText: content
            )
        }
        return highlights + thoughts
    }

    private func buildPrompt(books: [LibraryBook], notes: [ReadingNote]) -> String {
        var parts: [String] = []
        parts.append("【分析范围】\(books.count) 本书，\(notes.count) 条记录")
        for book in books {
            parts.append("\n【书籍】《\(book.title)》 / \(book.author) / \(book.category)")
            notes.filter { $0.bookID == book.id }.prefix(80).enumerated().forEach { index, note in
                if note.noteText.isEmpty {
                    parts.append("\(index + 1). [\(note.kind.rawValue)]「\(note.sourceText)」")
                } else {
                    parts.append("\(index + 1). [原文]「\(note.sourceText)」→ [我的想法] \(note.noteText)")
                }
            }
        }
        return parts.joined(separator: "\n")
    }
}
