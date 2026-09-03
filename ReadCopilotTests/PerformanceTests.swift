import XCTest
@testable import ReadCopilot

final class PerformanceTests: XCTestCase {
    private func makeBooks(count: Int) -> [LibraryBook] {
        (0..<count).map { index in
            LibraryBook(
                id: "book-\(index)",
                title: "图书 \(index)",
                author: "作者 \(index)",
                cover: "",
                category: index % 2 == 0 ? "管理" : "心理",
                finished: index % 3 == 0,
                secret: false,
                readUpdateTime: index,
                isAlbum: false
            )
        }
    }

    private func makeNotes(books: [LibraryBook], perBook: Int) -> [ReadingNote] {
        books.flatMap { book in
            (0..<perBook).map { index in
                ReadingNote(
                    id: "\(book.id)-\(index)",
                    bookID: book.id,
                    bookTitle: book.title,
                    kind: .thought,
                    sourceText: "第 \(index) 条原文，关于\(book.category)和长期学习。",
                    noteText: "我的反思 \(index)：把概念应用到真实场景。"
                )
            }
        }
    }

    func testPromptBuildPerformance() {
        let books = makeBooks(count: 24)
        let notes = makeNotes(books: books, perBook: 20)
        measure {
            _ = AnalysisService.buildPrompt(books: books, notes: notes)
        }
    }

    func testMarkdownExportPerformance() {
        let books = makeBooks(count: 1)
        let notes = makeNotes(books: books, perBook: 400)
        measure {
            _ = ReportExporter.markdown(
                title: "性能测试",
                author: "ReadCopilot",
                report: "## 总结\n内容",
                notes: notes
            )
        }
    }

    func testTopicParsingPerformance() {
        let pairs = (0..<600).map { "\"id-\($0)\":[\"主题\($0 % 9)\",\"方法论\"]" }
        let payload = "{\"topics\":{\(pairs.joined(separator: ","))}}"
        measure {
            _ = TopicExtractionService.parseTopics(from: payload)
        }
    }
}
