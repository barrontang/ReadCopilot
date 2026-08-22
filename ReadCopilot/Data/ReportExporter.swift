import CoreGraphics
import CoreText
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .pdf] }

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
    static func markdown(title: String, author: String, report: String, notes: [ReadingNote]) -> String {
        var sections = [
            "# \(title)",
            "",
            author.isEmpty ? "" : "**作者：** \(author)",
            "**生成时间：** \(Date().formatted(.iso8601.year().month().day()))",
            "",
            report,
            "",
            "## 原文与笔记"
        ]

        for (index, note) in notes.enumerated() {
            sections.append("\n### \(index + 1). \(note.bookTitle) · \(note.kind.rawValue)")
            sections.append("\n> \(note.sourceText.replacingOccurrences(of: "\n", with: "\n> "))")
            if !note.noteText.isEmpty {
                sections.append("\n**我的笔记：** \(note.noteText)")
            }
        }
        return sections.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    static func pdf(from text: String) -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        let attributed = NSAttributedString(
            string: text,
            attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String):
                    CTFontCreateWithName("PingFangSC-Regular" as CFString, 11, nil),
                NSAttributedString.Key(kCTForegroundColorAttributeName as String):
                    CGColor(gray: 0.12, alpha: 1)
            ]
        )
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        var range = CFRange(location: 0, length: 0)

        while range.location < attributed.length {
            context.beginPDFPage(nil)
            context.textMatrix = .identity
            context.translateBy(x: 0, y: mediaBox.height)
            context.scaleBy(x: 1, y: -1)
            let path = CGPath(rect: mediaBox.insetBy(dx: 48, dy: 48), transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, range, path, nil)
            CTFrameDraw(frame, context)
            let visible = CTFrameGetVisibleStringRange(frame)
            context.endPDFPage()
            guard visible.length > 0 else { break }
            range.location += visible.length
        }
        context.closePDF()
        return data as Data
    }
}
