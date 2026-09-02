import Foundation

// MARK: - 阅读分析服务
// 职责：从 KeyStore 构建 LLM 客户端、组 Prompt、执行分析、提取摘要。
// Prompt 构建与摘要提取为纯函数，便于单测。

struct AnalysisService {
    let keyStore: any KeyStore

    init(keyStore: any KeyStore = KeychainKeyStore()) {
        self.keyStore = keyStore
    }

    enum ConfigError: LocalizedError {
        case missingLLMConfig

        var errorDescription: String? {
            "未设置阅读分析模型，请到设置页填写并点击「测试连接并保存」"
        }
    }

    /// 从 KeyStore 读取配置构建 LLM 客户端（Ollama 允许空 Key）。
    func makeClient() throws -> LLMClient {
        guard let base = keyStore.get(.llmBaseURL), !base.isEmpty,
              let model = keyStore.get(.llmModel), !model.isEmpty else {
            throw ConfigError.missingLLMConfig
        }
        return LLMClient(
            apiKey: keyStore.get(.llmAPIKey) ?? "",
            baseURL: base,
            model: model
        )
    }

    /// 执行阅读分析，返回 Markdown 报告。
    func analyze(
        books: [LibraryBook],
        notes: [ReadingNote],
        template: AnalysisTemplate
    ) async throws -> String {
        let client = try makeClient()
        return try await client.chat(
            system: template.systemPrompt,
            user: Self.buildPrompt(books: books, notes: notes),
            maxTokens: template == .bookReview ? 3200 : 2200,
            timeout: 180
        )
    }

    /// 纯函数：书籍 + 笔记 → 分析 Prompt
    static func buildPrompt(books: [LibraryBook], notes: [ReadingNote]) -> String {
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

    /// 纯函数：从报告提取「一句话总结」段落，用于通知正文。
    static func extractOneLiner(from report: String) -> String? {
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
}
