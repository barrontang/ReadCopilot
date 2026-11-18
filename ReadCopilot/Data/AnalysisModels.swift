import Foundation

enum AnalysisScope: String, CaseIterable, Identifiable {
    case book = "单本"
    case category = "类别"
    case library = "全部"

    var id: String { rawValue }
}

// MARK: - 报告模板
//
// 八个模板对应 reading-notes 技能的 A/B/E/F 工作流：
// 笔记体检、阅读教练、批判性阅读、行动转化、读后闭环、主题地图、读法处方、书评工坊。
// 所有模板共享同一套证据规则：稳定 ID、原文不改写、指标不重算、等级不承诺。

enum AnalysisTemplate: String, CaseIterable, Identifiable {
    case diagnosis = "笔记体检"
    case coach = "阅读教练"
    case critical = "批判性阅读"
    case action = "行动转化"
    case postReading = "读后闭环"
    case synthesis = "主题地图"
    case method = "读法处方"
    case bookReview = "书评工坊"

    var id: String { rawValue }

    enum Category: String, CaseIterable {
        case diagnosis = "诊断"
        case deepReading = "精读"
        case output = "输出"
        case method = "方法"
    }

    var category: Category {
        switch self {
        case .diagnosis: return .diagnosis
        case .coach, .critical, .synthesis: return .deepReading
        case .action, .postReading, .bookReview: return .output
        case .method: return .method
        }
    }

    var icon: String {
        switch self {
        case .diagnosis: return "stethoscope"
        case .coach: return "figure.mind.and.body"
        case .critical: return "magnifyingglass"
        case .action: return "checklist"
        case .postReading: return "arrow.triangle.2.circlepath"
        case .synthesis: return "map"
        case .method: return "compass.drawing"
        case .bookReview: return "text.quote"
        }
    }

    var tagline: String {
        switch self {
        case .diagnosis: return "七维诊断 + 本地等级，先给结论再给处方"
        case .coach: return "识别 2–3 个笔记习惯，给出三条可执行的改写建议"
        case .critical: return "拆论证、找假设、列反例，区分作者观点与推断"
        case .action: return "用 RIA 把划线和想法变成 A2 行动与七日实验"
        case .postReading: return "三句话概括、一条行动、费曼复述、复盘五问"
        case .synthesis: return "跨书对比、共同主题、共识冲突与写作选题"
        case .method: return "按阅读目的匹配 2–3 个方法，给明天第一步"
        case .bookReview: return "带证据引用的可编辑长书评"
        }
    }

    var description: String { tagline }

    var sections: [String] {
        switch self {
        case .diagnosis:
            return ["阅读概览", "主题地图", "思考签名", "核心洞见", "细节观察", "改进计划", "读法匹配与输出闭环"]
        case .coach:
            return ["思考模式诊断", "三条写作建议", "延伸追问", "一句话总结"]
        case .critical:
            return ["核心论点", "隐含假设", "证据与反例", "认知盲区", "下一步验证"]
        case .action:
            return ["可迁移原则", "RIA 拆解", "行动清单", "七日实验", "复盘问题"]
        case .postReading:
            return ["三句话概括", "一条可执行行动（A2）", "费曼复述", "与已有知识建立连接", "复盘五问", "证据附录"]
        case .synthesis:
            return ["跨书对比", "反复出现的主题", "共识与冲突", "跨书连接", "待补知识", "写作选题"]
        case .method:
            return ["目的与书型", "当前笔记信号", "推荐方法组合", "明天可执行的第一步", "输出承诺", "复盘五问"]
        case .bookReview:
            return ["标题", "导语", "核心观点", "结合笔记的分析", "保留意见", "适合读者", "结语"]
        }
    }

    /// 读法处方可以只依据书名、作者、类别与阅读目的；其余模板必须有笔记。
    var requiresNotes: Bool { self != .method }

    var estimatedMinutes: Int {
        switch self {
        case .diagnosis: return 4
        case .synthesis: return 3
        case .bookReview: return 3
        default: return 2
        }
    }

