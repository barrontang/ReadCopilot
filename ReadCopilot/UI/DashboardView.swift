import SwiftUI
import Charts

// MARK: - Dashboard 仪表盘
// 数据来源: LibraryStore (已拉取 overall + 书架)
// 布局: 两列卡片网格 + 时段热力图 + 品类偏好 + 统计摘要

struct DashboardColumn: View {
    @ObservedObject var store: LibraryStore
    let openBook: (LibraryBook) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: 顶部标题行
                Group {
                    #if os(iOS)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("阅读主页")
                                .font(Theme.serifTitle(22))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            syncButton
                        }
                        Picker("统计周期", selection: Binding(
                            get: { store.period },
                            set: { newValue in Task { await store.syncAll(period: newValue) } }
                        )) {
                            ForEach(ReadingPeriod.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    #else
                    HStack {
                        Text("阅读主页")
                            .font(Theme.serifTitle(22))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Picker("统计周期", selection: Binding(
                            get: { store.period },
                            set: { newValue in Task { await store.syncAll(period: newValue) } }
                        )) {
                            ForEach(ReadingPeriod.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 260)
                        syncButton
                    }
                    #endif
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                if let err = store.error {
                    ErrorBanner(message: err)
                        .padding(.horizontal, 24)
                }

                if store.profile.totalReadTime == 0 && !store.loading && store.lastSyncedAt != nil {
                    EmptyDashboard()
                } else {
                    // MARK: 核心数据卡片行
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 140), spacing: 12),
                    ], spacing: 12) {
                        StatCard(
                            icon: "clock.fill",
                            iconColor: Theme.accent,
                            label: "累计阅读",
                            value: LibraryStore.fmtDuration(store.profile.totalReadTime)
                        )
                        StatCard(
                            icon: "calendar",
                            iconColor: .orange,
                            label: "阅读天数",
                            value: "\(store.profile.readDays) 天"
                        )
                        StatCard(
                            icon: "books.vertical.fill",
                            iconColor: Theme.info,
                            label: "书架总数",
                            value: "\(store.totalShelfItems) 本"
                        )
                        StatCard(
                            icon: "checkmark.seal.fill",
                            iconColor: Theme.success,
                            label: "读完",
                            value: "\(store.books.filter { $0.finished }.count) 本"
                        )
                        StatCard(
                            icon: "percent",
                            iconColor: Theme.accent,
                            label: "完读率",
                            value: completionRate
                        )
                        StatCard(
                            icon: "flame.fill",
                            iconColor: .orange,
                            label: "阅读历程",
                            value: store.readingStreak > 0 ? "\(store.readingStreak) 天" : "—"
                        )
                        StatCard(
                            icon: "chart.line.uptrend.xyaxis",
                            iconColor: .purple,
                            label: "日均阅读",
                            value: store.averageDailyReadTime > 0 ? LibraryStore.fmtDuration(store.averageDailyReadTime) : "—"
                        )
                    }
                    .padding(.horizontal, 24)

                    // MARK: 扩展统计 (readStat[])
                    if !store.profile.stats.isEmpty {
                        ReadStatRow(stats: store.profile.stats)
                            .padding(.horizontal, 24)
                    }

                    ReadingOverview(store: store)
                        .padding(.horizontal, 24)

                    // MARK: 偏好信息
                    if !store.profile.preferCategoryWord.isEmpty || !store.profile.preferTimeWord.isEmpty {
                        PreferenceRow(profile: store.profile)
                            .padding(.horizontal, 24)
                    }

                    // MARK: 时段热力图(24 桶,从 6 点起)
                    if !store.profile.preferTime.isEmpty {
                        TimeHeatmap(buckets: store.profile.preferTime)
                            .padding(.horizontal, 24)
                    }

                    // MARK: 品类分布(书架)
                    let categoryData = store.categoryDistribution
                    if !categoryData.isEmpty {
                        CategoryChart(data: categoryData)
                            .padding(.horizontal, 24)
                    }

                    if !store.recentBooks.isEmpty {
                        RecentBooksRow(books: store.recentBooks)
                            .padding(.horizontal, 24)
                    }

                    LibraryShelfSection(books: store.books, openBook: openBook)
                        .padding(.horizontal, 24)

