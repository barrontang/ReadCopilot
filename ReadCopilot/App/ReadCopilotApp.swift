import SwiftUI
import UserNotifications

@main
struct ReadCopilotApp: App {

    init() {
        // 启动时申请本地通知权限（诊断后台完成通知用）
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 900, minHeight: 560)
                .preferredColorScheme(.light)
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        #endif
    }
}