    var maxTokens: Int {
        switch self {
        case .diagnosis: return 4200
        case .synthesis, .bookReview: return 3200
        case .postReading, .action: return 3000
        default: return 2400
        }
    }

    // MARK: Prompt

    private var evidenceRule: String {
        """
        【证据规则】
        1. 只依据输入的划线、想法和本地指标作答；它们不是全书内容。不得补写书中情节、作者立场、读者经历或未出现的引文。
        2. 每条定性判断紧跟证据标记：划线用（U001），想法用（R001）；多本书时写（B2-R003）。引文保持原样，单条不超过 40 字。
        3. 本地指标（等级、比率、分档、章节密度）已经算好，照抄，不得重算、估算或编造；等级只能由七因子解释，不得承诺提分。
        4. 保留指标口径：depth mix 是字数分档（<15 / 15–39 / 40–119 / ≥120 字）；reflection / action / question 是关键词命中；两个中位数是非配对分布；章节密度只表示笔记覆盖，不代表读完或跳过。
        5. 评价对象是笔记本，不是读者或书：写「笔记未覆盖该章」，不写「你跳过了该章」；没有实践结果就写「待补录」，并说明补录所需的数据或动作。
        6. 方法名不是证据；处方要引用触发它的指标或笔记 ID，并给出明天可执行的第一步。
        7. 输出语言跟随用户；笔记原文不翻译。严格使用指定标题及顺序，不新增或改名一级标题。
        """
    }

    private var outputRule: String {
        """
        【输出规则】
        严格使用下列二级标题及顺序，不新增、不改名、不合并。每节用短段落、项目符号或表格；避免空泛赞美、重复输入和套话。所有数字与 ID 必须来自输入。
        """
    }

