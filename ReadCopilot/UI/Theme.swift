import SwiftUI

// MARK: - 设计系统:暖中性色 + 书卷气 + 单一强调色(墨绿)
// 对标 Things3 / Reeder。中文排版为命门。

enum Theme {
    // 强调色:墨绿
    static let accent = Color(red: 0.11, green: 0.29, blue: 0.24)
    // 暖中性底色
    static let bg = Color(red: 0.97, green: 0.96, blue: 0.94)
    static let panel = Color(red: 0.99, green: 0.98, blue: 0.96)
    static let ink = Color(red: 0.12, green: 0.12, blue: 0.10)
    static let inkSecondary = Color(red: 0.34, green: 0.33, blue: 0.30)
    static let hairline = Color(red: 0.76, green: 0.74, blue: 0.70)
    static let success = Color(red: 0.10, green: 0.45, blue: 0.23)
    static let info = Color(red: 0.10, green: 0.36, blue: 0.72)

    // 中文排版
    static func serifTitle(_ size: CGFloat) -> Font {
        .system(serifTextStyle(for: size), design: .serif).weight(.semibold)
    }
    static func body(_ size: CGFloat) -> Font {
        .system(bodyTextStyle(for: size), design: .default).weight(.regular)
    }

    private static func serifTextStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case 22...: return .title
        case 20..<22: return .title2
        case 18..<20: return .title3
        case 16..<18: return .headline
        default: return .body
        }
    }

    private static func bodyTextStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<10: return .caption2
        case 10..<12: return .caption
        case 12..<13: return .footnote
        case 13..<14: return .subheadline
        case 14..<16: return .body
        case 16..<18: return .callout
        default: return .headline
        }
    }
}
