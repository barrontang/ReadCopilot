import Foundation

// MARK: - 诊断引擎:拉单本书笔记 → 组 prompt → 调 LLM → 流式输出诊断报告

@MainActor
final class DiagnosisModel: ObservableObject {
    @Published var state: State = .idle
    @Published var report: String = ""

    enum State: Equatable {
        case idle
        case fetchingNotes
        case generating
        case done
        case failed(String)
    }

    // MARK: 主入口
    func run(book: LibraryBook) async {
        report = ""
        state = .fetchingNotes

        guard let wrKey = Keychain.get(.wereadAPIKey), wrKey.hasPrefix("wrk-") else {
            state = .failed("未设置微信读书 Key,请到设置页填入 wrk- 开头的 Key"); return
        }
        guard let llmKey = Keychain.get(.llmAPIKey), !llmKey.isEmpty,
              let llmBase = Keychain.get(.llmBaseURL), !llmBase.isEmpty,
              let llmModel = Keychain.get(.llmModel), !llmModel.isEmpty else {
            state = .failed("未设置 LLM Key,请到设置页填写并点击「测试连接并保存」"); return
        }

        do {
            // 并发拉划线 + 想法
            let gw = WeReadGateway(apiKey: wrKey)
            async let bmJSON = gw.bookmarks(bookId: book.id)
            async let rvJSON = gw.myReviews(bookId: book.id, synckey: 0, count: 100)
            let (bm, rv) = try await (bmJSON, rvJSON)

            let highlights = parseHighlights(bm)
            let thoughts = parseThoughts(rv)

            guard !highlights.isEmpty || !thoughts.isEmpty else {
                state = .failed("这本书暂无划线或想法记录,无法生成诊断。")
                return
            }

            state = .generating
            let prompt = buildPrompt(book: book, highlights: highlights, thoughts: thoughts)
            let client = LLMClient(apiKey: llmKey, baseURL: llmBase, model: llmModel)
            let result = try await client.chat(
                system: systemPrompt,
                user: prompt,
                maxTokens: 1800
            )
            report = result
            state = .done

        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: 解析划线(bookmarklist → updated[].markText)
    private func parseHighlights(_ j: [String: Any]) -> [String] {
        let arr = j["updated"] as? [[String: Any]] ?? []
        return arr.compactMap { $0["markText"] as? String }.filter { !$0.isEmpty }
    }

    // MARK: 解析想法(review/list/mine → reviews[].review.content + abstract)
    private func parseThoughts(_ j: [String: Any]) -> [(abstract: String, content: String)] {
        let arr = j["reviews"] as? [[String: Any]] ?? []
        return arr.compactMap { item -> (String, String)? in
            guard let r = item["review"] as? [String: Any],
                  let content = r["content"] as? String, !content.isEmpty else { return nil }
            let abstract = r["abstract"] as? String ?? ""
            return (abstract, content)
        }
    }

    // MARK: 组 prompt
    private func buildPrompt(book: LibraryBook, highlights: [String], thoughts: [(abstract: String, content: String)]) -> String {
        var parts: [String] = []
        parts.append("【书名】\(book.title)")
        parts.append("【作者】\(book.author)")
        parts.append("【划线原文】共 \(highlights.count) 条:")
        highlights.prefix(60).enumerated().forEach { i, h in
            parts.append("\(i+1). 「\(h)」")
        }
        if !thoughts.isEmpty {
            parts.append("\n【个人想法/点评】共 \(thoughts.count) 条:")
            thoughts.prefix(40).enumerated().forEach { i, t in
                if t.abstract.isEmpty {
                    parts.append("\(i+1). [想法] \(t.content)")
                } else {
                    parts.append("\(i+1). [原文]「\(t.abstract)」→ [想法] \(t.content)")
                }
            }
        }
        return parts.joined(separator: "\n")
    }

    // MARK: 系统 prompt
    private let systemPrompt = """
    你是一位深度阅读教练,擅长通过读者的划线与批注,分析其思考模式与写作潜力。
    你的诊断报告是一封写给读者本人的信,语气温暖、直接,有洞察力。

    报告结构(严格按此顺序,用 Markdown):
    ## 思考模式诊断
    分析这位读者的注意力偏好、思维框架、内在关切(100-150字)

    ## 写作建议
    基于ta的划线模式,给出2-3条具体可操作的写作建议,每条引用ta自己的一条划线作为证据

    ## 延伸追问
    提出2-3个能让ta深入思考的问题,帮助ta把阅读转化为写作素材

    ## 一句话总结
    用一句话描述这位读者的阅读画像(20字以内)

    语言:中文。风格:像一封私人信件,不要用表格,不要罗列评分。
    """
}
