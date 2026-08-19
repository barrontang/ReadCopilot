import SwiftUI

// MARK: - 书库中间列:书单 + 搜索过滤

struct BookListColumn: View {
    @ObservedObject var store: LibraryStore
    @Binding var selectedBook: LibraryBook?
    @State private var query = ""
    @State private var filterFinished: FilterState = .all

    enum FilterState: String, CaseIterable {
        case all = "全部"
        case finished = "读完"
        case unfinished = "在读"
    }

    private var filtered: [LibraryBook] {
        store.books.filter { book in
            let matchQ = query.isEmpty
                || book.title.localizedCaseInsensitiveContains(query)
                || book.author.localizedCaseInsensitiveContains(query)
            let matchF: Bool
            switch filterFinished {
            case .all: matchF = true
            case .finished: matchF = book.finished
            case .unfinished: matchF = !book.finished
            }
            return matchQ && matchF
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.inkSecondary)
                    .font(.system(size: 13))
                TextField("搜索书名/作者", text: $query)
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.ink)
                    .textFieldStyle(.plain)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.hairline, lineWidth: 1))
            .padding(.horizontal, 12)
            .padding(.top, 12)

            // 过滤 Picker
            Picker("", selection: $filterFinished) {
                ForEach(FilterState.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // 数量提示
            HStack {
                Text("\(filtered.count) 本")
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)

            Divider().padding(.top, 4)

            // 书单
            if store.loading {
                Spacer()
                ProgressView("拉取书架中…")
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
            } else if filtered.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.hairline)
                    Text(store.books.isEmpty ? "书架为空，请先同步" : "无匹配结果")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
            } else {
                List(filtered, selection: $selectedBook) { book in
                    BookRow(book: book)
                        .tag(book)
                }
                .listStyle(.sidebar)
            }
        }
        .background(Theme.bg)
        .navigationTitle("书库")
    }
}

// MARK: - 书单行
struct BookRow: View {
    let book: LibraryBook

    var body: some View {
        HStack(spacing: 10) {
            // 封面小图
            AsyncImage(url: URL(string: book.cover)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.hairline)
                        .overlay(
                            Image(systemName: book.isAlbum ? "headphones" : "book.closed.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.inkSecondary)
                        )
                }
            }
            .frame(width: 40, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Text(book.author)
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if !book.category.isEmpty {
                        TagChip(book.category)
                    }
                    if book.finished {
                        TagChip("✓ 读完", color: .green)
                    }
                    if book.isAlbum {
                        TagChip("有声书", color: .blue)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct TagChip: View {
    let label: String
    let color: Color

    init(_ label: String, color: Color = .secondary) {
        self.label = label
        self.color = color
    }

    var body: some View {
        Text(label)
            .font(.system(size: 9))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
