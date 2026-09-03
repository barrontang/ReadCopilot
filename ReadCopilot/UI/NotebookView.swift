import SwiftUI

struct NotebookWorkspace: View {
    @ObservedObject var libraryStore: LibraryStore
    @ObservedObject var knowledgeStore: KnowledgeStore
    @ObservedObject var notebookStore: NotebookStore
    @Binding var selectedBookID: String
    let openCopilot: (String) -> Void

    @State private var importMessage: String?

    private var availableBooks: [LibraryBook] {
        libraryStore.books.filter { !$0.isAlbum }
    }

    private var categories: [String] {
        Array(Set(availableBooks.map(\.category).filter { !$0.isEmpty })).sorted()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if let error = notebookStore.error {
                    ErrorBanner(message: error)
                }

                if let importMessage {
                    Text(importMessage)
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.inkSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
                }

                if notebookStore.filteredNotes.isEmpty {
                    emptyState
                } else if notebookStore.mode == .readingOrder {
                    NotebookReadingOrderView(
                        groups: notebookStore.readingOrderGroups,
                        importEntry: importEntry,
                        openCopilot: openEntryInCopilot
                    )
                } else {
                    NotebookCalendarView(
                        visibleMonth: notebookStore.visibleMonth,
                        selectedDay: notebookStore.selectedDay,
                        cells: notebookStore.calendarCells,
                        summaries: notebookStore.calendarSummaries,
                        shiftMonth: notebookStore.shiftMonth(by:),
                        selectDay: { notebookStore.selectedDay = $0 },
                        importEntry: importEntry,
                        openCopilot: openEntryInCopilot
                    )
                }
            }
            .padding(24)
        }
        .background(Theme.bg)
        .navigationTitle("Notebook")
        .onAppear {
            notebookStore.reload()
            if notebookStore.selectedBookID.isEmpty, !selectedBookID.isEmpty {
                notebookStore.selectedBookID = selectedBookID
            }
        }
        .onChange(of: selectedBookID) { _, newValue in
            if !newValue.isEmpty {
                notebookStore.selectedBookID = newValue
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("阅读笔记本")
                        .font(Theme.serifTitle(22))
                        .foregroundStyle(Theme.ink)
                    Text("按阅读顺序整理划线与想法，并支持按日回看。")
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                if notebookStore.loading {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task {
                            guard let book = currentBook else { return }
                            await notebookStore.loadNotes(for: book)
                        }
                    } label: {
                        Label("同步当前图书", systemImage: "arrow.clockwise")
                            .font(Theme.body(12))
                    }
                    .disabled(currentBook == nil)
                }
            }

            HStack(spacing: 12) {
                Picker("模式", selection: $notebookStore.mode) {
                    ForEach(NotebookMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)

                Picker("图书", selection: $notebookStore.selectedBookID) {
                    Text("全部已缓存图书").tag("")
                    ForEach(availableBooks) { book in
                        Text(book.title).tag(book.id)
                    }
                }
                .frame(maxWidth: 280)

                Picker("类别", selection: $notebookStore.selectedCategory) {
                    Text("全部类别").tag("")
                    ForEach(categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .frame(maxWidth: 220)

                if notebookStore.selectedDay != nil {
                    Button("清除日期筛选") {
                        notebookStore.selectedDay = nil
                    }
                    .font(Theme.body(12))
                }

                Spacer()

                Text("已缓存 \(Set(notebookStore.notes.map(\.bookID)).count) 本书 · \(notebookStore.notes.count) 条记录")
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .padding(18)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
    }

    private var currentBook: LibraryBook? {
        availableBooks.first { $0.id == notebookStore.selectedBookID }
            ?? availableBooks.first { $0.id == selectedBookID }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "暂无可展示的笔记",
            systemImage: "book.pages",
            description: Text("先在 Copilot 或 Notebook 中同步某本书的划线与想法，再按阅读顺序或日历视图回看。")
        )
        .frame(maxWidth: .infinity, minHeight: 320)
    }

    private func importEntry(_ note: ReadingNote) {
        let imported = knowledgeStore.importNotes([note])
        importMessage = imported == 0 ? "这条记录已在知识库中" : "已导入知识库 1 条记录"
    }

    private func openEntryInCopilot(_ note: ReadingNote) {
        selectedBookID = note.bookID
        notebookStore.selectedBookID = note.bookID
        openCopilot(note.bookID)
    }
}

private struct NotebookReadingOrderView: View {
    let groups: [NotebookDayGroup]
    let importEntry: (ReadingNote) -> Void
    let openCopilot: (ReadingNote) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 12) {
                    Text(group.date.formatted(.dateTime.year().month().day().weekday(.wide)))
                        .font(Theme.serifTitle(18))
                        .foregroundStyle(Theme.ink)

                    ForEach(group.entries) { entry in
                        NotebookEntryCard(entry: entry, importEntry: importEntry, openCopilot: openCopilot)
                    }
                }
            }
        }
    }
}

