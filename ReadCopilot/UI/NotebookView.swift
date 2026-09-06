import SwiftUI

@MainActor
final class NotebookViewModel: ObservableObject {
    @Published var mode: NotebookSortMode = .readingOrder
    @Published var selectedBookID: String = ""
    @Published var selectedCategory: String = ""
    @Published var useDateRange = false
    @Published var fromDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @Published var toDate = Date()
    @Published var loading = false
    @Published var message: String?
    @Published private(set) var allEntries: [NotebookEntry] = []

    func reload() {
        do {
            let notes = try PersistenceManager.shared.fetchAllNotes()
            allEntries = NotebookComposer.compose(notes: notes)
        } catch {
            message = "加载失败：\(error.localizedDescription)"
            allEntries = []
        }
    }

    func sync(book: LibraryBook) async {
        loading = true
        message = nil
        defer { loading = false }
        do {
            let notes = try await WeReadNotesService().fetchAllNotes(for: book)
            try PersistenceManager.shared.saveNotes(notes, bookID: book.id)
            reload()
            message = "已同步《\(book.title)》\(notes.count) 条记录"
        } catch {
            message = "同步失败：\(error.localizedDescription)"
        }
    }

    func filteredEntries(books: [LibraryBook]) -> [NotebookEntry] {
        let bookMap = Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0) })
        return allEntries.filter { entry in
            if !selectedBookID.isEmpty && entry.note.bookID != selectedBookID {
                return false
            }
            if !selectedCategory.isEmpty {
                let category = bookMap[entry.note.bookID]?.category ?? ""
                if category != selectedCategory { return false }
            }
            if useDateRange {
                let start = Calendar.current.startOfDay(for: fromDate)
                let end = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: toDate) ?? toDate
                if entry.timelineDate < start || entry.timelineDate > end { return false }
            }
            return true
        }
    }
}

struct NotebookView: View {
    let books: [LibraryBook]
    @Binding var selectedBookID: String
    let openCopilot: (String) -> Void
    @StateObject private var model = NotebookViewModel()

    private var categories: [String] {
        Array(Set(books.map(\.category).filter { !$0.isEmpty })).sorted()
    }

    private var displayEntries: [NotebookEntry] {
        model.filteredEntries(books: books)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Notebook")
                    .font(Theme.serifTitle(22))
                controls
                if let message = model.message {
                    Text(message)
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.inkSecondary)
                }
                if displayEntries.isEmpty {
                    ContentUnavailableView("暂无笔记记录", systemImage: "book.pages")
                } else if model.mode == .readingOrder {
                    NotebookReadingOrderList(entries: displayEntries, openCopilot: openCopilot)
                } else {
                    NotebookDayGroupedList(groups: NotebookComposer.groupByDay(entries: displayEntries), openCopilot: openCopilot)
                }
            }
            .padding(24)
        }
        .background(Theme.bg)
        .navigationTitle("Notebook")
        .task {
            model.reload()
            if model.selectedBookID.isEmpty, !selectedBookID.isEmpty {
                model.selectedBookID = selectedBookID
            }
        }
        .onChange(of: selectedBookID) { _, newValue in
            if !newValue.isEmpty {
                model.selectedBookID = newValue
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("模式", selection: $model.mode) {
                ForEach(NotebookSortMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            HStack {
                Picker("图书", selection: $model.selectedBookID) {
                    Text("全部图书").tag("")
                    ForEach(books.filter { !$0.isAlbum }) { book in
                        Text(book.title).tag(book.id)
                    }
                }
                Picker("类别", selection: $model.selectedCategory) {
                    Text("全部类别").tag("")
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }
            }
            HStack {
                Toggle("日期范围", isOn: $model.useDateRange)
                if model.useDateRange {
                    DatePicker("从", selection: $model.fromDate, displayedComponents: .date)
                    DatePicker("到", selection: $model.toDate, displayedComponents: .date)
                }
                Spacer()
                Button {
                    guard let selected = books.first(where: { $0.id == model.selectedBookID }) else { return }
                    Task { await model.sync(book: selected) }
                } label: {
                    if model.loading {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("同步当前图书笔记", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(model.selectedBookID.isEmpty || model.loading)
            }
            .font(Theme.body(12))
        }
        .padding(14)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct NotebookReadingOrderList: View {
    let entries: [NotebookEntry]
    let openCopilot: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(entries) { entry in
                NotebookEntryRow(entry: entry, openCopilot: openCopilot)
            }
        }
    }
}

private struct NotebookDayGroupedList: View {
    let groups: [(day: String, entries: [NotebookEntry])]
    let openCopilot: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(groups, id: \.day) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(group.day) · \(group.entries.count) 条")
                        .font(Theme.serifTitle(15))
                    ForEach(group.entries) { entry in
                        NotebookEntryRow(entry: entry, openCopilot: openCopilot)
                    }
                }
            }
        }
    }
}

private struct NotebookEntryRow: View {
    let entry: NotebookEntry
    let openCopilot: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.note.bookTitle)
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
                Text(entry.timelineDate.formatted(date: .abbreviated, time: .shortened))
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.inkSecondary)
            }
            Text(entry.note.sourceText)
                .font(Theme.body(13))
                .foregroundStyle(Theme.ink)
            Text(entry.note.noteText.isEmpty ? "笔记：（无）" : "笔记：\(entry.note.noteText)")
                .font(Theme.body(12))
                .foregroundStyle(Theme.inkSecondary)
            HStack {
                Text(entry.orderHint)
                    .font(Theme.body(10))
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
                Button("去 Copilot 分析") { openCopilot(entry.note.bookID) }
                    .font(Theme.body(11))
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(12)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.hairline, lineWidth: 1))
    }
}
