import SwiftUI

enum Nav: String, CaseIterable, Identifiable {
    case dashboard = "仪表盘"
    case library = "书库"
    case diagnosis = "诊断"
    case settings = "设置"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .dashboard: return "chart.bar.doc.horizontal"
        case .library: return "books.vertical"
        case .diagnosis: return "sparkles"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - 三栏根视图(真实数据)
struct RootView: View {
    @StateObject private var store = LibraryStore()
    @State private var nav: Nav = .dashboard
    @State private var selectedBook: LibraryBook?

    var body: some View {
        NavigationSplitView {
            List(Nav.allCases, selection: $nav) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .font(Theme.body(14)).tag(item)
            }
            .navigationTitle("ReadCopilot")
            .frame(minWidth: 180)
        } content: {
            Group {
                switch nav {
                case .settings:
                    Text("设置项见右侧").foregroundStyle(Theme.inkSecondary)
                default:
                    BookListColumn(store: store, selectedBook: $selectedBook)
                }
            }
            .frame(minWidth: 260)
        } detail: {
            Group {
                switch nav {
                case .dashboard: DashboardColumn(store: store)
                case .settings: SettingsView()
                default:
                    if let book = selectedBook {
                        DiagnosisColumn(book: book)
                    } else {
                        ContentUnavailableView("选择一本书", systemImage: "book")
                    }
                }
            }
        }
        .background(Theme.bg)
        .tint(Theme.accent)
        .task { await store.syncAll() }   // 启动即全量同步
    }
}

// MARK: - 列表栏:真实书库
struct BookListColumn: View {
    @ObservedObject var store: LibraryStore
    @Binding var selectedBook: LibraryBook?
    @State private var query = ""

    var filtered: [LibraryBook] {
        query.isEmpty ? store.books :
            store.books.filter { $0.title.contains(query) || $0.author.contains(query) }
    }

    var body: some View {
        Group {
            if store.loading && store.books.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在拉取全量书库…").font(Theme.body(13)).foregroundStyle(Theme.inkSecondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = store.error, store.books.isEmpty {
                ContentUnavailableView {
                    Label("书库未加载", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(err).foregroundStyle(Theme.inkSecondary)
                } actions: {
                    Button("重试") { Task { await store.syncAll() } }
                }
            } else {
                List(filtered, selection: $selectedBook) { book in
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                if book.isAlbum { Image(systemName: "headphones").font(.caption2).foregroundStyle(Theme.accent) }
                                Text(book.title).font(Theme.body(15)).foregroundStyle(Theme.ink)
                                if book.finished { Text("已读完").font(.caption2).foregroundStyle(Theme.accent) }
                            }
                            HStack(spacing: 6) {
                                Text(book.author)
                                if !book.category.isEmpty { Text("·"); Text(book.category) }
                            }
                            .font(Theme.body(12)).foregroundStyle(Theme.inkSecondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 3).tag(book)
                }
                .searchable(text: $query, prompt: "搜索书名或作者")
            }
        }
        .navigationTitle("书库")
        .toolbar {
            ToolbarItem {
                Button { Task { await store.syncAll() } } label: {
                    Image(systemName: "arrow.clockwise")
                }.disabled(store.loading)
            }
        }
    }
}

// MARK: - 仪表盘(真实画像)
struct DashboardColumn: View {
    @ObservedObject var store: LibraryStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("阅读教练").font(Theme.serifTitle(28)).foregroundStyle(Theme.ink)

                if store.loading && store.books.isEmpty {
                    HStack { ProgressView(); Text("同步中…").foregroundStyle(Theme.inkSecondary) }
                } else if let err = store.error, store.books.isEmpty {
                    Text(err).font(Theme.body(15)).foregroundStyle(.red)
                    Button("重试") { Task { await store.syncAll() } }.tint(Theme.accent)
                } else {
                    // 全量书库口径
                    Text("书架共 \(store.totalShelfItems) 个条目:\(store.bookCount) 本电子书 + \(store.albumCount) 个有声书\(store.hasMPCollection ? " + 1 个文章收藏" : "")")
                        .font(Theme.body(15)).foregroundStyle(Theme.ink)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent.opacity(0.08)))

                    // 阅读统计摘要(readStat,原样文案)
                    if !store.profile.stats.isEmpty {
                        HStack(spacing: 12) {
                            ForEach(store.profile.stats) { s in
                                statCard(s.counts, s.stat)
                            }
                        }
                    }

                    // 时长 / 天数 / 注册
                    HStack(spacing: 12) {
                        statCard(LibraryStore.fmtDuration(store.profile.totalReadTime), "累计时长")
                        statCard("\(store.profile.readDays)", "阅读天数")
                        statCard(LibraryStore.fmtDate(store.profile.registTime), "注册于")
                    }

                    if !store.profile.preferCategoryWord.isEmpty {
                        Text(store.profile.preferCategoryWord).font(Theme.body(14)).foregroundStyle(Theme.inkSecondary)
                    }
                    if !store.profile.preferTimeWord.isEmpty {
                        Text(store.profile.preferTimeWord).font(Theme.body(14)).foregroundStyle(Theme.inkSecondary)
                    }
                    if let t = store.lastSyncedAt {
                        Text("上次同步:\(t.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(Theme.inkSecondary)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .background(Theme.panel)
    }

    func statCard(_ n: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(n).font(Theme.serifTitle(22)).foregroundStyle(Theme.accent)
            Text(label).font(Theme.body(12)).foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bg))
    }
}

// MARK: - 详情栏:诊断报告(占位,M1 下一步接 LLM)
struct DiagnosisColumn: View {
    let book: LibraryBook

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title).font(Theme.serifTitle(26)).foregroundStyle(Theme.ink)
                    Text("\(book.author)\(book.category.isEmpty ? "" : " · \(book.category)")")
                        .font(Theme.body(13)).foregroundStyle(Theme.inkSecondary)
                }
                Divider().background(Theme.hairline)
                Text("笔记写作诊断将在此生成(需先配置 LLM Key)。\n下一步:拉取本书的划线与想法 → 结构化喂给 LLM → 输出思考模式判定 + 写作建议 + 延伸追问。")
                    .font(Theme.body(15)).foregroundStyle(Theme.ink).lineSpacing(6)
                Button {
                } label: { Label("生成诊断", systemImage: "sparkles").font(Theme.body(14)) }
                    .buttonStyle(.borderedProminent).tint(Theme.accent)
            }
            .padding(28).frame(maxWidth: 680, alignment: .leading)
        }
        .background(Theme.panel)
    }
}
