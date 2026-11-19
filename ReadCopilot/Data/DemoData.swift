import Foundation
import SwiftData

#if os(macOS)
import AppKit
#endif

// MARK: - 演示数据（仅 Debug）
//
// 用途：
// 1. 生成 App Store 截图，避免使用任何真实阅读数据。
// 2. 本地验证空数据之外的主要界面状态。
//
// 通过 `--demo` 启动参数启用；Release 构建不包含本文件内容。

#if DEBUG

enum DemoData {

    // MARK: 书架

    static let books: [LibraryBook] = [
        book(1, "人类简史", "尤瓦尔·赫拉利", "历史", finished: true, hoursAgo: 3),
        book(2, "思考，快与慢", "丹尼尔·卡尼曼", "心理", finished: true, hoursAgo: 9),
        book(3, "置身事内", "兰小欢", "经济", finished: true, hoursAgo: 26),
        book(4, "深度工作", "卡尔·纽波特", "方法", finished: false, hoursAgo: 30),
        book(5, "万历十五年", "黄仁宇", "历史", finished: true, hoursAgo: 52),
        book(6, "被讨厌的勇气", "岸见一郎", "心理", finished: false, hoursAgo: 74),
        book(7, "百年孤独", "加西亚·马尔克斯", "文学", finished: true, hoursAgo: 96),
        book(8, "原则", "瑞·达利欧", "管理", finished: false, hoursAgo: 120),
        book(9, "心流", "米哈里·契克森米哈赖", "心理", finished: true, hoursAgo: 144),
        book(10, "学会提问", "尼尔·布朗", "方法", finished: true, hoursAgo: 168),
        book(11, "活着", "余华", "文学", finished: true, hoursAgo: 192),
        book(12, "反脆弱", "纳西姆·塔勒布", "思维", finished: false, hoursAgo: 216),
        book(13, "月亮与六便士", "毛姆", "文学", finished: true, hoursAgo: 240),
        book(14, "穷查理宝典", "彼得·考夫曼", "投资", finished: false, hoursAgo: 264),
        book(15, "阅读是一座随身携带的避难所", "毛姆", "文学", finished: false, hoursAgo: 288),
        album(16, "曾国藩家书", "曾国藩", hoursAgo: 312)
    ]

    static let profile: ReadingProfile = {
        var p = ReadingProfile()
        p.totalReadTime = 2_347_800       // 652 小时
        p.readDays = 486
        p.registTime = Int(Date(timeIntervalSince1970: 1_662_000_000).timeIntervalSince1970)
        p.preferCategoryWord = "文学与历史"
        p.preferTimeWord = "晚上 21:00–23:00"
        p.preferTime = [
            0, 0, 0,
            600, 1_200, 3_600, 2_400, 1_800, 1_500,
            2_100, 2_600, 3_200, 2_800, 1_900, 2_200,
            3_000, 4_200, 5_200, 6_100, 4_800, 3_600,
            2_400, 1_200, 400
        ]
        p.stats = [
            ReadStatItem(stat: "读过", counts: "78本"),
            ReadStatItem(stat: "读完", counts: "34本"),
            ReadStatItem(stat: "阅读", counts: "652小时"),
            ReadStatItem(stat: "笔记", counts: "1,286条")
        ]
        return p
    }()

    // MARK: 知识库

