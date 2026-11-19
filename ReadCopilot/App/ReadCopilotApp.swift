import SwiftUI
import UserNotifications

#if os(macOS)
import AppKit
#endif

@main
struct ReadCopilotApp: App {

    init() {
        // 启动时申请本地通知权限（诊断后台完成通知用）
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        #if DEBUG && os(macOS)
        DemoCapture.scheduleIfNeeded()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                #if os(macOS)
                .frame(minWidth: 900, minHeight: 560)
                .background(WindowConfigurator())
                #endif
                .preferredColorScheme(.light)
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        #endif
    }
}

#if os(macOS)
// 商店截图时固定窗口内容尺寸，确保输出 1440×900 pt（Retina 下 2880×1800 px）。
private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        guard LaunchOptions.isDemo else { return view }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard let window = view.window else { return }
            window.setContentSize(NSSize(width: 1440, height: 900))
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif

#if DEBUG && os(macOS)
// 从应用内部截取自身窗口，避免依赖“屏幕录制”系统权限。
enum DemoCapture {
    static func scheduleIfNeeded() {
        guard let name = LaunchOptions.demoScreenshotName else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            capture(named: name)
        }
    }

    private static func capture(named name: String) {
        defer { NSApp.terminate(nil) }
        guard let window = NSApp.windows.first(where: {
            $0.isVisible && ($0.contentView?.bounds.width ?? 0) > 500
        }), let view = window.contentView else { return }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        view.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        let bounds = view.bounds
        let scale = window.backingScaleFactor
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(bounds.width * scale),
            pixelsHigh: Int(bounds.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return }

        representation.size = bounds.size
        view.cacheDisplay(in: bounds, to: representation)

        guard let data = representation.representation(using: .png, properties: [:]) else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("readcopilot-\(name).png")
        try? data.write(to: url)
        print("DEMO_SHOT_PATH=\(url.path)")
    }
}
#endif
