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
    @StateObject private var knowledgeStore: KnowledgeStore = {
        #if DEBUG
        if LaunchOptions.isDemo {
            return KnowledgeStore(container: DemoData.knowledgeContainer, migrateLegacy: false)
        }
        #endif
        return KnowledgeStore()
    }()
    // 生命周期与 App 绑定，确保切到其他 Tab/导航项时正在后台运行的分析任务不被销毁
    @StateObject private var diagnosisSessionStore = DiagnosisSessionStore()
    @State private var nav: Nav = {
        switch LaunchOptions.demoScreen {
        case "copilot": return .copilot
        case "gallery": return .copilot
        case "knowledge": return .knowledge
        case "settings": return .settings
        default: return .home
        }
    }()
    @State private var selectedBookID = LaunchOptions.isDemo ? "demo-book-1" : ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn

    var body: some View {
        Group {
        #if os(iOS)
        TabView(selection: $nav) {
            DashboardColumn(store: store) { book in
                selectedBookID = book.id
                nav = .copilot
            }
            .tabItem { Label(Nav.home.rawValue, systemImage: Nav.home.icon) }
            .tag(Nav.home)

            CopilotWorkspace(store: store, knowledgeStore: knowledgeStore, sessionStore: diagnosisSessionStore, selectedBookID: $selectedBookID)
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
            VStack(alignment: .leading, spacing: 4) {
                Text("ReadCopilot")
                    .font(Theme.serifTitle(18))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10)
                    .padding(.top, 22)
                    .padding(.bottom, 14)

                ForEach(Nav.allCases) { item in
                    Button {
                        nav = item
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.icon)
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 18)
                            Text(item.rawValue)
                                .font(Theme.body(14))
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(nav == item ? Theme.accent : Theme.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(nav == item ? Theme.accent.opacity(0.10) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .background(Theme.bg)
            .frame(minWidth: 180)
        } detail: {
            switch nav {
            case .home:
                DashboardColumn(store: store) { book in
                    selectedBookID = book.id
                    nav = .copilot
                }
            case .copilot:
                if LaunchOptions.demoScreen == "gallery" {
                    TemplateGalleryContent(current: .coach, onSelect: { _ in })
                } else {
                    CopilotWorkspace(store: store, knowledgeStore: knowledgeStore, sessionStore: diagnosisSessionStore, selectedBookID: $selectedBookID)
                }
            case .knowledge:
                KnowledgeGraphView(books: store.books, knowledgeStore: knowledgeStore)
            case .settings:
                SettingsView()
            }
        }
        .background(Theme.bg)
        .tint(Theme.accent)
        #endif
        }
        .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}
