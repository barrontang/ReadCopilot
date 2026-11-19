import Foundation

// MARK: - 调试启动参数
//
// 仅在 Debug 构建中生效，用于生成商店截图与本地演示。
// Release 构建下 isDemo 恒为 false，不包含任何演示数据。

enum LaunchOptions {
    static let arguments = ProcessInfo.processInfo.arguments

    static var isDemo: Bool {
        #if DEBUG
        return arguments.contains("--demo")
        #else
        return false
        #endif
    }

    /// 启动时显示的页面：home / copilot / gallery / knowledge / settings
    static var demoScreen: String? {
        guard isDemo else { return nil }
        return value(for: "--demo-screen=")
    }

    /// 生成截图后退出：文件写入应用临时目录。
    static var demoScreenshotName: String? {
        guard isDemo else { return nil }
        return value(for: "--demo-shot=")
    }

    static var loadDemoReport: Bool {
        isDemo && arguments.contains("--demo-report")
    }

    private static func value(for prefix: String) -> String? {
        arguments
            .first { $0.hasPrefix(prefix) }?
            .replacingOccurrences(of: prefix, with: "")
    }
}
