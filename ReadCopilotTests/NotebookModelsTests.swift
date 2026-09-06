import XCTest
@testable import ReadCopilot

final class NotebookModelsTests: XCTestCase {
    func testComposeUsesFallbackOrderChain() {
        let now = Date(timeIntervalSince1970: 1_000)
        let notes: [ReadingNote] = [
            ReadingNote(
                id: "event",
                bookID: "b1",
                bookTitle: "书1",
                kind: .highlight,
                sourceText: "有时间",
                noteText: "",
                eventTime: Date(timeIntervalSince1970: 50),
                syncedAt: now
            ),
            ReadingNote(
                id: "location",
                bookID: "b1",
                bookTitle: "书1",
                kind: .highlight,
                sourceText: "有位置",
                noteText: "",
                location: 20,
                syncedAt: now
            ),
            ReadingNote(
                id: "source-order",
                bookID: "b1",
                bookTitle: "书1",
                kind: .thought,
                sourceText: "有顺序",
                noteText: "想法",
                sourceOrder: 10,
                syncedAt: now
            ),
            ReadingNote(
                id: "synced",
                bookID: "b1",
                bookTitle: "书1",
                kind: .highlight,
                sourceText: "仅同步时间",
                noteText: "",
                syncedAt: Date(timeIntervalSince1970: 5)
            )
        ]

        let entries = NotebookComposer.compose(notes: notes)
        XCTAssertEqual(entries.map(\.id), ["event", "location", "source-order", "synced"])
        XCTAssertEqual(entries.first(where: { $0.id == "event" })?.orderSource, .eventTime)
        XCTAssertEqual(entries.first(where: { $0.id == "location" })?.orderSource, .location)
        XCTAssertEqual(entries.first(where: { $0.id == "source-order" })?.orderSource, .sourceOrder)
        XCTAssertEqual(entries.first(where: { $0.id == "synced" })?.orderSource, .syncedAt)
    }

    func testGroupByDayBuildsStableBuckets() {
        let day1 = Date(timeIntervalSince1970: 86_400 * 10)
        let day2 = Date(timeIntervalSince1970: 86_400 * 11)
        let entries = [
            NotebookEntry(
                id: "a",
                note: ReadingNote(id: "a", bookID: "b", bookTitle: "书", kind: .highlight, sourceText: "1", noteText: "", eventTime: day1),
                timelineDate: day1,
                readingOrderKey: Int64(day1.timeIntervalSince1970),
                orderSource: .eventTime
            ),
            NotebookEntry(
                id: "b",
                note: ReadingNote(id: "b", bookID: "b", bookTitle: "书", kind: .highlight, sourceText: "2", noteText: "", eventTime: day2),
                timelineDate: day2,
                readingOrderKey: Int64(day2.timeIntervalSince1970),
                orderSource: .eventTime
            )
        ]

        let groups = NotebookComposer.groupByDay(entries: entries)
        XCTAssertEqual(groups.count, 2)
        XCTAssertTrue(groups[0].day > groups[1].day)
        XCTAssertEqual(groups[0].entries.count, 1)
        XCTAssertEqual(groups[1].entries.count, 1)
    }

    func testParseNotesMapsTraceabilityFields() {
        let book = LibraryBook(
            id: "b1",
            title: "测试",
            author: "",
            cover: "",
            category: "",
            finished: false,
            secret: false,
            readUpdateTime: 0,
            isAlbum: false
        )
        let bookmarks: [String: Any] = [
            "updated": [[
                "bookmarkId": "bm1",
                "markText": "划线",
                "createTime": 1_720_000_000,
                "chapterTitle": "第一章",
                "range": 18
            ]]
        ]
        let reviews: [String: Any] = [
            "reviews": [[
                "review": [
                    "reviewId": "rv1",
                    "content": "想法",
                    "abstract": "摘要",
                    "createTime": 1_720_000_100,
                    "position": 25
                ]
            ]]
        ]

        let notes = WeReadNotesService.parseNotes(book: book, bookmarks: bookmarks, reviews: reviews)
        XCTAssertEqual(notes.count, 2)
        XCTAssertEqual(notes[0].chapterTitle, "第一章")
        XCTAssertEqual(notes[0].location, 18)
        XCTAssertNotNil(notes[0].eventTime)
        XCTAssertEqual(notes[0].sourceOrder, 0)
        XCTAssertEqual(notes[1].sourceOrder, 1)
    }
}
