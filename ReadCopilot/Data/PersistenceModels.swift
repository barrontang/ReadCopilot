import Foundation
import SwiftData

// MARK: - SwiftData Persistence Models

/// Persistent storage model for a book in the library
@Model
final class PersistentBook {
    @Attribute(.unique) var id: String
    var title: String
    var author: String
    var cover: String
    var category: String
    var finished: Bool
    var secret: Bool
    var readUpdateTime: Int
    var isAlbum: Bool
    var lastSyncedAt: Date?
    
    /// Relationship: this book has many reading notes
    @Relationship(deleteRule: .cascade, inverse: \PersistentReadingNote.book)
    var notes: [PersistentReadingNote] = []
    
    /// Relationship: this book may have a diagnosis result
    @Relationship(deleteRule: .cascade, inverse: \PersistentDiagnosisResult.book)
    var diagnosisResult: PersistentDiagnosisResult?
    
    init(from libraryBook: LibraryBook) {
        self.id = libraryBook.id
        self.title = libraryBook.title
        self.author = libraryBook.author
        self.cover = libraryBook.cover
        self.category = libraryBook.category
        self.finished = libraryBook.finished
        self.secret = libraryBook.secret
        self.readUpdateTime = libraryBook.readUpdateTime
        self.isAlbum = libraryBook.isAlbum
        self.lastSyncedAt = Date()
    }
    
    /// Convert back to LibraryBook (in-memory model)
    func toLibraryBook() -> LibraryBook {
        LibraryBook(
            id: id,
            title: title,
            author: author,
            cover: cover,
            category: category,
            finished: finished,
            secret: secret,
            readUpdateTime: readUpdateTime,
            isAlbum: isAlbum
        )
    }
}

/// Persistent storage model for a reading note (highlight or thought)
@Model
final class PersistentReadingNote {
    @Attribute(.unique) var id: String
    var bookID: String
    var bookTitle: String
    var kind: String  // "highlight" or "thought"
    var sourceText: String
    var noteText: String
    var createdAt: Date
    
    /// Inverse relationship to PersistentBook
    var book: PersistentBook?
    
    init(from readingNote: ReadingNote, book: PersistentBook? = nil) {
        self.id = readingNote.id
        self.bookID = readingNote.bookID
        self.bookTitle = readingNote.bookTitle
        self.kind = readingNote.kind.rawValue
        self.sourceText = readingNote.sourceText
        self.noteText = readingNote.noteText
        self.createdAt = Date()
        self.book = book
    }
    
    /// Convert back to ReadingNote (in-memory model)
    func toReadingNote() -> ReadingNote {
        ReadingNote(
            id: id,
            bookID: bookID,
            bookTitle: bookTitle,
            kind: ReadingNote.Kind(rawValue: kind) ?? .highlight,
            sourceText: sourceText,
            noteText: noteText
        )
    }
}

/// Persistent storage model for a diagnosis result
@Model
final class PersistentDiagnosisResult {
    @Attribute(.unique) var id: String
    var book: PersistentBook?
    var bookID: String
    var bookTitle: String
    var template: String  // "coach", "critical", etc.
    var report: String
    var notesCount: Int
    var generatedAt: Date
    
    init(
        bookID: String,
        bookTitle: String,
        template: String,
        report: String,
        notesCount: Int
    ) {
        self.id = "\(bookID)-\(template)-\(Date().timeIntervalSince1970)"
        self.bookID = bookID
        self.bookTitle = bookTitle
        self.template = template
        self.report = report
        self.notesCount = notesCount
        self.generatedAt = Date()
    }
}

// MARK: - Reading Profile Persistence

/// Persistent reading profile and statistics
@Model
final class PersistentReadingProfile {
    @Attribute(.unique) var id: String = "singleton"
    var totalReadTime: Int = 0
    var readDays: Int = 0
    var registTime: Int = 0
    var preferCategoryWord: String = ""
    var preferTimeWord: String = ""
    var preferTime: [Int] = []
    var bookCount: Int = 0
    var albumCount: Int = 0
    var hasMPCollection: Bool = false
    var lastSyncedAt: Date?
    
    /// Nested stats array
    var readStats: [ReadStatSnapshot] = []
    
    init(
        id: String = "singleton",
        totalReadTime: Int = 0,
        readDays: Int = 0,
        registTime: Int = 0,
        preferCategoryWord: String = "",
        preferTimeWord: String = "",
        preferTime: [Int] = [],
        bookCount: Int = 0,
        albumCount: Int = 0,
        hasMPCollection: Bool = false,
        lastSyncedAt: Date? = nil,
        readStats: [ReadStatSnapshot] = []
    ) {
        self.id = id
        self.totalReadTime = totalReadTime
        self.readDays = readDays
        self.registTime = registTime
        self.preferCategoryWord = preferCategoryWord
        self.preferTimeWord = preferTimeWord
        self.preferTime = preferTime
        self.bookCount = bookCount
        self.albumCount = albumCount
        self.hasMPCollection = hasMPCollection
        self.lastSyncedAt = lastSyncedAt
        self.readStats = readStats
    }
}

/// Snapshot of read statistics at a point in time
@Model
final class ReadStatSnapshot {
    @Attribute(.unique) var id: String
    var stat: String  // "读过", "读完", "阅读", "笔记"
    var counts: String  // "12本"
    
    init(stat: String, counts: String) {
        self.id = "\(stat)-\(Date().timeIntervalSince1970)"
        self.stat = stat
        self.counts = counts
    }
}
