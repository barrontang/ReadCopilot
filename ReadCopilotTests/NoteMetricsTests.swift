import XCTest
@testable import ReadCopilot

// MARK: - 本地指标与导出契约
//
// 这些测试锁定 reading-notes 技能的三条硬约束：
// 1. 等级只由七因子计算，不由 LLM 生成；
// 2. 引用 ID 稳定（U### / R### / 多书 B2-R###）；
// 3. 单文件 HTML 不包含远程资源或脚本，指标口径随报告披露。

final class NoteMetricsTests: XCTestCase {

    // MARK: 构造器

    private func makeBook(
        id: String = "b1",
        title: String = "测试书",
        author: String = "作者",
        category: String = "认知"
    ) -> LibraryBook {
        LibraryBook(
            id: id,
            title: title,
            author: author,
            cover: "",
            category: category,
            finished: false,
            secret: false,
            readUpdateTime: 0,
            isAlbum: false
        )
    }

    private func makeNote(
        id: String,
        kind: ReadingNote.Kind,
        book: LibraryBook,
        source: String = "",
        note: String = "",
        chapter: String = "",
        quoteID: String? = nil,
        createdAt: Int = 0
    ) -> ReadingNote {
        ReadingNote(
            id: id,
            bookID: book.id,
            bookTitle: book.title,
            kind: kind,
            sourceText: source,
            noteText: note,
            chapter: chapter,
            createdAt: createdAt,
            quoteID: quoteID
        )
    }

    private func richNotes(book: LibraryBook) -> [ReadingNote] {
        let highlightTexts = [
            "习惯是重复足够多次后自动化的行为。",
            "环境线索比意志力更稳定。",
            "身份认同改变会带来长期行为改变。",
            "小胜利可以积累自我效能。"
        ]
        var notes = highlightTexts.enumerated().map { index, text in
            makeNote(
                id: "u\(index + 1)",
                kind: .highlight,
                book: book,
                source: text,
                chapter: "第\(index + 1)章",
                createdAt: 1_700_000_000 + index * 86_400
            )
        }
        let ideas = [
            "因为环境线索更稳定，所以我要先改造书桌，而不是重复发誓。",
            "如果身份先改变，那么行为会跟随；这意味着自我介绍也要改写。",
            "习惯回路不是线性的，相反它会被奖励强化。因此复盘要盯住奖励。",
            "把目标缩小到两分钟，先开始，再逐步扩展；否则计划会被阻力吞掉。"
        ]
        notes += ideas.enumerated().map { index, text in
            makeNote(
                id: "r\(index + 1)",
                kind: .thought,
                book: book,
                source: highlightTexts[index],
                note: text,
                chapter: "第\(index + 1)章",
                quoteID: "u\(index + 1)",
                createdAt: 1_700_000_000 + index * 86_400
            )
        }
        return notes
    }

    // MARK: 等级

    func testGradeUsesSevenFactorsAndCapsAtOneHundred() {
        let ratios = NoteRatios(
            ideaRate: 1.0,
            ideaDepthMix: DepthMix(reaction: 0, explain: 0, extend: 1, synthesize: 1),
            reflectionDensity: 0.6,
            actionRate: 0.4,
            questionRate: 0.3,
            firstPersonRate: 1,
            linkedRate: 1,
            orphanRate: 0,
            topChapterShare: 0
        )
        let counts = NoteCounts(
            underlines: 10,
            ideas: 10,
            notes: 20,
            chaptersTotal: 10,
            chaptersWithNotes: 10
        )

        let result = NoteMetrics.evaluateGrade(ratios: ratios, counts: counts)

        XCTAssertEqual(result.factors.count, 7)
        XCTAssertEqual(result.factors.map(\.key), [
            "idea", "depth", "reflection", "action", "question", "linked", "spread"
        ])
        XCTAssertEqual(result.factors.map(\.maxPoints).reduce(0, +), 100)
        XCTAssertEqual(result.grade.score, 100, accuracy: 0.01)
        XCTAssertEqual(result.grade.level, "A")
    }

    func testGradeWithoutIdeasIsDAndPrescriptionStartsAtCornell() {
        let book = makeBook()
        let notes = (1...4).map { index in
            makeNote(
                id: "u\(index)",
                kind: .highlight,
                book: book,
                source: String(repeating: "原文", count: 20),
                chapter: "第\(index)章"
            )
        }

        let brief = NoteMetrics.compute(notes: notes, book: book)

        XCTAssertEqual(brief.counts.ideas, 0)
        XCTAssertEqual(brief.grade.level, "D")
        XCTAssertTrue(brief.diagnoses.first?.contains("只有划线") == true)
        XCTAssertFalse(brief.evidence.isEmpty)
        XCTAssertTrue(brief.evidence.allSatisfy { $0.kind == .highlight })
        XCTAssertTrue(brief.prescription.combo.contains("康奈尔（线索栏）"))
        XCTAssertFalse(brief.prescription.firstStep.isEmpty)
    }

