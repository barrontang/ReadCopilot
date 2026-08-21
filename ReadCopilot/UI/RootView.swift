import SwiftUI

enum Nav: String, CaseIterable, Identifiable {
    case dashboard = "仪表盘"
    case library   = "书库"
    case settings  = "设置"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .dashboard: return "chart.bar.doc.horizontal"
        case .library:   return "books.vertical"
        case .settings:  return "gearshape"
        }
    }
    /// 是否需要中间书库列
    var needsContentColumn: Bool { self == .library }
}

// MARK: - 根视图
struct RootView: View {
    @StateObject private var store = LibraryStore()
    @State private var nav: Nav = .dashboard
    @State private var selectedBook: LibraryBook?
    // .doubleColumn = 侧边栏 + detail，隐藏中间列（.detailOnly 会把侧边栏也藏掉）
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(Nav.allCases, selection: $nav) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .font(Theme.body(14))
                    .tag(item)
            }
            .navigationTitle("ReadCopilot")
            .frame(minWidth: 180)
        } content: {
            // 中间列仅在书库导航下有意义
            BookListColumn(store: store, selectedBook: $selectedBook)
                .frame(minWidth: 260)
        } detail: {
            switch nav {
            case .dashboard:
                DashboardColumn(store: store)
            case .settings:
                SettingsView()
            case .library:
                if let book = selectedBook {
                    DiagnosisColumn(book: book)
                } else {
                    ContentUnavailableView("选择一本书开始诊断", systemImage: "book.and.wrench")
                }
            }
        }
        .background(Theme.bg)
        .tint(Theme.accent)
        .onChange(of: nav) { _, newNav in
            withAnimation {
                columnVisibility = newNav.needsContentColumn ? .all : .doubleColumn
            }
        }
    }
}
