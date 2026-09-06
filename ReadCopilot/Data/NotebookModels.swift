import Foundation

struct NotebookEntry: Identifiable, Hashable {
    let id: String
    let note: ReadingNote
    let orderDate: Date
    let orderSource: OrderSource

    enum OrderSource: String, Hashable {
        case eventTime = "事件时间"
        case location = "阅读位置"
        case sourceOrder = "抓取顺序"
        case syncedAt = "同步时间"
    }

    var dayKey: String {
        DateFormatter.notebookDay.string(from: orderDate)
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
                return NotebookEntry(id: note.id, note: note, orderDate: eventTime, orderSource: .eventTime)
            }
            if let location = note.location {
                let pseudo = Date(timeIntervalSince1970: TimeInterval(max(location, 0)))
                return NotebookEntry(id: note.id, note: note, orderDate: pseudo, orderSource: .location)
            }
            if let sourceOrder = note.sourceOrder {
                let pseudo = Date(timeIntervalSince1970: TimeInterval(max(sourceOrder, 0)))
                return NotebookEntry(id: note.id, note: note, orderDate: pseudo, orderSource: .sourceOrder)
            }
            return NotebookEntry(id: note.id, note: note, orderDate: note.syncedAt, orderSource: .syncedAt)
        }
        .sorted { lhs, rhs in
            if lhs.orderDate != rhs.orderDate {
                return lhs.orderDate < rhs.orderDate
            }
            return lhs.id < rhs.id
        }
    }

    static func groupByDay(entries: [NotebookEntry]) -> [(day: String, entries: [NotebookEntry])] {
        Dictionary(grouping: entries, by: \.dayKey)
            .map { ($0.key, $0.value.sorted { $0.orderDate < $1.orderDate }) }
            .sorted { $0.day > $1.day }
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
