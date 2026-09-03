import Foundation

enum NotebookMode: String, CaseIterable, Identifiable {
    case readingOrder = "阅读顺序"
    case calendar = "日历"

    var id: String { rawValue }
}

struct NotebookDayGroup: Identifiable, Hashable {
    let date: Date
    let entries: [ReadingNote]

    var id: Date { date }
}

struct NotebookDaySummary: Identifiable, Hashable {
    let date: Date
    let entries: [ReadingNote]

    var id: Date { date }
    var entryCount: Int { entries.count }
    var books: [String] { Array(Set(entries.map(\.bookTitle))).sorted() }
    var firstActivity: Date? { entries.compactMap(\.recordedAtOrSyncDate).min() }
    var lastActivity: Date? { entries.compactMap(\.recordedAtOrSyncDate).max() }
}

struct NotebookCalendarCell: Identifiable, Hashable {
    let date: Date
    let summary: NotebookDaySummary?
    let isCurrentMonth: Bool

    var id: Date { date }
}

enum NotebookComposer {
    static func readingOrder(_ notes: [ReadingNote]) -> [ReadingNote] {
        notes.sorted(by: ReadingNote.readingOrderAscending)
    }

    static func groupByDay(_ notes: [ReadingNote], calendar: Calendar = .current) -> [NotebookDayGroup] {
        let grouped = Dictionary(grouping: readingOrder(notes)) {
            calendar.startOfDay(for: $0.recordedAtOrSyncDate)
        }
        return grouped.keys.sorted().map { date in
            NotebookDayGroup(date: date, entries: grouped[date] ?? [])
        }
    }

    static func monthSummaries(
        for month: Date,
        notes: [ReadingNote],
        calendar: Calendar = .current
    ) -> [NotebookDaySummary] {
        let interval = calendar.dateInterval(of: .month, for: month)
        let inMonth = readingOrder(notes).filter { note in
            guard let interval else { return true }
            return interval.contains(note.recordedAtOrSyncDate)
        }
        return groupByDay(inMonth, calendar: calendar).map {
            NotebookDaySummary(date: $0.date, entries: $0.entries)
        }
    }

    static func calendarCells(
        for month: Date,
        notes: [ReadingNote],
        calendar: Calendar = .current
    ) -> [NotebookCalendarCell] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let lastMoment = calendar.date(byAdding: .day, value: -1, to: monthInterval.end),
              let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: lastMoment) else {
            return []
        }

        let summaryMap = Dictionary(uniqueKeysWithValues: monthSummaries(for: month, notes: notes, calendar: calendar).map {
            (calendar.startOfDay(for: $0.date), $0)
        })

        var cells: [NotebookCalendarCell] = []
        var cursor = firstWeek.start
        while cursor < lastWeek.end {
            let day = calendar.startOfDay(for: cursor)
            let isCurrentMonth = calendar.isDate(day, equalTo: month, toGranularity: .month)
            cells.append(NotebookCalendarCell(
                date: day,
                summary: summaryMap[day],
                isCurrentMonth: isCurrentMonth
            ))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return cells
    }
}

extension ReadingNote {
    var recordedAtOrSyncDate: Date {
        recordedAt ?? syncedAt
    }

    static func readingOrderAscending(_ lhs: ReadingNote, _ rhs: ReadingNote) -> Bool {
        let lhsTime = lhs.recordedAt?.timeIntervalSince1970
        let rhsTime = rhs.recordedAt?.timeIntervalSince1970
        if lhsTime != rhsTime {
            switch (lhsTime, rhsTime) {
            case let (l?, r?):
                return l < r
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                break
            }
        }

        if lhs.location != rhs.location {
            switch (lhs.location, rhs.location) {
            case let (l?, r?):
                return l < r
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                break
            }
        }

        if lhs.syncedAt != rhs.syncedAt {
            return lhs.syncedAt < rhs.syncedAt
        }

        if lhs.sequenceHint != rhs.sequenceHint {
            return lhs.sequenceHint < rhs.sequenceHint
        }

        return lhs.id < rhs.id
    }
}
