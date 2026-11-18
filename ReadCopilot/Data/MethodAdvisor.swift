import Foundation

// MARK: - 方法处方层
//
// 方法名与阶段标签只是“建议层”，不是证据。处方必须有一个触发信号
// （指标或笔记 ID）、一个会移动的指标和明天可执行的第一步。
// 选型来源：reading-notes/references/reading-methods.md §诊断 → 处方映射。

enum ReadingStage: String, CaseIterable {
    case filter = "筛选"
    case understand = "理解"
    case internalize = "内化"
    case output = "输出"
    case apply = "应用"
}

struct MethodSignals {
    let ideaRate: Double
    let reactionShare: Double
    let synthesizeShare: Double
    let reflectionDensity: Double
    let actionRate: Double
    let questionRate: Double
    let linkedRate: Double
    let topChapterShare: Double
    let untouchedCount: Int
    let ideaCount: Int
    let bookCount: Int
    let sharedThemeCount: Int
}

struct MethodPrescription {
    let stage: ReadingStage
    let combo: [String]
    let trigger: String
    let metricMoved: String
    let firstStep: String
    let mappedRow: String
    let whyNot: String
}

enum MethodAdvisor {
    private struct Candidate {
        let severity: Double
        let stage: ReadingStage
        let primary: String
        let auxiliary: [String]
        let trigger: String
        let metricMoved: String
        let firstStep: String
        let mappedRow: String
    }

