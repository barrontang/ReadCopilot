import Foundation

struct NotebookEntry: Identifiable, Hashable {
    let id: String
    let note: ReadingNote
    let timelineDate: Date
    let orderValue: Int64
    let orderSource: OrderSource

    enum OrderSource: String, Hashable {
        case eventTime = "事件时间"
        case location = "阅读位置"
        case sourceOrder = "抓取顺序"
        case syncedAt = "同步时间"
    }

    var dayKey: String {
        DateFormatter.notebookDay.string(from: timelineDate)
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
            if let eventTime = note.eventTime {
                return NotebookEntry(
                    id: note.id,
                    note: note,
                    timelineDate: eventTime,
                    orderValue: Int64(eventTime.timeIntervalSince1970 * 1000),
                    orderSource: .eventTime
                )
            }
            if let location = note.location {
                return NotebookEntry(
                    id: note.id,
                    note: note,
                    timelineDate: note.syncedAt,
                    orderValue: Int64(location),
                    orderSource: .location
                )
            }
            if let sourceOrder = note.sourceOrder {
                return NotebookEntry(
                    id: note.id,
                    note: note,
                    timelineDate: note.syncedAt,
                    orderValue: Int64(sourceOrder),
                    orderSource: .sourceOrder
                )
            }
            return NotebookEntry(
                id: note.id,
                note: note,
                timelineDate: note.syncedAt,
                orderValue: Int64(note.syncedAt.timeIntervalSince1970 * 1000),
                orderSource: .syncedAt
            )
        }
        .sorted { lhs, rhs in
            if lhs.timelineDate != rhs.timelineDate {
                return lhs.timelineDate < rhs.timelineDate
            }
            if lhs.orderSource != rhs.orderSource {
                return sourcePriority(lhs.orderSource) < sourcePriority(rhs.orderSource)
            }
            if lhs.orderValue != rhs.orderValue {
                return lhs.orderValue < rhs.orderValue
            }
            return lhs.id < rhs.id
        }
    }

    static func groupByDay(entries: [NotebookEntry]) -> [(day: String, entries: [NotebookEntry])] {
        Dictionary(grouping: entries, by: \.dayKey)
            .map { ($0.key, $0.value.sorted { $0.timelineDate < $1.timelineDate }) }
            .sorted { $0.day > $1.day }
    }

    private static func sourcePriority(_ source: NotebookEntry.OrderSource) -> Int {
        switch source {
        case .eventTime: return 0
        case .location: return 1
        case .sourceOrder: return 2
        case .syncedAt: return 3
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private extension DateFormatter {
    static let notebookDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
