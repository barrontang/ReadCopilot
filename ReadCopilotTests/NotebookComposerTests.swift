import XCTest
@testable import ReadCopilot

final class NotebookComposerTests: XCTestCase {
    private func makeNote(
        id: String,
        recordedAt: Date? = nil,
        syncedAt: Date,
        location: Int? = nil,
        sequenceHint: Int = 0
    ) -> ReadingNote {
        ReadingNote(
            id: id,
            bookID: "book-1",
            bookTitle: "测试书",
            bookCategory: "方法论",
            kind: .highlight,
            sourceText: id,
            noteText: "",
            chapterTitle: "第一章",
            location: location,
            recordedAt: recordedAt,
            syncedAt: syncedAt,
            sequenceHint: sequenceHint
        )
    }

    func testReadingOrderPrefersRecordedAtThenLocationThenSyncTime() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let notes = [
            makeNote(id: "c", recordedAt: nil, syncedAt: base.addingTimeInterval(120), location: 30, sequenceHint: 2),
            makeNote(id: "b", recordedAt: base.addingTimeInterval(60), syncedAt: base.addingTimeInterval(90), location: 20, sequenceHint: 1),
            makeNote(id: "a", recordedAt: base, syncedAt: base.addingTimeInterval(180), location: 10, sequenceHint: 0)
        ]

        let sorted = NotebookComposer.readingOrder(notes)
        XCTAssertEqual(sorted.map(\.id), ["a", "b", "c"])
    }

    func testGroupByDayFallsBackToSyncDateWhenRecordedAtMissing() {
        let firstDay = Date(timeIntervalSince1970: 1_700_000_000)
        let secondDay = firstDay.addingTimeInterval(86_400)
        let notes = [
            makeNote(id: "first", syncedAt: firstDay),
            makeNote(id: "second", syncedAt: secondDay)
        ]

        let groups = NotebookComposer.groupByDay(notes, calendar: Calendar(identifier: .gregorian))
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.first?.entries.first?.id, "first")
        XCTAssertEqual(groups.last?.entries.first?.id, "second")
    }

    func testMonthSummariesAggregateBooksAndCounts() {
        let calendar = Calendar(identifier: .gregorian)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let notes = [
            ReadingNote(id: "1", bookID: "b1", bookTitle: "甲", bookCategory: "类", kind: .highlight, sourceText: "a", noteText: "", recordedAt: base, syncedAt: base),
            ReadingNote(id: "2", bookID: "b2", bookTitle: "乙", bookCategory: "类", kind: .thought, sourceText: "b", noteText: "想法", recordedAt: base.addingTimeInterval(600), syncedAt: base)
        ]

        let summaries = NotebookComposer.monthSummaries(for: base, notes: notes, calendar: calendar)
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries.first?.entryCount, 2)
        XCTAssertEqual(summaries.first?.books, ["乙", "甲"].sorted())
    }

    func testParseNotesCapturesMetadata() {
        let book = LibraryBook(
            id: "book1",
            title: "Test Book",
            author: "Author",
            cover: "",
            category: "心理学",
            finished: false,
            secret: false,
            readUpdateTime: 0,
            isAlbum: false
        )

        let bookmarksJSON: [String: Any] = [
            "updated": [[
                "bookmarkId": "bm1",
                "markText": "重要的句子",
                "chapterTitle": "第一章",
                "range": 42,
                "createTime": 1_700_000_000
            ]]
        ]
        let reviewsJSON: [String: Any] = [
            "reviews": [[
                "review": [
                    "reviewId": "rv1",
                    "content": "我的想法",
                    "abstract": "作者说...",
                    "chapterTitle": "第二章",
                    "position": 84,
                    "createTime": 1_700_000_360
                ]
            ]]
        ]

        let notes = WeReadNotesService.parseNotes(book: book, bookmarks: bookmarksJSON, reviews: reviewsJSON)
        XCTAssertEqual(notes.count, 2)
        XCTAssertEqual(notes.first?.bookCategory, "心理学")
        XCTAssertEqual(notes.first?.chapterTitle, "第一章")
        XCTAssertEqual(notes.first?.location, 42)
        XCTAssertNotNil(notes.first?.recordedAt)
        XCTAssertEqual(notes.last?.chapterTitle, "第二章")
        XCTAssertEqual(notes.last?.location, 84)
    }
}