                    // MARK: 底部同步时间
                    if let ts = store.lastSyncedAt {
                        Text("上次同步: \(ts.formatted(.dateTime.month().day().hour().minute()))")
                            .font(Theme.body(11))
                            .foregroundStyle(Theme.inkSecondary)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                    }

                }
            }
        }
        .background(Theme.bg)
        .navigationTitle("阅读主页")
        .task { if store.books.isEmpty && !store.loading { await store.syncAll() } }
    }

    private var completionRate: String {
        guard !store.readableBooks.isEmpty else { return "—" }
        return "\(Int((store.completionRate * 100).rounded()))%"
    }

    @ViewBuilder
    private var syncButton: some View {
        if store.loading {
            ProgressView().controlSize(.small)
        } else {
            Button {
                Task { await store.syncAll() }
            } label: {
                Label("同步", systemImage: "arrow.clockwise")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
    }
}

struct ReadingOverview: View {
    @ObservedObject var store: LibraryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("阅读概览")
                .font(Theme.serifTitle(18))
            HStack(spacing: 12) {
                overviewItem("在读", value: "\(store.readingBooks.count) 本", icon: "book")
                overviewItem("已读完", value: "\(store.finishedBooks.count) 本", icon: "checkmark.circle")
                overviewItem("有声书", value: "\(store.albumCount) 本", icon: "headphones")
                overviewItem("收藏文章", value: store.hasMPCollection ? "已同步" : "无", icon: "bookmark")
            }
            Divider()
            HStack {
                Text("统计周期：\(store.period.rawValue)")
                Spacer()
                Text(store.lastSyncedAt.map { "数据更新于 \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "尚未同步")
            }
            .font(Theme.body(11))
            .foregroundStyle(Theme.inkSecondary)
        }
        .padding(16)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
    }

    private func overviewItem(_ title: String, value: String, icon: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(value).font(Theme.body(14)).foregroundStyle(Theme.ink)
                Text(title).font(Theme.body(11)).foregroundStyle(Theme.inkSecondary)
            }
        } icon: {
            Image(systemName: icon).foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LibraryShelfSection: View {
        let books: [LibraryBook]
        let openBook: (LibraryBook) -> Void
        @State private var query = ""
        @State private var filter: BookListColumn.FilterState = .all

        private var filtered: [LibraryBook] {
            books.filter { book in
                let matchesQuery = query.isEmpty
                    || book.title.localizedCaseInsensitiveContains(query)
                    || book.author.localizedCaseInsensitiveContains(query)
                let matchesFilter: Bool
                switch filter {
                case .all: matchesFilter = true
                case .finished: matchesFilter = book.finished
                case .unfinished: matchesFilter = !book.finished
                }
                return matchesQuery && matchesFilter
            }
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("我的书库")
                        .font(Theme.serifTitle(18))
                    Spacer()
                    TextField("搜索书名或作者", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 240)
                    Picker("状态", selection: $filter) {
                        ForEach(BookListColumn.FilterState.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .frame(width: 180)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                    ForEach(filtered) { book in
                        Button { openBook(book) } label: {
                            BookRow(book: book)
                                .padding(10)
                                .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                                .background(Theme.panel)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

// MARK: - 核心数字卡片
struct StatCard: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.system(size: 14))
                Text(label)
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.inkSecondary)
            }
            Text(value)
                .font(Theme.serifTitle(18))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.hairline, lineWidth: 1)
        )
    }
}

// MARK: - 扩展统计条(readStat[]: 读过/读完/阅读/笔记)
struct ReadStatRow: View {
    let stats: [ReadStatItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("阅读统计摘要")
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSecondary)
            HStack(spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.element.id) { idx, item in
                    VStack(spacing: 4) {
                        Text(item.counts)
                            .font(Theme.serifTitle(16))
                            .foregroundStyle(Theme.ink)
                        Text(item.stat)
                            .font(Theme.body(11))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    if idx < stats.count - 1 {
                        Divider().frame(height: 30)
                    }
                }
            }
            .padding(14)
            .background(Theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
        }
    }
}

// MARK: - 偏好标签
struct PreferenceRow: View {
    let profile: ReadingProfile