    // MARK: 指标口径

    func testDepthMixUsesCharacterBuckets() {
        let book = makeBook()
        var notes = [
            makeNote(id: "u1", kind: .highlight, book: book, source: "原文一"),
            makeNote(id: "u2", kind: .highlight, book: book, source: "原文二"),
            makeNote(id: "u3", kind: .highlight, book: book, source: "原文三"),
            makeNote(id: "u4", kind: .highlight, book: book, source: "原文四")
        ]
        let lengths = [10, 20, 60, 130]
        notes += lengths.enumerated().map { index, length in
            makeNote(
                id: "r\(index + 1)",
                kind: .thought,
                book: book,
                note: String(repeating: "字", count: length)
            )
        }

        let brief = NoteMetrics.compute(notes: notes, book: book)
        let mix = brief.ratios.ideaDepthMix

        XCTAssertEqual(mix.reaction, 0.25, accuracy: 0.001)
        XCTAssertEqual(mix.explain, 0.25, accuracy: 0.001)
        XCTAssertEqual(mix.extend, 0.25, accuracy: 0.001)
        XCTAssertEqual(mix.synthesize, 0.25, accuracy: 0.001)
        XCTAssertEqual(brief.ratios.ideaRate, 1.0, accuracy: 0.001)
    }

    func testCitationIDsAreStableAndMultiBookPrefixed() {
        let first = makeBook(id: "b1", title: "第一本")
        let second = makeBook(id: "b2", title: "第二本")

        let firstBrief = NoteMetrics.compute(
            notes: richNotes(book: first),
            book: first,
            chapterTitles: ["第1章", "第2章", "第3章", "第4章"]
        )
        let secondBrief = NoteMetrics.compute(
            notes: richNotes(book: second),
            book: second,
            idPrefix: "B2-"
        )

        XCTAssertEqual(firstBrief.citationIDs["u1"], "U001")
        XCTAssertEqual(firstBrief.citationIDs["r1"], "R001")
        XCTAssertEqual(secondBrief.citationIDs["u1"], "B2-U001")
        XCTAssertEqual(secondBrief.citationIDs["r1"], "B2-R001")
        XCTAssertEqual(firstBrief.counts.chaptersWithNotes, 4)
        XCTAssertEqual(firstBrief.counts.chaptersTotal, 4)
        XCTAssertTrue(firstBrief.untouchedChapters.isEmpty)
    }

    func testSharedThemesRequireTwoBooks() {
        let first = makeBook(id: "b1", title: "第一本")
        let second = makeBook(id: "b2", title: "第二本")
        let firstNotes = [
            makeNote(id: "a1", kind: .highlight, book: first, source: "习惯养成需要环境"),
            makeNote(id: "a2", kind: .thought, book: first, source: "习惯回路", note: "习惯回路值得记录")
        ]
        let secondNotes = [
            makeNote(id: "b1", kind: .highlight, book: second, source: "习惯来自重复"),
            makeNote(id: "b2", kind: .thought, book: second, source: "习惯设计", note: "习惯设计要降低阻力")
        ]

        let briefs = [
            NoteMetrics.compute(notes: firstNotes, book: first),
            NoteMetrics.compute(notes: secondNotes, book: second)
        ]
        let themes = NoteMetrics.sharedThemes(briefs: briefs)

        XCTAssertTrue(themes.contains { $0.keyword == "习惯" && $0.bookTitles.count == 2 })
        XCTAssertTrue(NoteMetrics.sharedThemes(briefs: [briefs[0]]).isEmpty)
    }

    // MARK: Prompt 注入

    func testPromptInjectsBriefCitationsAndPurpose() {
        let book = makeBook()
        let notes = richNotes(book: book)
        let brief = NoteMetrics.compute(notes: notes, book: book, chapterTitles: ["第1章"])

        let prompt = AnalysisService.buildPrompt(
            books: [book],
            notes: notes,
            briefs: [brief],
            template: .method,
            purpose: "写作"
        )

        XCTAssertTrue(prompt.contains("【本地指标（确定性计算，照抄，不要重算）】"))
        XCTAssertTrue(prompt.contains("【阅读目的】写作"))
        XCTAssertTrue(prompt.contains("【报告模板】读法处方"))
        XCTAssertTrue(prompt.contains("(U001"))
        XCTAssertTrue(prompt.contains("【读法处方（与报告第 6、7 维使用同一组合）】"))
        XCTAssertFalse(AnalysisTemplate.method.requiresNotes)
        XCTAssertTrue(AnalysisTemplate.diagnosis.requiresNotes)
    }