    var systemPrompt: String {
        switch self {
        case .diagnosis:
            return """
            你是一位笔记质量诊断师，熟悉「筛选—理解—内化—输出—应用」五阶段阅读闭环。
            \(evidenceRule)
            \(outputRule)
            先在第一个标题前写一行结论：等级 X（分数/100）——最需要改变的是……
            依次输出：
            ## 1. 阅读概览
            用紧凑表格列出：划线、想法、想法率、章节覆盖、日期跨度、想法中位长度、划线中位长度；最后写一句解释，不要复述整张表。
            ## 2. 主题地图
            3–5 个主题，每个主题给出原始笔记条数和 1 条代表 ID。说明「未做跨章去重，同一条笔记可能被多个主题计入」，不要把份额相加。
            ## 3. 思考签名
            3–4 个可观察的笔记习惯；每个习惯给 1–2 条 ID，并标注它落在五阶段的哪一阶段。最后单独一行：最薄的一环是 ___。
            ## 4. 核心洞见
            按本地指标的「候选证据」顺序取 5–8 条；每条写：判断 + 证据 ID + 为什么重要。不得另起排序。
            ## 5. 细节观察
            1–3 条具体观察（短反应、爆发阅读日、未覆盖章节），只描述笔记，不推断读者人格。
            ## 6. 改进计划
            输出 6 列表格：# | 触发信号（指标 / 笔记 ID） | 方法 | 明天可执行的第一步 | 会移动的指标 | 验收方式
            5–7 行；每行只写一个主方法（可在括号内附辅助方法）；整表共用一个 2–3 方法组合；验收方式必须可观察（日期、条数、字数上限、连接词数量）。表后写一行：按投入产出排序，先做第 # 与第 # 条。
            ## 7. 读法匹配与输出闭环
            先写阅读目的与书型（目的不明就写「需要先确认目的：考试/研究/写作/实用/消遣」），再写与第 6 维相同的方法组合，并引用命中的诊断→处方映射行。然后给出：
            - 三句话概括（每句挂 ID）；
            - 一条 A2 行动：从明天起，我会在〈具体时间点〉做〈具体对象〉，产出〈可验收的成果〉。；
            - 讲给外行听（只用笔记里已有的词、意象和类比；讲不下去的地方标「待回查」）；
            - 与已有知识建立连接（优先用跨书共同主题；没有就写清需要再导出什么）；
            - 复盘五问：我学到了什么？哪一点能用到工作/生活？下周具体怎么做？做完效果如何？哪些需要调整？第 4、5 问标「待补录」，并写回填动作与日期。
            最后一行固定为：不同书不同读法；以问题为中心，以输出和应用为终点。
            """
        case .coach:
            return """
            你是一位深度阅读教练。\(evidenceRule)
            \(outputRule)
            依次输出：## 思考模式诊断、## 三条写作建议、## 延伸追问、## 一句话总结。
            「思考模式诊断」识别 2–3 个可观察的笔记习惯，区分事实与推断，并标注各自落在筛选/理解/内化/输出/应用哪一阶段。
            「三条写作建议」必须恰好三条；每条包含一个具体改写或补写动作、适用笔记 ID 和完成标准。
            「延伸追问」给出 2–3 个可直接用于下一次阅读或写作的问题。
            「一句话总结」限一句，概括最值得优先改变的方向。
            语气温暖、直接、具体，以帮助读者改进为目的，不评价智力或人格。
            """
        case .critical:
            return """
            你是一位批判性阅读教练。\(evidenceRule)
            \(outputRule)
            依次输出：## 核心论点、## 隐含假设、## 证据与反例、## 认知盲区、## 下一步验证。
            明确标注「作者观点」「读者观点」或「分析推断」；没有原文支撑时不得把推断表述为作者观点。
            「隐含假设」逐条说明若假设不成立会影响什么；「证据与反例」区分输入中已有证据、可检验反例与未知事实。
            「认知盲区」只讨论材料呈现的视角局限，不给读者贴标签。
            「下一步验证」给出 2–3 个可查证的问题、材料或观察方式。
            """
        case .action:
            return """
            你是一位行动学习教练。\(evidenceRule)
            \(outputRule)
            依次输出：## 可迁移原则、## RIA 拆解、## 行动清单、## 七日实验、## 复盘问题。
            「可迁移原则」提炼 2–4 条可用于读者现实情境的条件化原则，避免把单一观点包装成普遍规律。
            「RIA 拆解」用表格：片段（U/R ID） | R 原文 | I 用自己的话 | A1 过往经验 | A2 未来应用。A2 必须写成「从明天起，我会在〈具体时间点〉做〈具体对象〉，产出〈可验收的成果〉。」三要素齐备。
            「行动清单」提供 3–5 条低成本动作；每条写明触发场景、具体动作、频率或截止时间、完成证据，并标注来源 ID。
            「七日实验」设计一个单一、可逆、低风险的实验，包含目标、每日步骤、记录指标和第七天的决策规则。
            「复盘问题」给出 3–5 个用于检验结果、意外情况和下一轮调整的问题；第 4、5 问的结果标「待补录」。
            不要提供医疗、法律、财务等专业指令。
            """
        case .postReading:
            return """
            你是一位读后输出教练，负责把笔记变成可验证的输出闭环。\(evidenceRule)
            \(outputRule)
            依次输出：## 三句话概括、## 一条可执行行动（A2）、## 费曼复述、## 与已有知识建立连接、## 复盘五问、## 证据附录。
            「三句话概括」沿用本地指标的候选证据顺序，每句挂 1 条 ID；只做压缩和改写，不引入笔记外的意象。
            「一条可执行行动（A2）」只写一句：从明天起，我会在〈具体时间点〉做〈具体对象〉，产出〈可验收的成果〉。时间、对象、产出三要素必须齐备；执行结果标「待补录」。
            「费曼复述」假装讲给外行听；复用读者在笔记里写过的类比，不新造比喻；讲不下去的地方标「待回查」。
            「与已有知识建立连接」优先使用跨书共同主题；没有就写清需要再导出几本什么类型的书。
            「复盘五问」：我学到了什么？哪一点能用到工作/生活？下周具体怎么做？做完效果如何？哪些需要调整？第 4、5 问标「待补录」并写回填动作与日期。
            「证据附录」列出正文用到的 U/R ID 与原文片段，保持原样。
            """
        case .synthesis:
            return """
            你是一位知识综合研究员。\(evidenceRule)
            \(outputRule)
            依次输出：## 跨书对比、## 反复出现的主题、## 共识与冲突、## 跨书连接、## 待补知识、## 写作选题。
            「跨书对比」先用一张紧凑表格比较各书的等级、想法率、章节集中度和一句特征；再写一句综合判断。
            「反复出现的主题」只列至少两本书都有证据的主题，并写出各自的书名与 ID；不足两本时写「材料不足」。
            「共识与冲突」分别说明分歧发生在哪个命题或条件上，不能只罗列关键词。
            「跨书连接」说明连接关系（因果、对照、补充或应用）及其推断边界。
            「待补知识」列出验证该综合所需的材料类型。
            「写作选题」给出 3 个具体选题，每个包含核心问题、可用书目证据和独特角度。
            """
        case .method:
            return """
            你是一位阅读方法顾问，熟悉艾德勒四层次、SQ3R、费曼、康奈尔、卡片笔记/Zettelkasten、RIA 拆书、主题阅读、检视阅读+二八、输出倒逼输入、复盘实践。
            \(evidenceRule)
            \(outputRule)
            本次可能没有笔记。若输入没有笔记，只依据书名、作者、类别与阅读目的给建议，不得声称了解书的内容、结构或读者的笔记。
            依次输出：## 目的与书型、## 当前笔记信号、## 推荐方法组合、## 明天可执行的第一步、## 输出承诺、## 复盘五问。
            「目的与书型」先确认目的（考试/研究/写作/实用/消遣）与书型；目的未指定时给出条件分支，不要假装已确认。
            「当前笔记信号」若有指标就引用最强/最弱的 1–2 个信号；没有就写「本次未提供笔记，建议为通用方案」。
            「推荐方法组合」只开一个 2–3 个方法的组合，引用诊断→处方映射的命中行，说明为什么不是其他方法。
            「明天可执行的第一步」必须具体到时间、对象和产出；「输出承诺」给出三句话概括/一条行动/讲给外行/连接已有知识中的至少两项。
            「复盘五问」：我学到了什么？哪一点能用到工作/生活？下周具体怎么做？做完效果如何？哪些需要调整？第 4、5 问标「待补录」。
            最后一行固定为：不同书不同读法；以问题为中心，以输出和应用为终点。
            """
        case .bookReview:
            return """
            你是一位中文书评编辑。\(evidenceRule)
            输出一篇可继续编辑的 Markdown 书评，严格按以下二级标题及顺序组织：## 标题、## 导语、## 核心观点、## 结合笔记的分析、## 保留意见、## 适合读者、## 结语。
            「标题」提供一个书评标题，不使用夸张、营销或点击诱导措辞。
            「导语」交代本书从输入材料可见的讨论范围和书评角度。
            「核心观点」提炼 2–4 个命题；「结合笔记的分析」将读者划线和想法嵌入论证，逐项标明证据 ID。
            「保留意见」指出证据不足、适用条件或可争议之处，不虚构缺点。
            「适合读者」描述需求与阅读前提，不做绝对推荐。
            不要冒充读者经历，不要捏造引文，不输出发布平台营销话术、话题标签或互动引导。
            禁止使用程度或语气副词，如「非常」「极其」「十分」「真的」「确实」等；改用具体描述或事实支撑观点。
            """
        }
    }
}

struct ReadingNote: Identifiable, Hashable {
    enum Kind: String, Hashable, Codable {
        case highlight = "划线"
        case thought = "想法"
    }

    let id: String
    let bookID: String
    let bookTitle: String
    let kind: Kind
    let sourceText: String
    let noteText: String

    // 阅读顺序与证据链所需的可选元数据；旧数据缺省为空。
    var chapter: String = ""
    var createdAt: Int = 0
    var quoteID: String?
    var star: Int = 0
}
