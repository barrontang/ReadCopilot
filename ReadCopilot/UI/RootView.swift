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
        case .library:   return "books.vertical"
        case .diagnosis: return "sparkles"
        case .settings:  return "gearshape"
        }
    }
    // 仪表盘和设置不需要中间列
    var needsContentColumn: Bool {
        switch self {
        case .library, .diagnosis: return true
        default: return false
        }
    }
}

// MARK: - 根视图
struct RootView: View {
    @StateObject private var store = LibraryStore()
    @State private var nav: Nav = .dashboard
    @State private var selectedBook: LibraryBook?
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // MARK: 侧边导航栏
            List(Nav.allCases, selection: $nav) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .font(Theme.body(14))
                    .tag(item)
            }
            .navigationTitle("ReadCopilot")
            .frame(minWidth: 180)
        } content: {
            // MARK: 中间列：只有书库/诊断才出现
            BookListColumn(store: store, selectedBook: $selectedBook)
                .frame(minWidth: 260)
        } detail: {
            // MARK: 详情/主内容
            switch nav {
            case .dashboard:
                DashboardColumn(store: store)
            case .settings:
                SettingsView()
            default:
                if let book = selectedBook {
                    DiagnosisColumn(book: book)
                } else {
                    ContentUnavailableView("选择一本书", systemImage: "book")
                }
            }
        }
        .background(Theme.bg)
        .tint(Theme.accent)
        .onChange(of: nav) { _, newNav in
            withAnimation {
                columnVisibility = newNav.needsContentColumn ? .all : .detailOnly
            }
        }
    }
}
