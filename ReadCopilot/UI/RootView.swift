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
            // MARK: 侧边导航
            List(Nav.allCases, selection: $nav) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .font(Theme.body(14))
                    .tag(item)
            }
            .navigationTitle("ReadCopilot")
            .frame(minWidth: 180)
        } content: {
            // MARK: 中间列
            Group {
                switch nav {
                case .dashboard:
                    // 仪表盘全宽在 detail，中间列仅做占位
                    VStack {
                        Spacer()
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.hairline)
                        Text("仪表盘显示在右侧")
                            .font(Theme.body(12))
                            .foregroundStyle(Theme.inkSecondary)
                            .padding(.top, 8)
                        Spacer()
                    }
                case .settings:
                    VStack {
                        Spacer()
                        Image(systemName: "gearshape")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.hairline)
                        Text("设置项见右侧")
                            .font(Theme.body(12))
                            .foregroundStyle(Theme.inkSecondary)
                            .padding(.top, 8)
                        Spacer()
                    }
                default:
                    BookListColumn(store: store, selectedBook: $selectedBook)
                }
            }
            .frame(minWidth: 260)
            .background(Theme.bg)
        } detail: {
            // MARK: 详情/主内容列
            Group {
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
        }
        .background(Theme.bg)
        .tint(Theme.accent)
    }
}
