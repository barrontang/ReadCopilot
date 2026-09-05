import XCTest
import CoreGraphics
import PDFKit
@testable import ReadCopilot

final class AnalysisModelsTests: XCTestCase {
    func testEveryTemplateRequiresEvidence() {
        for template in AnalysisTemplate.allCases {
            XCTAssertTrue(template.systemPrompt.contains("证据"))
            XCTAssertFalse(template.description.isEmpty)
        }
    }

    func testReadingPeriodMapsToSupportedAPIModes() {
        XCTAssertEqual(ReadingPeriod.weekly.apiMode, "weekly")
        XCTAssertEqual(ReadingPeriod.monthly.apiMode, "monthly")
        XCTAssertEqual(ReadingPeriod.annually.apiMode, "annually")
        XCTAssertEqual(ReadingPeriod.overall.apiMode, "overall")
    }

    func testMarkdownExportPairsSourceAndThought() {
        let note = ReadingNote(
            id: "note-1",
            bookID: "book-1",
            bookTitle: "测试书",
            kind: .thought,
            sourceText: "原文",
            noteText: "我的想法"
        )

        let result = ReportExporter.markdown(
            title: "阅读分析",
            author: "作者",
            report: "## 结论\n内容",
            notes: [note]
        )

        XCTAssertTrue(result.contains("> 原文"))
        XCTAssertTrue(result.contains("**我的笔记：** 我的想法"))
        XCTAssertTrue(result.contains("## 结论"))
    }

    func testNotesExportIncludesHighlightWithoutThought() {
        let note = ReadingNote(
            id: "highlight-1",
            bookID: "book-1",
            bookTitle: "测试书",
            kind: .highlight,
            sourceText: "划线原文",
            noteText: ""
        )

        let result = ReportExporter.notesMarkdown(title: "测试书", author: "作者", notes: [note])

        XCTAssertTrue(result.contains("> 划线原文"))
        XCTAssertTrue(result.contains("**我的笔记：** （无）"))
        XCTAssertTrue(result.contains("共 1 条记录"))
    }

    func testPDFExportProducesReadablePage() {
        let data = ReportExporter.pdf(from: "导出报告\n原文与笔记")

        assertValidPDF(data, containing: ["导出报告", "原文与笔记"])
    }

    func testAnalysisReportPDFExportFlowProducesSearchableText() {
        let note = ReadingNote(
            id: "note-1",
            bookID: "book-1",
            bookTitle: "测试书",
            kind: .thought,
            sourceText: "原文片段",
            noteText: "我的想法"
        )
        let markdown = ReportExporter.markdown(
            title: "《测试书》阅读分析",
            author: "作者",
            report: "## 结论\n分析内容",
            notes: [note]
        )

        assertValidPDF(
            ReportExporter.pdf(from: markdown),
            containing: ["测试书", "结论", "原文片段", "我的想法"]
        )
    }

    func testNotesPDFExportFlowProducesSearchableText() {
        let note = ReadingNote(
            id: "highlight-1",
            bookID: "book-1",
            bookTitle: "测试书",
            kind: .highlight,
            sourceText: "划线原文",
            noteText: ""
        )
        let markdown = ReportExporter.notesMarkdown(title: "测试书", author: "作者", notes: [note])

        assertValidPDF(
            ReportExporter.pdf(from: markdown),
            containing: ["测试书", "划线原文", "我的笔记"]
        )
    }

    func testEmptyPDFExportStillProducesReadablePage() {
        assertValidPDF(
            ReportExporter.pdf(from: "\n  "),
            containing: ["暂无内容"]
        )
    }

    func testExtractOneLinerReturnsFirstNonEmptyLine() {
        let report = """
        ## 一句话总结
        **把输入拆成更小的可验证步骤。**

        ## 细节
        说明
        """
        XCTAssertEqual(
            AnalysisService.extractOneLiner(from: report),
            "把输入拆成更小的可验证步骤。"
        )
    }

    @MainActor func testDurationFormattingHandlesHoursAndMinutes() {
        XCTAssertEqual(LibraryStore.fmtDuration(59 * 60), "59分钟")
        XCTAssertEqual(LibraryStore.fmtDuration(2 * 3600 + 15 * 60), "2小时15分钟")
    }

    private func assertValidPDF(
        _ data: Data,
        containing expectedSnippets: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(data.starts(with: Data("%PDF".utf8)), file: file, line: line)

        let provider = CGDataProvider(data: data as CFData)
        let cgDocument = provider.flatMap(CGPDFDocument.init)
        XCTAssertNotNil(cgDocument, file: file, line: line)
        XCTAssertGreaterThan(cgDocument?.numberOfPages ?? 0, 0, file: file, line: line)

        let pdfDocument = PDFDocument(data: data)
        let extractedText = pdfDocument?.string ?? ""
        for snippet in expectedSnippets {
            XCTAssertTrue(
                extractedText.contains(snippet),
                "PDF text did not contain expected snippet: \(snippet)",
                file: file,
                line: line
            )
        }
    }
}