    // MARK: HTML 导出

    func testHTMLReportIsSelfContainedAndCarriesEvidence() {
        let book = makeBook()
        let notes = richNotes(book: book)
        let brief = NoteMetrics.compute(notes: notes, book: book, chapterTitles: ["第1章", "第2章"])

        let html = ReportExporter.html(
            title: book.title,
            author: book.author,
            templateName: AnalysisTemplate.diagnosis.rawValue,
            report: "## 1. 阅读概览\n\n| 项目 | 数值 |\n|---|---|\n| 想法 | 4 |\n\n核心洞见（U001）。",
            briefs: [brief]
        )

        XCTAssertTrue(html.hasPrefix("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("笔记体检"))
        XCTAssertTrue(html.contains("七因子"))
        XCTAssertTrue(html.contains("U001"))
        XCTAssertTrue(html.contains("data:image/svg+xml") || html.contains("封面占位图"))
        XCTAssertFalse(html.contains("<script"))
        XCTAssertFalse(html.contains("http://"))
        XCTAssertFalse(html.contains("https://"))
        XCTAssertFalse(html.contains("<link rel=\"stylesheet\""))
        XCTAssertTrue(html.contains("指标口径"))
    }

    func testMethodHTMLWithoutBriefsOmitsZeroKPIs() {
        let html = ReportExporter.html(
            title: "测试书",
            author: "作者",
            templateName: AnalysisTemplate.method.rawValue,
            report: "## 目的与书型\n\n尚未指定阅读目的。",
            briefs: []
        )

        XCTAssertTrue(html.contains("读法处方"))
        XCTAssertTrue(html.contains("本次未提供笔记"))
        XCTAssertTrue(html.contains("本次未计算笔记指标"))
        XCTAssertFalse(html.contains("想法率"))
    }

    func testHTMLMultiBookReportShowsComparison() {
        let first = makeBook(id: "b1", title: "第一本")
        let second = makeBook(id: "b2", title: "第二本")
        let briefs = [
            NoteMetrics.compute(notes: richNotes(book: first), book: first, idPrefix: "B1-"),
            NoteMetrics.compute(notes: richNotes(book: second), book: second, idPrefix: "B2-")
        ]

        let html = ReportExporter.html(
            title: "跨书阅读分析",
            author: "",
            templateName: AnalysisTemplate.synthesis.rawValue,
            report: "## 跨书对比\n\n正文。",
            briefs: briefs
        )

        XCTAssertTrue(html.contains("主题地图"))
        XCTAssertTrue(html.contains("本书对比"))
        XCTAssertTrue(html.contains("第一本"))
        XCTAssertTrue(html.contains("第二本"))
        XCTAssertTrue(html.contains("单书等级只解释该书笔记"))
    }

    func testNotesHTMLPreservesOriginalTextAndGroupsChapters() {
        let book = makeBook()
        let notes = [
            makeNote(id: "u1", kind: .highlight, book: book, source: "第一段原文\n第二行", chapter: "第一章"),
            makeNote(id: "r1", kind: .thought, book: book, source: "第一段原文", note: "我的想法", chapter: "第一章"),
            makeNote(id: "u2", kind: .highlight, book: book, source: "另一章原文", chapter: "第二章")
        ]

        let html = ReportExporter.notesHTML(book: book, notes: notes)

        XCTAssertTrue(html.contains("划线整理本"))
        XCTAssertTrue(html.contains("第一章"))
        XCTAssertTrue(html.contains("第二章"))
        XCTAssertTrue(html.contains("第一段原文"))
        XCTAssertTrue(html.contains("我的想法"))
        XCTAssertTrue(html.contains("未调用 LLM"))
        XCTAssertFalse(html.contains("<script"))
        XCTAssertFalse(html.contains("https://"))
    }

    func testMarkdownAppendixIncludesLocalMetrics() {
        let book = makeBook()
        let brief = NoteMetrics.compute(notes: richNotes(book: book), book: book)

        let markdown = ReportExporter.markdown(
            title: "《测试书》阅读分析",
            author: book.author,
            report: "## 结论\n正文",
            notes: [],
            briefs: [brief]
        )

        XCTAssertTrue(markdown.contains("## 本地指标（确定性计算）"))
        XCTAssertTrue(markdown.contains("| 想法率 |"))
        XCTAssertTrue(markdown.contains("读法处方："))
        XCTAssertTrue(markdown.contains("指标口径"))
        XCTAssertTrue(markdown.contains("想法长度分档"))
    }
}
