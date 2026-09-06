import Foundation

struct NotebookEntry: Identifiable, Hashable {
    let id: String
    let note: ReadingNote
    let timelineDate: Date
    let readingOrderKey: Int64
    let orderSource: OrderSource

    enum OrderSource: String, Hashable {
        case eventTime = "事件时间"
        case location = "阅读位置"
        case sourceOrder = "抓取顺序"
        case syncedAt = "同步时间"
    }

    var orderHint: String {
        if let chapter = note.chapterTitle.nilIfEmpty {
            return chapter
        }
        if let location = note.location {
            return "位置 \(location)"
        }
        return orderSource.rawValue
    }
}

enum NotebookSortMode: String, CaseIterable, Identifiable {
    case readingOrder = "阅读顺序"
    case byDay = "按天查看"
    var id: String { rawValue }
}

enum NotebookBookFilter: String, CaseIterable, Identifiable {
    case all = "全部图书"
    case single = "当前图书"
    var id: String { rawValue }
}

enum NotebookComposer {
    static func compose(notes: [ReadingNote]) -> [NotebookEntry] {
        notes.map { note in
            let timelineDate = note.eventTime ?? note.syncedAt
            if let eventTime = note.eventTime {
                return NotebookEntry(
                    id: note.id,
                    note: note,
                    timelineDate: eventTime,
                    readingOrderKey: prioritizedOrderKey(priority: 0, value: baseDateOrderKey(eventTime)),
                    orderSource: .eventTime
                )
            }
            if let location = note.location {
                return NotebookEntry(
                    id: note.id,
                    note: note,
                    timelineDate: timelineDate,
                    readingOrderKey: prioritizedOrderKey(priority: 1, value: Int64(location)),
                    orderSource: .location
                )
            }
            if let sourceOrder = note.sourceOrder {
                return NotebookEntry(
                    id: note.id,
                    note: note,
                    timelineDate: timelineDate,
                    readingOrderKey: prioritizedOrderKey(priority: 2, value: Int64(sourceOrder)),
                    orderSource: .sourceOrder
                )
            }
            return NotebookEntry(
                id: note.id,
                note: note,
                timelineDate: note.syncedAt,
                readingOrderKey: prioritizedOrderKey(priority: 3, value: baseDateOrderKey(note.syncedAt)),
                orderSource: .syncedAt
            )
        }
        .sorted { lhs, rhs in
            if lhs.readingOrderKey != rhs.readingOrderKey {
                return lhs.readingOrderKey < rhs.readingOrderKey
            }
            if lhs.timelineDate != rhs.timelineDate {
                return lhs.timelineDate < rhs.timelineDate
            }
            return lhs.id < rhs.id
        }
    }

    static func groupByDay(entries: [NotebookEntry]) -> [(day: String, entries: [NotebookEntry])] {
        let calendar = Calendar.current
        return Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.timelineDate)
        }
            .map { day, items in
                (
                    day: day.formatted(.dateTime.year().month().day()),
                    sortDay: day,
                    entries: items.sorted { $0.timelineDate < $1.timelineDate }
                )
            }
            .sorted { $0.sortDay > $1.sortDay }
            .map { (day: $0.day, entries: $0.entries) }
    }

    private static func baseDateOrderKey(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970 * 1000)
    }

    private static func prioritizedOrderKey(priority: Int64, value: Int64) -> Int64 {
        priority * 1_000_000_000_000_000 + max(value, 0)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