    static func prescribe(_ signals: MethodSignals) -> MethodPrescription {
        var candidates: [Candidate] = []

        if signals.ideaCount == 0 {
            candidates.append(
                Candidate(
                    severity: 1.0,
                    stage: .understand,
                    primary: "康奈尔（线索栏）",
                    auxiliary: ["费曼", "输出倒逼输入"],
                    trigger: "只有划线、没有想法（想法/划线=0）",
                    metricMoved: "ideaRate、reflectionDensity",
                    firstStep: "选一条划线，在旁栏写一句「这句话在说什么」，再用自己的话补一句「所以呢」。",
                    mappedRow: "ideaRate < 0.25 → 康奈尔（线索栏）+ 费曼 + 输出倒逼输入"
                )
            )
        } else {
            if signals.synthesizeShare <= 0.01 {
                candidates.append(
                    Candidate(
                        severity: 1.0,
                        stage: .internalize,
                        primary: "费曼",
                        auxiliary: ["卡片笔记法"],
                        trigger: "synthesize≈0（没有 ≥120 字的想法）",
                        metricMoved: "ideaDepthMix.synthesize",
                        firstStep: "选一条已有想法，用「因为…所以…」扩写到 120 字以上，并标出来源划线。",
                        mappedRow: "synthesize≈0、无 ≥120 字想法 → 费曼 + 卡片笔记法"
                    )
                )
            }

            if signals.ideaRate < 0.25 || signals.reactionShare >= 0.4 {
                let severity = max(
                    (0.25 - signals.ideaRate) / 0.25,
                    signals.reactionShare
                )
                candidates.append(
                    Candidate(
                        severity: severity,
                        stage: .understand,
                        primary: "康奈尔（线索栏）",
                        auxiliary: ["费曼", "输出倒逼输入"],
                        trigger: signals.ideaRate < 0.25
                            ? "想法/划线=\(String(format: "%.2f", signals.ideaRate))（<0.25）"
                            : "\(Int((signals.reactionShare * 100).rounded()))% 的想法是短反应（≥40%）",
                        metricMoved: "ideaRate、reflectionDensity、ideaDepthMix",
                        firstStep: "选一条划线，在旁栏写一个关键词和一个问题，再用一句话总结这一段。",
                        mappedRow: "ideaRate < 0.25 或 reaction ≥ 40% → 康奈尔（线索栏）+ 费曼 + 输出倒逼输入"
                    )
                )
            }

            if signals.actionRate < 0.15 {
                candidates.append(
                    Candidate(
                        severity: (0.15 - signals.actionRate) / 0.15,
                        stage: .apply,
                        primary: "RIA（重点 A2）",
                        auxiliary: ["复盘实践", "输出倒逼输入"],
                        trigger: "行动标记 \(Int((signals.actionRate * 100).rounded()))%（<15%）",
                        metricMoved: "actionRate",
                        firstStep: "选一个片段，写出 I（自己的话复述）、A1（过往经验）、A2（下周具体应用）各一句。",
                        mappedRow: "actionRate < 15% → RIA（重点 A2）+ 复盘实践 + 输出倒逼输入"
                    )
                )
            }

            if signals.questionRate < 0.10 {
                candidates.append(
                    Candidate(
                        severity: (0.10 - signals.questionRate) / 0.10 * 0.9,
                        stage: .understand,
                        primary: "SQ3R 的 Question",
                        auxiliary: ["检视阅读"],
                        trigger: "提问率 \(Int((signals.questionRate * 100).rounded()))%（<10%）",
                        metricMoved: "questionRate",
                        firstStep: "把当前章节标题改写成 2 个问题，带着问题读下一节，并把答案写进想法。",
                        mappedRow: "questionRate 低 → SQ3R 的 Question + 检视阅读"
                    )
                )
            }

            if signals.linkedRate < 0.5 && signals.ideaCount >= 5 {
                candidates.append(
                    Candidate(
                        severity: (0.5 - signals.linkedRate) / 0.5 * 0.9,
                        stage: .output,
                        primary: "卡片笔记法（标来源）",
                        auxiliary: ["康奈尔线索栏"],
                        trigger: "可追溯率 \(Int((signals.linkedRate * 100).rounded()))%（<50%）",
                        metricMoved: "linkedRate",
                        firstStep: "选 3 条没有挂划线的想法，各补一条原文引用和来源章节。",
                        mappedRow: "linkedRate < 50% → 卡片笔记（标来源）+ 康奈尔线索栏"
                    )
                )
            }
        }

        if signals.topChapterShare >= 0.5 || signals.untouchedCount > 0 {
            candidates.append(
                Candidate(
                    severity: 0.8,
                    stage: .filter,
                    primary: "检视阅读 + 二八法则",
                    auxiliary: [],
                    trigger: signals.topChapterShare >= 0.5
                        ? "\(Int((signals.topChapterShare * 100).rounded()))% 的笔记集中在单一章节"
                        : "有 \(signals.untouchedCount) 个章节未被笔记覆盖",
                    metricMoved: "topChapterShare、章节覆盖",
                    firstStep: "只读目录、序言和结论，列出 2 个核心章节和 1 个可略读章节。",
                    mappedRow: "topChapterShare ≥ 50% 或有未覆盖章节 → 检视阅读 + 二八法则"
                )
            )
        }

        if signals.bookCount > 1 && signals.sharedThemeCount == 0 {
            candidates.append(
                Candidate(
                    severity: 0.9,
                    stage: .internalize,
                    primary: "主题阅读",
                    auxiliary: ["卡片笔记法"],
                    trigger: "多本书之间没有可识别的共同主题",
                    metricMoved: "跨书主题、ideaDepthMix.synthesize",
                    firstStep: "定义一个跨书问题，从每本书各选 1 条证据，写成 3 张卡片并标出来源。",
                    mappedRow: "多本书之间无共同主题 → 主题阅读 + 卡片笔记法"
                )
            )
        }

        guard !candidates.isEmpty else {
            return MethodPrescription(
                stage: .output,
                combo: ["输出倒逼输入", "卡片笔记法"],
                trigger: "各项代理指标未见明显短板",
                metricMoved: "linkedRate、ideaDepthMix.synthesize",
                firstStep: "从本周笔记里选 3 条，各写 1 张不超过 80 字的卡片，并各加 1 条与旧知识的连接。",
                mappedRow: "无弱信号 → 输出倒逼输入 + 卡片笔记法",
                whyNot: "当前不需要先补筛选或理解环节，直接进入输出。"
            )
        }

        let sorted = candidates.sorted { $0.severity > $1.severity }
        let top = Array(sorted.prefix(2))
        var combo: [String] = []
        for candidate in top where !combo.contains(candidate.primary) {
            combo.append(candidate.primary)
        }
        for candidate in top {
            for auxiliary in candidate.auxiliary where combo.count < 3 {
                if !combo.contains(auxiliary) { combo.append(auxiliary) }
            }
        }

        let stage = top[0].stage
        let excluded = sorted.dropFirst(2).first
        let whyNot: String
        if let excluded {
            whyNot = "未优先选「\(excluded.primary)」：当前最弱信号在\(stage.rawValue)阶段，\(excluded.primary)主要针对\(excluded.stage.rawValue)阶段。"
        } else {
            whyNot = "当前没有更多高优先级短板，先把这一个组合做完，再重新导出指标复查。"
        }

        return MethodPrescription(
            stage: stage,
            combo: combo,
            trigger: top.map(\.trigger).joined(separator: "；"),
            metricMoved: top.map(\.metricMoved).joined(separator: "、"),
            firstStep: top[0].firstStep,
            mappedRow: top.map(\.mappedRow).joined(separator: "；"),
            whyNot: whyNot
        )
    }
}
