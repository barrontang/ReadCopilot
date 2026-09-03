import Foundation
import SwiftData

// MARK: - SwiftData Container Configuration

/// Central manager for SwiftData persistence
struct PersistenceManager {
    static let shared = PersistenceManager()
    
    /// Create and configure the SwiftData model container (cached; a computed
    /// property here would rebuild the container on every access and break
    /// cross-context consistency)
    static let modelContainer: ModelContainer = {
        let schema = Schema([
            PersistentBook.self,
            PersistentReadingNote.self,
            PersistentDiagnosisResult.self,
            PersistentReadingProfile.self,
            ReadStatSnapshot.self,
            KnowledgeItem.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none  // Privacy-first: no cloud sync
        )
        
        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }()
    
    /// Create context for background operations
    private func backgroundContext() -> ModelContext {
        ModelContext(Self.modelContainer)
    }
    
    // MARK: - Book Persistence
    
    /// Save or update a book in persistent storage
    func save(book: LibraryBook) throws {
        let context = ModelContext(Self.modelContainer)
        let bookId = book.id
        
        // Check if already exists
        let fetchDescriptor = FetchDescriptor<PersistentBook>(
            predicate: #Predicate { $0.id == bookId }
        )
        let existing = try context.fetch(fetchDescriptor).first
        
        if let existing = existing {
            // Update existing
            existing.title = book.title
            existing.author = book.author
            existing.cover = book.cover
            existing.category = book.category
            existing.finished = book.finished
            existing.secret = book.secret
            existing.readUpdateTime = book.readUpdateTime
            existing.lastSyncedAt = Date()
        } else {
            // Insert new
            let persistentBook = PersistentBook(from: book)
            context.insert(persistentBook)
        }
        
        try context.save()
    }
    
    /// Save multiple books
    func saveBooks(_ books: [LibraryBook]) throws {
        let context = ModelContext(Self.modelContainer)
        
        for book in books {
            let bookId = book.id
            let fetchDescriptor = FetchDescriptor<PersistentBook>(
                predicate: #Predicate { $0.id == bookId }
            )
            if let existing = try context.fetch(fetchDescriptor).first {
                existing.title = book.title
                existing.author = book.author
                existing.cover = book.cover
                existing.category = book.category
                existing.finished = book.finished
                existing.secret = book.secret
                existing.readUpdateTime = book.readUpdateTime
                existing.lastSyncedAt = Date()
            } else {
                let persistentBook = PersistentBook(from: book)
                context.insert(persistentBook)
            }
        }
        
        try context.save()
    }
    
    /// Fetch all stored books
    func fetchBooks() throws -> [LibraryBook] {
        let context = ModelContext(Self.modelContainer)
        let descriptor = FetchDescriptor<PersistentBook>(
            sortBy: [SortDescriptor(\.readUpdateTime, order: .reverse)]
        )
        let persistentBooks = try context.fetch(descriptor)
        return persistentBooks.map { $0.toLibraryBook() }
    }
    
    /// Delete a book and its associated notes
    func deleteBook(id: String) throws {
        let context = ModelContext(Self.modelContainer)
        let descriptor = FetchDescriptor<PersistentBook>(
            predicate: #Predicate { $0.id == id }
        )
        if let book = try context.fetch(descriptor).first {
            context.delete(book)
            try context.save()
        }
    }
    
    // MARK: - Reading Notes Persistence
    
    /// Save or update reading notes for a book
    func saveNotes(_ notes: [ReadingNote], bookID: String) throws {
        let context = ModelContext(Self.modelContainer)
        
        // Fetch the book
        let bookDescriptor = FetchDescriptor<PersistentBook>(
            predicate: #Predicate { $0.id == bookID }
        )
        guard let book = try context.fetch(bookDescriptor).first else {
            throw NSError(domain: "PersistenceError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Book not found"])
        }
        
        // Clear existing notes for this book
        let existingNotes = try context.fetch(FetchDescriptor<PersistentReadingNote>(
            predicate: #Predicate { $0.bookID == bookID }
        ))
        for note in existingNotes {
            context.delete(note)
        }
        book.notes.removeAll()
        
        // Add new notes
        for note in notes {
            let persistentNote = PersistentReadingNote(from: note, book: book)
            context.insert(persistentNote)
            book.notes.append(persistentNote)
        }
        
        try context.save()
    }
    
