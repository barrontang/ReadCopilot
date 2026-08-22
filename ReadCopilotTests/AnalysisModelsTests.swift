import XCTest
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
}
