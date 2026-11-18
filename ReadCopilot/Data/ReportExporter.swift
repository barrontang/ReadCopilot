import CoreGraphics
import CoreText
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .pdf, .html] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum ReportExporter {
    static func notesMarkdown(title: String, author: String, notes: [ReadingNote]) -> String {
        var sections = [
            "# 《\(title)》划线与笔记",
            author.isEmpty ? "" : "**作者：** \(author)",
            "**导出时间：** \(Date().formatted(.iso8601.year().month().day()))",
            "",
            "共 \(notes.count) 条记录",
            "",
            "## 划线原文与对应笔记"
        ]

        for (index, note) in notes.enumerated() {
            sections.append("\n### \(index + 1). \(note.kind.rawValue)")
            sections.append("\n> \(note.sourceText.replacingOccurrences(of: "\n", with: "\n> "))")
            sections.append(note.noteText.isEmpty ? "\n**我的笔记：** （无）" : "\n**我的笔记：** \(note.noteText)")
        }
        return sections.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    static func markdown(
        title: String,
        author: String,
        report: String,
        notes: [ReadingNote],
        briefs: [NoteBrief] = []
    ) -> String {
        var sections = [
            "# \(title)",
            "",
            author.isEmpty ? "" : "**作者：** \(author)",
            "**生成时间：** \(Date().formatted(.iso8601.year().month().day()))",
            "",
            report
        ]

        if !briefs.isEmpty {
            sections.append("")
            sections.append("## 本地指标（确定性计算）")
            sections.append("")
            sections.append(briefsMarkdown(briefs))
        }

        sections.append("")
        sections.append("## 原文与笔记")

        for (index, note) in notes.enumerated() {
            sections.append("\n### \(index + 1). \(note.bookTitle) · \(note.kind.rawValue)")
            sections.append("\n> \(note.sourceText.replacingOccurrences(of: "\n", with: "\n> "))")
            if !note.noteText.isEmpty {
                sections.append("\n**我的笔记：** \(note.noteText)")
            }
        }
        return sections.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// 单文件 Apple 风格 HTML 报告（内联 CSS、封面 data URI 或占位图）。
    static func html(
        title: String,
        author: String,
        templateName: String,
        report: String,
        briefs: [NoteBrief] = [],
        cover: ReportCover? = nil
    ) -> String {
        ReportHTMLBuilder.report(
            title: title,
            author: author,
            templateName: templateName,
            report: report,
            briefs: briefs,
            cover: cover
        )
    }

    /// 本地生成的划线整理本：不调用 LLM，按章节与记录顺序输出。
    static func notesHTML(book: LibraryBook, notes: [ReadingNote], cover: ReportCover? = nil) -> String {
        ReportHTMLBuilder.notesBook(book: book, notes: notes, cover: cover)
    }

    static func pdf(from text: String) -> Data {
        let printableText = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "暂无内容" : text
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        // PingFang 缺失时回退系统字体，保证中文可渲染
        let preferred = CTFontCreateWithName("PingFangSC-Regular" as CFString, 11, nil)
        let font = CTFontCopyPostScriptName(preferred) as String == "PingFangSC-Regular"
            ? preferred
            : CTFontCreateUIFontForLanguage(.system, 11, "zh-Hans" as CFString) ?? preferred

        let attributed = NSAttributedString(
            string: printableText,
            attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String):
                    CGColor(gray: 0.12, alpha: 1)
            ]
        )
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        var range = CFRange(location: 0, length: 0)

        while range.location < attributed.length {
            context.beginPDFPage(nil)
            context.saveGState()
            context.textMatrix = .identity
            context.translateBy(x: 0, y: mediaBox.height)
            context.scaleBy(x: 1, y: -1)
            let path = CGPath(rect: mediaBox.insetBy(dx: 48, dy: 48), transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, range, path, nil)
            CTFrameDraw(frame, context)
            let visible = CTFrameGetVisibleStringRange(frame)
            context.restoreGState()
            context.endPDFPage()
            guard visible.length > 0 else { break }
            range.location += visible.length
        }
        context.closePDF()
        return data as Data
    }

    // MARK: - 本地指标附录

    private static func briefsMarkdown(_ briefs: [NoteBrief]) -> String {
        var lines: [String] = []
        for brief in briefs {
            lines.append("### 《\(brief.bookTitle)》\(brief.grade.level)（\(String(format: "%.1f", brief.grade.score))/100）")
            lines.append("")
            lines.append("- \(brief.grade.verdict)")
            lines.append("- 划线 \(brief.counts.underlines) / 想法 \(brief.counts.ideas)（想法/划线 \(String(format: "%.2f", brief.ratios.ideaRate))）｜章节覆盖 \(brief.counts.chaptersWithNotes)/\(brief.counts.chaptersTotal)")
            lines.append("- 想法长度分档（按字数）：reaction \(percent(brief.ratios.ideaDepthMix.reaction))% / explain \(percent(brief.ratios.ideaDepthMix.explain))% / extend \(percent(brief.ratios.ideaDepthMix.extend))% / synthesize \(percent(brief.ratios.ideaDepthMix.synthesize))%")
            lines.append("- 关键词命中口径：reflection \(percent(brief.ratios.reflectionDensity))% / action \(percent(brief.ratios.actionRate))% / question \(percent(brief.ratios.questionRate))% / linked \(percent(brief.ratios.linkedRate))%")
            lines.append("- 中位长度：想法 \(brief.ideaMedianChars) 字 / 划线 \(brief.underlineMedianChars) 字（两组非配对分布）")
            lines.append("")
            lines.append("| 因子 | 数值 | 得分/满分 | 规则 |")
            lines.append("|---|---|---|---|")
            for factor in brief.factors {
                lines.append("| \(factor.label) | \(factor.display) | \(String(format: "%.1f", factor.points))/\(Int(factor.maxPoints)) | \(factor.rule) |")
            }
            lines.append("")
            lines.append("读法处方：\(brief.prescription.combo.joined(separator: " + "))｜触发：\(brief.prescription.trigger)｜明天第一步：\(brief.prescription.firstStep)")
            lines.append("")
            lines.append("> 指标口径：depth mix 为字数分档；reflection/action/question 为关键词命中；两个中位数非配对；章节密度仅表示笔记覆盖，不代表读完或跳过。")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private static func percent(_ value: Double) -> Int {
        Int((value * 100).rounded(.down))
    }
}
