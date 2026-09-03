import Foundation

@MainActor
final class NotebookStore: ObservableObject {
    @Published private(set) var notes: [ReadingNote] = []
    @Published var loading = false
    @Published var error: String?
    @Published var mode: NotebookMode = .readingOrder
    @Published var selectedBookID: String = ""
    @Published var selectedCategory: String = ""
    @Published var selectedDay: Date?
    @Published var visibleMonth: Date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()

    private let notesService: WeReadNotesService
    private let persistence: PersistenceManager

    init(
        notesService: WeReadNotesService = WeReadNotesService(),
        persistence: PersistenceManager = .shared
    ) {
        self.notesService = notesService
        self.persistence = persistence
        reload()
    }

    var filteredNotes: [ReadingNote] {
        return NotebookComposer.readingOrder(notes).filter { note in
            let matchesBook = selectedBookID.isEmpty || note.bookID == selectedBookID
            let matchesCategory = selectedCategory.isEmpty || note.bookCategory == selectedCategory
            let matchesDay: Bool
            if let selectedDay {
                matchesDay = Calendar.current.isDate(note.recordedAtOrSyncDate, inSameDayAs: selectedDay)
            } else {
                matchesDay = true
            }
            return matchesBook && matchesCategory && matchesDay
        }
    }

    var readingOrderGroups: [NotebookDayGroup] {
        NotebookComposer.groupByDay(filteredNotes)
    }

    var calendarSummaries: [NotebookDaySummary] {
        NotebookComposer.monthSummaries(for: visibleMonth, notes: scopedNotes)
    }

    var calendarCells: [NotebookCalendarCell] {
        NotebookComposer.calendarCells(for: visibleMonth, notes: scopedNotes)
    }

    func reload() {
        notes = (try? persistence.fetchAllNotes()) ?? []
        normalizeSelection()
    }

    func loadNotes(for book: LibraryBook) async {
        loading = true
        error = nil
        defer { loading = false }

        do {
            let fetched = try await notesService.fetchAllNotes(for: book)
            try persistence.saveNotes(fetched, bookID: book.id)
            selectedBookID = book.id
            if let firstDate = NotebookComposer.readingOrder(fetched).first?.recordedAtOrSyncDate {
                visibleMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: firstDate)) ?? visibleMonth
            }
            reload()
        } catch {
            let cachedCount = ((try? persistence.fetchNotes(bookID: book.id)) ?? []).count
            if cachedCount > 0 {
                error = "同步失败，已显示《\(book.title)》的本地缓存：\(error.localizedDescription)"
                selectedBookID = book.id
                reload()
            } else {
                self.error = "获取《\(book.title)》笔记失败：\(error.localizedDescription)"
            }
        }
    }

    func shiftMonth(by offset: Int) {
        visibleMonth = Calendar.current.date(byAdding: .month, value: offset, to: visibleMonth) ?? visibleMonth
        if let selectedDay, !Calendar.current.isDate(selectedDay, equalTo: visibleMonth, toGranularity: .month) {
            self.selectedDay = nil
        }
    }

    private var scopedNotes: [ReadingNote] {
        NotebookComposer.readingOrder(notes).filter { note in
            let matchesBook = selectedBookID.isEmpty || note.bookID == selectedBookID
            let matchesCategory = selectedCategory.isEmpty || note.bookCategory == selectedCategory
            return matchesBook && matchesCategory
        }
    }

    private func normalizeSelection() {
        if !selectedBookID.isEmpty, !notes.contains(where: { $0.bookID == selectedBookID }) {
            selectedBookID = ""
        }
        if !selectedCategory.isEmpty, !notes.contains(where: { $0.bookCategory == selectedCategory }) {
            selectedCategory = ""
        }
        if let selectedDay, !filteredNotes.contains(where: { Calendar.current.isDate($0.recordedAtOrSyncDate, inSameDayAs: selectedDay) }) {
            self.selectedDay = nil
        }
    }
}
