import Foundation

enum AnalysisScope: String, CaseIterable, Identifiable {
    case book = "单本"
    case category = "类别"
    case library = "全部"

    var id: String { rawValue }
}

enum AnalysisTemplate: String, CaseIterable, Identifiable {
    case coach = "阅读教练"
    case critical = "批判性阅读"
    case action = "行动转化"
    case synthesis = "跨书综合"
    case bookReview = "知乎书评"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .coach: return "诊断笔记模式并提供可执行的写作建议"
        case .critical: return "检查论证、假设、证据与可能的反例"
        case .action: return "把知识转化为行动、实验和复盘问题"
        case .synthesis: return "寻找主题、分歧和跨书连接"
        case .bookReview: return "生成可继续编辑和发布的 Markdown 长书评"
        }
    }

    var systemPrompt: String {
        let evidenceRule = "每个判断必须引用输入中的原文或读者笔记作为证据，不得虚构书中内容。"
        switch self {
        case .coach:
            return """
            你是一位深度阅读教练。\(evidenceRule)
            使用 Markdown，依次输出：## 思考模式诊断、## 三条写作建议、## 延伸追问、## 一句话总结。
            语气温暖、直接、具体，不使用评分表。
            """
        case .critical:
            return """
            你是一位批判性阅读教练。\(evidenceRule)
            使用 Markdown，依次输出：## 核心论点、## 隐含假设、## 证据与反例、## 认知盲区、## 下一步验证。
            明确区分作者观点、读者观点和你的推断。
            """
        case .action:
            return """
            你是一位行动学习教练。\(evidenceRule)
            使用 Markdown，依次输出：## 可迁移原则、## 行动清单、## 七日实验、## 复盘问题。
            行动必须小而具体，并说明它来自哪条笔记。
            """
        case .synthesis:
            return """
            你是一位知识综合研究员。\(evidenceRule)
            使用 Markdown，依次输出：## 反复出现的主题、## 观点共识与冲突、## 跨书连接、## 待补知识、## 写作选题。
            明确标注每条结论来自哪本书。
            """
        case .bookReview:
            return """
            你是一位中文书评编辑。\(evidenceRule)
            生成一篇可供知乎继续编辑的 Markdown 书评，包括标题、导语、核心观点、结合读者笔记的分析、
            保留意见、适合读者和结语。不要冒充读者经历，不要捏造引文，不输出发布平台营销话术。
            """
        }
    }
}

struct ReadingNote: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case highlight = "划线"
        case thought = "想法"
    }

    let id: String
    let bookID: String
    let bookTitle: String
    let kind: Kind
    let sourceText: String
    let noteText: String
}
