import SwiftUI

// MARK: - 设计系统:暖中性色 + 书卷气 + 单一强调色(墨绿)
// 对标 Things3 / Reeder。中文排版为命门。

enum Theme {
    // 强调色:墨绿
    static let accent = Color(red: 0.18, green: 0.36, blue: 0.30)
    // 暖中性底色
    static let bg = Color(red: 0.97, green: 0.96, blue: 0.94)
    static let panel = Color(red: 0.99, green: 0.98, blue: 0.96)
    static let ink = Color(red: 0.16, green: 0.15, blue: 0.13)
    static let inkSecondary = Color(red: 0.45, green: 0.43, blue: 0.40)
    static let hairline = Color(red: 0.87, green: 0.85, blue: 0.82)

    // 中文排版
    static func serifTitle(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }
    static func body(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
}