private struct NotebookCalendarView: View {
    let visibleMonth: Date
    let selectedDay: Date?
    let cells: [NotebookCalendarCell]
    let summaries: [NotebookDaySummary]
    let shiftMonth: (Int) -> Void
    let selectDay: (Date?) -> Void
    let importEntry: (ReadingNote) -> Void
    let openCopilot: (ReadingNote) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(visibleMonth.formatted(.dateTime.year().month()))
                    .font(Theme.serifTitle(18))
                Spacer()
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { weekday in
                    Text(weekday)
                        .font(Theme.body(10))
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(cells) { cell in
                    if let date = cell.date {
                        Button {
                            selectDay(date)
                        } label: {
                            VStack(spacing: 4) {
                                Text(date.formatted(.dateTime.day()))
                                    .font(Theme.body(12))
                                    .foregroundStyle(cell.isCurrentMonth ? Theme.ink : Theme.inkSecondary)
                                if let summary = cell.summary {
                                    Text("\(summary.entryCount)")
                                        .font(Theme.body(10))
                                        .foregroundStyle(Theme.accent)
                                } else {
                                    Text(" ")
                                        .font(Theme.body(10))
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(background(for: cell, date: date))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(border(for: cell, date: date), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
            .background(Theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))

            ForEach(summaries) { summary in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(summary.date.formatted(.dateTime.month().day().weekday(.wide)))
                                .font(Theme.body(13))
                            Text("\(summary.entryCount) 条记录 · \(summary.books.joined(separator: "、"))")
                                .font(Theme.body(11))
                                .foregroundStyle(Theme.inkSecondary)
                        }
                        Spacer()
                        if let first = summary.firstActivity, let last = summary.lastActivity {
                            Text("\(first.formatted(.dateTime.hour().minute())) - \(last.formatted(.dateTime.hour().minute()))")
                                .font(Theme.body(11))
                                .foregroundStyle(Theme.inkSecondary)
                        }
                    }

                    ForEach(summary.entries) { entry in
                        NotebookEntryCard(entry: entry, importEntry: importEntry, openCopilot: openCopilot)
                    }
                }
                .opacity(opacity(for: summary.date))
            }
        }
    }

    private func background(for cell: NotebookCalendarCell, date: Date) -> Color {
        if let selectedDay, Calendar.current.isDate(date, inSameDayAs: selectedDay) {
            return Theme.accent.opacity(0.14)
        }
        if cell.summary != nil {
            return Theme.accent.opacity(0.08)
        }
        return Theme.bg
    }

    private func border(for cell: NotebookCalendarCell, date: Date) -> Color {
        if let selectedDay, Calendar.current.isDate(date, inSameDayAs: selectedDay) {
            return Theme.accent
        }
        return cell.summary != nil ? Theme.accent.opacity(0.25) : Theme.hairline
    }

    private func opacity(for date: Date) -> Double {
        guard let selectedDay else { return 1 }
        return Calendar.current.isDate(date, inSameDayAs: selectedDay) ? 1 : 0.35
    }
}

private struct NotebookEntryCard: View {
    let entry: ReadingNote
    let importEntry: (ReadingNote) -> Void
    let openCopilot: (ReadingNote) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.bookTitle)
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.ink)
                    Text(metadataLine)
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                Label(entry.kind.rawValue, systemImage: entry.noteText.isEmpty ? "highlighter" : "text.bubble")
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("原文")
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.inkSecondary)
                Text(entry.sourceText)
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.ink)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("笔记")
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.inkSecondary)
                Text(entry.noteText.isEmpty ? "（无）" : entry.noteText)
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.ink)
            }

            HStack {
                Button("去 Copilot") {
                    openCopilot(entry)
                }
                .font(Theme.body(12))

                Button("导入知识库") {
                    importEntry(entry)
                }
                .font(Theme.body(12))

                Spacer()
            }
        }
        .padding(16)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
    }

    private var metadataLine: String {
        var parts: [String] = [entry.recordedAtOrSyncDate.formatted(.dateTime.hour().minute())]
        if !entry.chapterTitle.isEmpty {
            parts.append(entry.chapterTitle)
        }
        if let location = entry.location {
            parts.append("位置 \(location)")
        }
        if !entry.bookCategory.isEmpty {
            parts.append(entry.bookCategory)
        }
        return parts.joined(separator: " · ")
    }
}