    var body: some View {
        HStack(spacing: 12) {
            if !profile.preferCategoryWord.isEmpty {
                PrefChip(icon: "book.fill", label: "偏好品类", value: profile.preferCategoryWord)
            }
            if !profile.preferTimeWord.isEmpty {
                PrefChip(icon: "moon.fill", label: "偏好时段", value: profile.preferTimeWord)
            }
            Spacer()
        }
    }
}

struct PrefChip: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Theme.body(10))
                    .foregroundStyle(Theme.inkSecondary)
                Text(value)
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.ink)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
    }
}

// MARK: - 时段热力图
// preferTime[]: 24 桶,从 6 点起,单位秒。桶 i => 小时 (i+6)%24
struct TimeHeatmap: View {
    let buckets: [Int]      // 长度 24

    private var hours: [(hour: Int, sec: Int)] {
        buckets.enumerated().map { idx, sec in
            ((idx + 6) % 24, sec)
        }
    }

    private var maxSec: Int {
        buckets.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("每日阅读时段分布")
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSecondary)
            VStack(spacing: 6) {
                // 热力块
                HStack(spacing: 3) {
                    ForEach(hours, id: \.hour) { item in
                        VStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(heatColor(item.sec))
                                .frame(height: 36)
                            Text(item.hour % 6 == 0 ? "\(item.hour)" : "")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.inkSecondary)
                        }
                    }
                }
                // 图例
                HStack(spacing: 4) {
                    Text("少")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkSecondary)
                    ForEach([0.1, 0.3, 0.5, 0.7, 0.9], id: \.self) { v in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatColor(Int(Double(maxSec) * v)))
                            .frame(width: 14, height: 10)
                    }
                    Text("多")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            .padding(14)
            .background(Theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
        }
    }

    private func heatColor(_ sec: Int) -> Color {
        guard maxSec > 0 else { return Theme.hairline }
        let ratio = Double(sec) / Double(maxSec)
        if ratio < 0.001 { return Theme.hairline }
        // 从淡绿→墨绿
        return Color(
            red: 0.18 + (1 - ratio) * (0.97 - 0.18),
            green: 0.36 + (1 - ratio) * (0.96 - 0.36),
            blue: 0.30 + (1 - ratio) * (0.94 - 0.30)
        )
    }
}

// MARK: - 品类分布 (Charts)
struct CategoryItem: Identifiable {
    let id = UUID()
    let category: String
    let count: Int
}

struct CategoryChart: View {
    let data: [CategoryItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("书架品类分布")
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSecondary)
            Chart(data) { item in
                BarMark(
                    x: .value("数量", item.count),
                    y: .value("品类", item.category)
                )
                .foregroundStyle(Theme.accent.opacity(0.85))
                .cornerRadius(4)
                .annotation(position: .trailing) {
                    Text("\(item.count)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ink)
                }
            }
            .frame(height: CGFloat(data.count * 32 + 20))
            .padding(14)
            .background(Theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
        }
    }
}

// MARK: - 最近阅读横向滚动
struct RecentBooksRow: View {
    let books: [LibraryBook]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近阅读")
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(books) { book in
                        BookThumbCard(book: book)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct BookThumbCard: View {
    let book: LibraryBook

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 封面占位 (异步加载)
            AsyncImage(url: URL(string: book.cover)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.hairline)
                        .overlay(
                            Image(systemName: book.isAlbum ? "headphones" : "book.closed")
                                .foregroundStyle(Theme.inkSecondary)
                        )
                }
            }
            .frame(width: 72, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6).stroke(Theme.hairline, lineWidth: 0.5)
            )

            Text(book.title)
                .font(Theme.body(11))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .frame(width: 72, alignment: .leading)

            if book.finished {
                Label("读完", systemImage: "checkmark")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.success)
            }
        }
        .frame(width: 72)
    }
}

// MARK: - 空状态
struct EmptyDashboard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(Theme.hairline)
            Text("点击右上角「同步」拉取阅读数据")
                .font(Theme.body(15))
                .foregroundStyle(Theme.inkSecondary)
            Text("需先在「设置」页填入微信读书 API Key")
                .font(Theme.body(12))
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

// MARK: - 错误条
struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(Theme.body(12))
                .foregroundStyle(Theme.ink)
                .lineLimit(3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }
}

#Preview {
    DashboardColumn(store: LibraryStore(), openBook: { _ in })
        .frame(width: 700, height: 800)
}
