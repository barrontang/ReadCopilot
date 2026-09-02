import Foundation

// MARK: - 主题提取服务
// 用 LLM 从知识条目批量提取主题标签，输出 条目ID → [主题]。
// 主题是「主题↔原文↔书籍」三层可追溯知识图谱的中间层。

struct TopicExtractionService {
    let keyStore: any KeyStore

    init(keyStore: any KeyStore = KeychainKeyStore()) {
        self.keyStore = keyStore
    }

    static let systemPrompt = """
    你是知识整理助手。为每条阅读笔记提取 1-3 个主题标签。
    要求：标签为 2-6 个汉字的抽象概念（如「决策心理」「团队管理」「时间观」），\
    同类内容用同一标签，不要照抄原文词句。
    只输出 JSON，格式：{"topics":{"<条目ID>":["主题1","主题2"]}}
    """

    /// 批量提取主题（每批最多 batchSize 条），返回 条目ID → 主题列表。
    /// 单批失败不中断整体，返回已成功的部分。
    func extractTopics(
        for entries: [KnowledgeEntry],
        batchSize: Int = 20
    ) async throws -> [String: [String]] {
        let analysisService = AnalysisService(keyStore: keyStore)
        let client = try analysisService.makeClient()

        var result: [String: [String]] = [:]
        for batchStart in stride(from: 0, to: entries.count, by: batchSize) {
            let batch = Array(entries[batchStart..<min(batchStart + batchSize, entries.count)])
            let reply = try await client.chat(
                system: Self.systemPrompt,
                user: Self.buildBatchPrompt(batch),
                maxTokens: 1600,
                timeout: 180
            )
            result.merge(Self.parseTopics(from: reply)) { _, new in new }
        }
        return result
    }

    /// 纯函数：一批条目 → 提取 Prompt
    static func buildBatchPrompt(_ entries: [KnowledgeEntry]) -> String {
        var parts = ["为以下 \(entries.count) 条笔记提取主题："]
        for entry in entries {
            var line = "ID: \(entry.id)\n书籍：《\(entry.bookTitle)》\n原文：\(entry.sourceText.prefix(200))"
            if !entry.noteText.isEmpty {
                line += "\n笔记：\(entry.noteText.prefix(200))"
            }
            parts.append(line)
        }
        return parts.joined(separator: "\n---\n")
    }

    /// 纯函数：模型回复 → 条目ID → 主题。容忍 JSON 前后多余文字。
    static func parseTopics(from reply: String) -> [String: [String]] {
        guard let start = reply.firstIndex(of: "{"),
              let end = reply.lastIndex(of: "}") else { return [:] }
        let jsonText = String(reply[start...end])
        guard let data = jsonText.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let topics = json["topics"] as? [String: [String]] else { return [:] }
        return topics.mapValues { list in
            list.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }
}
