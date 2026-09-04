import SwiftUI

enum Nav: String, CaseIterable, Identifiable {
    case home      = "阅读主页"
    case copilot   = "Copilot"
    case knowledge = "知识库"
    case settings  = "设置"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .home:      return "books.vertical.fill"
        case .copilot:   return "sparkles.rectangle.stack"
        case .knowledge: return "point.3.connected.trianglepath.dotted"
        case .settings:  return "gearshape"
        }
    }
}

// MARK: - 根视图
struct RootView: View {
    @StateObject private var store = LibraryStore()
    @StateObject private var knowledgeStore = KnowledgeStore()
    @State private var nav: Nav = .home
    @State private var selectedBookID = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn

    var body: some View {
        #if os(iOS)
        TabView(selection: $nav) {
            DashboardColumn(store: store) { book in
                selectedBookID = book.id
                nav = .copilot
            }
            .tabItem { Label(Nav.home.rawValue, systemImage: Nav.home.icon) }
            .tag(Nav.home)

            CopilotWorkspace(store: store, knowledgeStore: knowledgeStore, selectedBookID: $selectedBookID)
                .tabItem { Label(Nav.copilot.rawValue, systemImage: Nav.copilot.icon) }
                .tag(Nav.copilot)

            KnowledgeGraphView(books: store.books, knowledgeStore: knowledgeStore)
                .tabItem { Label(Nav.knowledge.rawValue, systemImage: Nav.knowledge.icon) }
                .tag(Nav.knowledge)

            SettingsView()
                .tabItem { Label(Nav.settings.rawValue, systemImage: Nav.settings.icon) }
                .tag(Nav.settings)
        }
        .tint(Theme.accent)
        #else
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(Nav.allCases) { item in
                Button {
                    nav = item
                } label: {
                    Label(item.rawValue, systemImage: item.icon)
                        .font(Theme.body(14))
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("ReadCopilot")
            .frame(minWidth: 180)
        } detail: {
            switch nav {
            case .home:
                DashboardColumn(store: store) { book in
                    selectedBookID = book.id
                    nav = .copilot
                }
            case .copilot:
                CopilotWorkspace(store: store, knowledgeStore: knowledgeStore, selectedBookID: $selectedBookID)
            case .knowledge:
                KnowledgeGraphView(books: store.books, knowledgeStore: knowledgeStore)
            case .settings:
                SettingsView()
            }
        }
        .background(Theme.bg)
        .tint(Theme.accent)
        #endif
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}