    /// Fetch notes for a specific book
    func fetchNotes(bookID: String) throws -> [ReadingNote] {
        let context = ModelContext(Self.modelContainer)
        let descriptor = FetchDescriptor<PersistentReadingNote>(
            predicate: #Predicate { $0.bookID == bookID },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let persistentNotes = try context.fetch(descriptor)
        return persistentNotes.map { $0.toReadingNote() }
    }

    /// Fetch all stored reading notes across books
    func fetchAllNotes() throws -> [ReadingNote] {
        let context = ModelContext(Self.modelContainer)
        let descriptor = FetchDescriptor<PersistentReadingNote>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try context.fetch(descriptor).map { $0.toReadingNote() }
    }
    
    // MARK: - Diagnosis Results Persistence
    
    /// Save a diagnosis result
    func saveDiagnosisResult(
        bookID: String,
        bookTitle: String,
        template: String,
        report: String,
        notesCount: Int
    ) throws {
        let context = ModelContext(Self.modelContainer)
        let result = PersistentDiagnosisResult(
            bookID: bookID,
            bookTitle: bookTitle,
            template: template,
            report: report,
            notesCount: notesCount
        )
        
        // Link to book if it exists
        let bookDescriptor = FetchDescriptor<PersistentBook>(
            predicate: #Predicate { $0.id == bookID }
        )
        if let book = try context.fetch(bookDescriptor).first {
            result.book = book
            book.diagnosisResult = result
        }
        
        context.insert(result)
        try context.save()
    }
    
    /// Fetch diagnosis result for a book
    func fetchDiagnosisResult(bookID: String) throws -> PersistentDiagnosisResult? {
        let context = ModelContext(Self.modelContainer)
        let descriptor = FetchDescriptor<PersistentDiagnosisResult>(
            predicate: #Predicate { $0.bookID == bookID }
        )
        return try context.fetch(descriptor).first
    }
    
    // MARK: - Reading Profile Persistence
    
    /// Save or update reading profile
    func saveProfile(_ profile: ReadingProfile) throws {
        let context = ModelContext(Self.modelContainer)
        let profileId = "singleton"
        
        let descriptor = FetchDescriptor<PersistentReadingProfile>(
            predicate: #Predicate { $0.id == profileId }
        )
        let existing = try context.fetch(descriptor).first
        
        let persistentProfile = existing ?? PersistentReadingProfile()
        persistentProfile.totalReadTime = profile.totalReadTime
        persistentProfile.readDays = profile.readDays
        persistentProfile.registTime = profile.registTime
        persistentProfile.preferCategoryWord = profile.preferCategoryWord
        persistentProfile.preferTimeWord = profile.preferTimeWord
        persistentProfile.preferTime = profile.preferTime
        persistentProfile.lastSyncedAt = Date()
        
        // Update stats
        persistentProfile.readStats = profile.stats.map { stat in
            ReadStatSnapshot(stat: stat.stat, counts: stat.counts)
        }
        
        if existing == nil {
            context.insert(persistentProfile)
        }
        
        try context.save()
    }
    
    /// Fetch reading profile
    func fetchProfile() throws -> ReadingProfile? {
        let context = ModelContext(Self.modelContainer)
        let descriptor = FetchDescriptor<PersistentReadingProfile>(
            predicate: #Predicate { $0.id == "singleton" }
        )
        guard let persistent = try context.fetch(descriptor).first else { return nil }
        
        var profile = ReadingProfile()
        profile.totalReadTime = persistent.totalReadTime
        profile.readDays = persistent.readDays
        profile.registTime = persistent.registTime
        profile.preferCategoryWord = persistent.preferCategoryWord
        profile.preferTimeWord = persistent.preferTimeWord
        profile.preferTime = persistent.preferTime
        profile.stats = persistent.readStats.map { stat in
            ReadStatItem(stat: stat.stat, counts: stat.counts)
        }
        return profile
    }
    
    // MARK: - Cleanup
    
    /// Delete all persisted data (privacy: one-click data deletion)
    func deleteAllData() throws {
        let context = ModelContext(Self.modelContainer)
        
        try context.delete(model: PersistentBook.self)
        try context.delete(model: PersistentReadingNote.self)
        try context.delete(model: PersistentDiagnosisResult.self)
        try context.delete(model: PersistentReadingProfile.self)
        try context.delete(model: ReadStatSnapshot.self)
        
        try context.save()
    }
}
