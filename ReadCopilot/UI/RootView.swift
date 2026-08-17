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

// MARK: - 排序规则
enum BookSortOrder: String, CaseIterable, Identifiable {
    case recentRead  = "最近阅读"
    case titleAZ     = "书名 A-Z"
    case authorAZ    = "作者 A-Z"
    case finishedFirst = "读完优先"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .recentRead:    return "clock"
        case .titleAZ:       return "character"
        case .authorAZ:      return "person"
        case .finishedFirst: return "checkmark.seal"
        }
    }
}

// MARK: - 列表栏:真实书库
struct BookListColumn: View {
    @ObservedObject var store: LibraryStore
    @Binding var selectedBook: LibraryBook?
    @State private var query = ""
    @State private var sortOrder: BookSortOrder = .recentRead
    @State private var showFinishedOnly = false

    var filtered: [LibraryBook] {
        var list = store.books
        // 筛选
        if showFinishedOnly { list = list.filter { $0.finished } }
        if !query.isEmpty   { list = list.filter { $0.title.contains(query) || $0.author.contains(query) } }
        // 排序
        switch sortOrder {
        case .recentRead:
            list.sort { $0.readUpdateTime > $1.readUpdateTime }
        case .titleAZ:
            list.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .authorAZ:
            list.sort { $0.author.localizedCompare($1.author) == .orderedAscending }
        case .finishedFirst:
            list.sort {
                if $0.finished != $1.finished { return $0.finished }
                return $0.readUpdateTime > $1.readUpdateTime
            }
        }
        return list
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
                // footer:显示当前条目数,方便核对全量
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        Text(footerText)
                            .font(.caption).foregroundStyle(Theme.inkSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .navigationTitle("书库")
        .toolbar {
            // 排序菜单
            ToolbarItem(placement: .automatic) {
                Menu {
                    Section("排序方式") {
                        ForEach(BookSortOrder.allCases) { order in
                            Button {
                                sortOrder = order
                            } label: {
                                Label(order.rawValue, systemImage: order.icon)
                                if sortOrder == order { Image(systemName: "checkmark") }
                            }
                        }
                    }
                    Divider()
                    Section("筛选") {
                        Toggle(isOn: $showFinishedOnly) {
                            Label("只看已读完", systemImage: "checkmark.seal")
                        }
                    }
                } label: {
                    Image(systemName: sortOrder == .recentRead && !showFinishedOnly
                          ? "line.3.horizontal.decrease.circle"
                          : "line.3.horizontal.decrease.circle.fill")
                }
            }
            // 刷新
            ToolbarItem(placement: .automatic) {
                Button { Task { await store.syncAll() } } label: {
                    Image(systemName: "arrow.clockwise")
                }.disabled(store.loading)
            }
        }
    }

    private var footerText: String {
        let total = store.totalShelfItems
        let showing = filtered.count
        if showFinishedOnly || !query.isEmpty {
            return "显示 \(showing) 本 · 书架共 \(total) 个条目"
        }
        return "书架共 \(total) 个条目(\(store.bookCount) 本电子书 + \(store.albumCount) 个有声书\(store.hasMPCollection ? " + 1 文章收藏" : ""))"
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

// MARK: - 详情栏:诊断报告(真实 LLM)
struct DiagnosisColumn: View {
    let book: LibraryBook
    @StateObject private var model = DiagnosisModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // 书名 / 作者
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title).font(Theme.serifTitle(26)).foregroundStyle(Theme.ink)
                    Text("\(book.author)\(book.category.isEmpty ? "" : " · \(book.category)")")
                        .font(Theme.body(13)).foregroundStyle(Theme.inkSecondary)
                }
                Divider().background(Theme.hairline)

                // 状态区
                switch model.state {
                case .idle:
                    Text("点击下方按钮,拉取你在这本书的划线与想法,由 AI 生成阅读诊断报告。")
                        .font(Theme.body(15)).foregroundStyle(Theme.inkSecondary).lineSpacing(6)

                case .fetchingNotes:
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("正在拉取划线与想法…").font(Theme.body(14)).foregroundStyle(Theme.inkSecondary)
                    }

                case .generating:
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("AI 正在生成诊断报告…").font(Theme.body(14)).foregroundStyle(Theme.inkSecondary)
                    }

                case .done:
                    // Markdown 报告(简单渲染:##标题 + 正文)
                    ReportView(markdown: model.report)

                case .failed(let msg):
                    VStack(alignment: .leading, spacing: 10) {
                        Label("诊断失败", systemImage: "exclamationmark.triangle")
                            .font(Theme.body(15)).foregroundStyle(.red)
                        Text(msg).font(Theme.body(13)).foregroundStyle(Theme.inkSecondary)
                    }
                }

                Spacer(minLength: 16)

                // 生成按钮(idle / done / failed 时可点)
                let canRun = model.state == .idle || model.state == .done
                    || { if case .failed = model.state { return true } else { return false } }()
                Button {
                    Task { await model.run(book: book) }
                } label: {
                    Label(model.state == .done ? "重新生成" : "生成诊断",
                          systemImage: "sparkles")
                        .font(Theme.body(14))
                }
                .buttonStyle(.borderedProminent).tint(Theme.accent)
                .disabled(!canRun)
            }
            .padding(28).frame(maxWidth: 680, alignment: .leading)
        }
        .background(Theme.panel)
        // 切换不同书时重置状态
        .id(book.id)
    }
}

// MARK: - 简单 Markdown 渲染(## 标题 + 正文段落)
struct ReportView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, para in
                if para.isHeading {
                    Text(para.text)
                        .font(Theme.serifTitle(18))
                        .foregroundStyle(Theme.accent)
                        .padding(.top, 6)
                } else {
                    Text(para.text)
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(7)
                }
            }
        }
    }

    struct Para { let text: String; let isHeading: Bool }

    var paragraphs: [Para] {
        markdown.components(separatedBy: "\n")
            .map { line -> Para in
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("## ") { return Para(text: String(t.dropFirst(3)), isHeading: true) }
                if t.hasPrefix("# ")  { return Para(text: String(t.dropFirst(2)), isHeading: true) }
                return Para(text: t, isHeading: false)
            }
            .filter { !$0.text.isEmpty }
    }
}