    static let knowledgeEntries: [KnowledgeEntry] = [
        entry("k1", 1, "人类简史", .highlight,
              "智人之所以能统治地球，是因为我们能够编织出共同相信的故事。",
              "「共同想象」不是谎言，而是让陌生人协作的基础。公司、货币、国家都是这种故事的产物。",
              ["虚构故事", "认知革命"], hoursAgo: 2),
        entry("k2", 1, "人类简史", .thought,
              "农业革命是史上最大的骗局。",
              "从个体幸福看，狩猎采集者可能吃得更好、工作更短。农业让食物总量增加，却让大多数人的生活质量下降。",
              ["农业革命", "进步叙事"], hoursAgo: 3),
        entry("k3", 2, "思考，快与慢", .highlight,
              "系统一擅长快速判断，但会把「容易想到」误当成「更可能发生」。",
              "这解释了为什么新闻频率会影响风险感知。",
              ["系统一"], hoursAgo: 8),
        entry("k4", 2, "思考，快与慢", .thought,
              "锚定效应在谈判中几乎无法完全消除，只能通过事先写下独立估值来削弱。",
              "",
              ["决策偏误"], hoursAgo: 9),
        entry("k5", 3, "置身事内", .highlight,
              "地方政府的行为，必须放回财政激励与土地制度中去理解。",
              "把地方官员简单归因为「短视」会错过制度约束。",
              ["地方财政", "土地财政"], hoursAgo: 25),
        entry("k6", 4, "深度工作", .thought,
              "深度工作的敌人不是忙碌，而是「随时可被打断」的默认状态。",
              "把深度时段写进日历，比依赖意志力更可靠。",
              ["专注"], hoursAgo: 29),
        entry("k7", 5, "万历十五年", .highlight,
              "当制度只能依靠道德维系时，个人的勤勉反而会放大系统的僵化。",
              "海瑞与申时行的困境，都是制度性困境。",
              ["制度困境"], hoursAgo: 50),
        entry("k8", 7, "百年孤独", .thought,
              "布恩迪亚家族的孤独不是缺少陪伴，而是无法把经验翻译成别人听得懂的语言。",
              "",
              ["孤独"], hoursAgo: 94),
        entry("k9", 9, "心流", .highlight,
              "心流出现在挑战与技能恰好匹配的狭窄区间。",
              "所以「难一点」比「更努力」更重要。",
              ["心流"], hoursAgo: 142),
        entry("k10", 11, "活着", .thought,
              "福贵没有战胜苦难，他只是把苦难一件件接住，然后继续活下去。",
              "活着本身不是答案，而是问题被承受之后剩下的东西。",
              ["苦难"], hoursAgo: 190)
    ]

