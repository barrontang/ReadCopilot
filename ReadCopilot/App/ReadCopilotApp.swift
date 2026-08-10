import SwiftUI

@main
struct ReadCopilotApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 900, minHeight: 560)
                .preferredColorScheme(.light)   // 调色板为浅色设计,锁定浅色避免深色模式下白字白底
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        #endif
    }
}
