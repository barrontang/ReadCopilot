import Foundation

// MARK: - 阅读分析服务
// 职责：从 KeyStore 构建 LLM 客户端、组装「本地指标 + 带 ID 的笔记语料」Prompt、
// 执行分析、提取摘要。Prompt 构建与摘要提取为纯函数，便于单测。

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

    /// 兼容旧调用：没有本地指标时仍然可以分析，但报告质量会下降。
    func analyze(
        books: [LibraryBook],
        notes: [ReadingNote],
        template: AnalysisTemplate
    ) async throws -> String {
        try await analyze(books: books, notes: notes, briefs: [], template: template, purpose: "")
    }

    /// 执行阅读分析，返回 Markdown 报告。
    func analyze(
        books: [LibraryBook],
        notes: [ReadingNote],
        briefs: [NoteBrief],
        template: AnalysisTemplate,
        purpose: String = ""
    ) async throws -> String {
        let client = try makeClient()
        return try await client.chat(
            system: template.systemPrompt,
            user: Self.buildPrompt(
                books: books,
                notes: notes,
                briefs: briefs,
                template: template,
                purpose: purpose
            ),
            maxTokens: template.maxTokens,
            timeout: template == .diagnosis ? 240 : 180
        )
    }

    // MARK: Prompt

    /// 纯函数：书籍 + 笔记 + 本地指标 → 分析 Prompt。
    static func buildPrompt(
        books: [LibraryBook],
        notes: [ReadingNote],
        briefs: [NoteBrief] = [],
        template: AnalysisTemplate? = nil,
        purpose: String = ""
    ) -> String {
        var parts: [String] = []
        parts.append("【分析范围】\(books.count) 本书，\(notes.count) 条记录")
        if let template {
            parts.append("【报告模板】\(template.rawValue)（\(template.tagline)）")
        }
        if !purpose.isEmpty {
            parts.append("【阅读目的】\(purpose)")
        }

        let briefByBook = Dictionary(
            briefs.map { ($0.bookID, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for book in books {
            parts.append("\n【书籍】《\(book.title)》 / \(book.author) / \(book.category)")
            if let brief = briefByBook[book.id] {
                parts.append(briefMarkdown(brief))
            }
            let bookNotes = notes.filter { $0.bookID == book.id }
            if bookNotes.isEmpty {
                if template?.requiresNotes == false {
                    parts.append("【笔记】本次未提供笔记；以下建议只能依据书名、作者、类别与阅读目的，不得声称了解书的内容或读者的笔记。")
                } else {
                    parts.append("【笔记】该书没有可用笔记。不要编造，报告 0 条并说明这是空笔记本。")
                }
                continue
            }

            parts.append("\n【笔记语料（引用时必须带 ID）】")
            let citationByNote = briefByBook[book.id]?.citationIDs ?? [:]
            let limit = 160
            for (index, note) in bookNotes.prefix(limit).enumerated() {
                let chapter = note.chapter.isEmpty ? "未标注章节" : note.chapter
                let citation = citationByNote[note.id] ?? fallbackCitation(for: note, index: index)
                if note.kind == .highlight {
                    parts.append("(\(citation)｜\(chapter)) 「\(singleLine(note.sourceText))」")
                } else {
                    let source = note.sourceText.isEmpty || note.sourceText == "（无对应原文）"
                        ? ""
                        : "「\(singleLine(note.sourceText))」→ "
                    parts.append("(\(citation)｜\(chapter)) \(source)\(singleLine(note.noteText))")
                }
            }
            if bookNotes.count > limit {
                parts.append("（该书的笔记语料已截断，仅保留前 \(limit) 条；候选证据块中仍包含按论证价值排序的高价值笔记。）")
            }
        }

        let shared = NoteMetrics.sharedThemes(briefs: briefs)
        if !shared.isEmpty {
            parts.append("\n【跨书共同主题（2-gram / 英文词交集，出现于 ≥2 本书）】")
            for theme in shared {
                parts.append("- \(theme.keyword)：\(theme.bookTitles.map { "《\($0)》" }.joined(separator: "、"))")
            }
        }

        parts.append("""

        【引用格式】划线（U001）；想法（R001）；多本书（B2-R003）。
        【再次提醒】等级与比率来自本地计算，照抄；不得重算、不得承诺提分；证据不足就写「依据不足」或「待补录」，并说明还缺什么数据。
        """)

        return parts.joined(separator: "\n")
    }

    // MARK: 指标块

    private static func briefMarkdown(_ brief: NoteBrief) -> String {
        var lines: [String] = []
        lines.append("【本地指标（确定性计算，照抄，不要重算）】")
        lines.append("- 笔记质量等级：\(brief.grade.level)（\(String(format: "%.1f", brief.grade.score))/100）——\(brief.grade.verdict)")
        lines.append("- 划线 \(brief.counts.underlines) / 想法 \(brief.counts.ideas)（想法/划线=\(String(format: "%.2f", brief.ratios.ideaRate))）｜章节覆盖 \(brief.counts.chaptersWithNotes)/\(brief.counts.chaptersTotal)")
        if let span = brief.dateSpan {
            lines.append("- 日期跨度（createTime 按天）：\(span.first) → \(span.last)｜有笔记的天数 \(span.distinctTimeKeys)")
        } else {
            lines.append("- 日期跨度：语料缺少 createTime，待补录")
        }
        lines.append("- 想法长度分档（按字数）：reaction \(percent(brief.ratios.ideaDepthMix.reaction))% / explain \(percent(brief.ratios.ideaDepthMix.explain))% / extend \(percent(brief.ratios.ideaDepthMix.extend))% / synthesize \(percent(brief.ratios.ideaDepthMix.synthesize))%")
        lines.append("- 关键词命中口径：reflection \(percent(brief.ratios.reflectionDensity))% / action \(percent(brief.ratios.actionRate))% / question \(percent(brief.ratios.questionRate))% / firstPerson \(percent(brief.ratios.firstPersonRate))% / linked \(percent(brief.ratios.linkedRate))% / orphan \(percent(brief.ratios.orphanRate))%")
        lines.append("- 中位长度：想法 \(brief.ideaMedianChars) 字 / 划线 \(brief.underlineMedianChars) 字（两组非配对分布）")
        lines.append("- 章节集中度 topChapterShare \(String(format: "%.2f", brief.ratios.topChapterShare))（1 − 该值即章节分散因子）")
        if !brief.keywords.isEmpty {
            lines.append("- 高频词（2-gram / 英文词，出现 ≥2 次）：\(brief.keywords.joined(separator: "、"))")
        }

        lines.append("【七因子（得分/满分）】")
        for factor in brief.factors {
            lines.append("- \(factor.label)：\(factor.display)｜\(String(format: "%.1f", factor.points))/\(Int(factor.maxPoints))｜\(factor.rule)")
        }

        lines.append("【自动诊断（可作报告证据）】")
        for diagnosis in brief.diagnoses {
            lines.append("- \(diagnosis)")
        }

        lines.append("【章节密度（原始条数，未做跨章去重）】")
        lines.append("| 章节 | 划线 | 想法 | 笔记 |")
        lines.append("|---|---|---|---|")
        for chapter in brief.chapters.prefix(10) {
            lines.append("| \(singleLine(chapter.chapter)) | \(chapter.underlines) | \(chapter.ideas) | \(chapter.notes) |")
        }
        if !brief.untouchedChapters.isEmpty {
            lines.append("未被笔记覆盖的章节：\(brief.untouchedChapters.prefix(10).joined(separator: "；"))")
        }
        if !brief.bursts.isEmpty {
            lines.append("爆发阅读日（按天，≥3 条且不低于前一天的 2 倍）：\(brief.bursts.map { "\($0.date)（\($0.notes) 条）" }.joined(separator: "、"))")
        }

        lines.append("【候选证据（按论证价值排序；引用方括号内 ID）】")
        if brief.evidence.isEmpty {
            lines.append("- 无可用证据。")
        } else {
            for (index, evidence) in brief.evidence.enumerated() {
                let source = evidence.sourceText.isEmpty || evidence.sourceText == "（无对应原文）"
                    ? ""
                    : "「\(singleLine(evidence.sourceText))」→ "
                lines.append("\(index + 1). (\(evidence.citationID)｜\(evidence.chapter.isEmpty ? "未标注章节" : evidence.chapter)) \(source)\(singleLine(evidence.displayText))")
            }
        }
        if !brief.reactions.isEmpty {
            lines.append("【短反应（只用于判断阅读情绪，不作论据）】")
            for reaction in brief.reactions {
                lines.append("- (\(reaction.citationID)) \(singleLine(reaction.noteText))")
            }
        }

        lines.append("【读法处方（与报告第 6、7 维使用同一组合）】")
        lines.append("- 阶段：\(brief.prescription.stage.rawValue)")
        lines.append("- 方法组合：\(brief.prescription.combo.joined(separator: " + "))")
        lines.append("- 触发信号：\(brief.prescription.trigger)")
        lines.append("- 会移动的指标：\(brief.prescription.metricMoved)")
        lines.append("- 明天第一步：\(brief.prescription.firstStep)")
        lines.append("- 命中映射：\(brief.prescription.mappedRow)")
        lines.append("- 为什么不是其他方法：\(brief.prescription.whyNot)")

        return lines.joined(separator: "\n")
    }

    // MARK: 摘要

    /// 纯函数：从报告提取「一句话总结」段落，用于通知正文；没有该标题时取第一段正文。
    static func extractOneLiner(from report: String) -> String? {
        let lines = report.components(separatedBy: .newlines)
        var capture = false
        for line in lines {
            if line.contains("一句话总结") { capture = true; continue }
            if capture {
                let text = clean(line)
                if !text.isEmpty { return text }
            }
        }
        for line in lines {
            let text = clean(line)
            guard !text.isEmpty else { continue }
            if text.hasPrefix("#") || text.hasPrefix("|") || text.hasPrefix("-")
                || text.hasPrefix(">") || text == "---" { continue }
            return text
        }
        return nil
    }

    private static func clean(_ line: String) -> String {
        line.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#>*_"))
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: 小工具

    private static func fallbackCitation(for note: ReadingNote, index: Int) -> String {
        let prefix = note.kind == .highlight ? "U" : "R"
        return "\(prefix)\(String(format: "%03d", index + 1))"
    }

    private static func singleLine(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func percent(_ value: Double) -> Int {
        Int((value * 100).rounded(.down))
    }
}