    static let knowledgeContainer: ModelContainer = {
        let schema = Schema([
            PersistentBook.self,
            PersistentReadingNote.self,
            PersistentDiagnosisResult.self,
            PersistentReadingProfile.self,
            ReadStatSnapshot.self,
            KnowledgeItem.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        for item in knowledgeEntries {
            let note = ReadingNote(
                id: item.id,
                bookID: item.bookID,
                bookTitle: item.bookTitle,
                kind: item.kind,
                sourceText: item.sourceText,
                noteText: item.noteText
            )
            let knowledgeItem = KnowledgeItem(note: note, importedAt: item.importedAt)
            knowledgeItem.topics = item.topics
            context.insert(knowledgeItem)
        }
        try? context.save()
        return container
    }()

    // MARK: 演示报告

    static let report = """
    ## 一句话结论
    你在这本书里已经完成了从「摘录观点」到「连接现实」的第一步。当前笔记的主要缺口不是数量，而是把划线与自己的判断分开记录。

    ## 思考模式诊断
    - 划线集中在「认知革命」与「虚构故事」两章，说明你对解释框架的兴趣高于史实细节。
    - 想法多是对原文的转述，缺少「我是否同意」与「反例是什么」。
    - 3 条想法跨越了章节，但仍未出现把概念迁移到工作或生活的具体例子。

    ## 三条写作建议
    1. 每条划线只追问一个问题：作者凭什么这么说？把答案写成一句话，而不是一段话。
    2. 给每条想法补一个「反例」或「边界条件」，让观点可以被检验。
    3. 每周选一条笔记，写一个 200 字的现实应用场景，下周复盘结果。

    ## 一句话总结
    把「作者说了什么」改写成「我相信什么、为什么」，这本书才会真正进入你的知识结构。
    """

    // MARK: 构造辅助

    private static func book(
        _ index: Int,
        _ title: String,
        _ author: String,
        _ category: String,
        finished: Bool,
        hoursAgo: Int
    ) -> LibraryBook {
        LibraryBook(
            id: "demo-book-\(index)",
            title: title,
            author: author,
            cover: coverURL(index: index, title: title, author: author),
            category: category,
            finished: finished,
            secret: false,
            readUpdateTime: Int(Date().timeIntervalSince1970) - hoursAgo * 3_600,
            isAlbum: false
        )
    }

    private static func album(_ index: Int, _ title: String, _ author: String, hoursAgo: Int) -> LibraryBook {
        LibraryBook(
            id: "demo-book-\(index)",
            title: title,
            author: author,
            cover: coverURL(index: index, title: title, author: author),
            category: "有声书",
            finished: true,
            secret: false,
            readUpdateTime: Int(Date().timeIntervalSince1970) - hoursAgo * 3_600,
            isAlbum: true
        )
    }

    private static func entry(
        _ id: String,
        _ bookIndex: Int,
        _ title: String,
        _ kind: ReadingNote.Kind,
        _ source: String,
        _ note: String,
        _ topics: [String],
        hoursAgo: Int
    ) -> KnowledgeEntry {
        KnowledgeEntry(
            id: id,
            bookID: "demo-book-\(bookIndex)",
            bookTitle: title,
            kind: kind,
            sourceText: source,
            noteText: note,
            importedAt: Date().addingTimeInterval(-Double(hoursAgo) * 3_600),
            topics: topics
        )
    }

    // MARK: 本地生成封面（避免截图依赖网络）

    #if os(macOS)
    private static let coverPalette: [(NSColor, NSColor)] = [
        (NSColor(red: 0.16, green: 0.32, blue: 0.27, alpha: 1), NSColor(red: 0.08, green: 0.17, blue: 0.14, alpha: 1)),
        (NSColor(red: 0.55, green: 0.27, blue: 0.20, alpha: 1), NSColor(red: 0.31, green: 0.13, blue: 0.10, alpha: 1)),
        (NSColor(red: 0.18, green: 0.26, blue: 0.42, alpha: 1), NSColor(red: 0.10, green: 0.14, blue: 0.25, alpha: 1)),
        (NSColor(red: 0.62, green: 0.48, blue: 0.22, alpha: 1), NSColor(red: 0.35, green: 0.25, blue: 0.10, alpha: 1)),
        (NSColor(red: 0.38, green: 0.24, blue: 0.36, alpha: 1), NSColor(red: 0.20, green: 0.12, blue: 0.20, alpha: 1)),
        (NSColor(red: 0.20, green: 0.40, blue: 0.42, alpha: 1), NSColor(red: 0.10, green: 0.22, blue: 0.24, alpha: 1)),
        (NSColor(red: 0.52, green: 0.30, blue: 0.16, alpha: 1), NSColor(red: 0.29, green: 0.15, blue: 0.08, alpha: 1)),
        (NSColor(red: 0.30, green: 0.31, blue: 0.34, alpha: 1), NSColor(red: 0.16, green: 0.17, blue: 0.19, alpha: 1))
    ]

    private static func coverURL(index: Int, title: String, author: String) -> String {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("readcopilot-demo-covers", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("cover-\(index).png")
        if FileManager.default.fileExists(atPath: url.path) {
            return url.absoluteString
        }

        let size = NSSize(width: 360, height: 504)
        let colors = coverPalette[(index - 1) % coverPalette.count]
        let image = NSImage(size: size, flipped: false) { rect in
            NSGradient(starting: colors.0, ending: colors.1)?.draw(in: rect, angle: -90)

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineBreakMode = .byWordWrapping

            let titleFont = NSFont(name: "Songti SC", size: 36) ?? NSFont.systemFont(ofSize: 36, weight: .semibold)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: NSColor.white.withAlphaComponent(0.96),
                .paragraphStyle: paragraph
            ]
            let titleRect = NSRect(x: 30, y: 150, width: size.width - 60, height: 230)
            (title as NSString).draw(in: titleRect, withAttributes: titleAttributes)

            let authorParagraph = NSMutableParagraphStyle()
            authorParagraph.alignment = .center
            let authorAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 17, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.72),
                .paragraphStyle: authorParagraph
            ]
            let authorRect = NSRect(x: 30, y: 96, width: size.width - 60, height: 40)
            (author as NSString).draw(in: authorRect, withAttributes: authorAttributes)

            NSColor.white.withAlphaComponent(0.18).setStroke()
            let border = NSBezierPath(rect: rect.insetBy(dx: 14, dy: 14))
            border.lineWidth = 1
            border.stroke()
            return true
        }

        guard let tiff = image.tiffRepresentation,
              let representation = NSBitmapImageRep(data: tiff),
              let png = representation.representation(using: .png, properties: [:]) else {
            return ""
        }
        try? png.write(to: url)
        return url.absoluteString
    }
    #else
    private static func coverURL(index: Int, title: String, author: String) -> String { "" }
    #endif
}

#endif
