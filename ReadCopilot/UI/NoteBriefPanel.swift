import SwiftUI

// MARK: - 本地指标面板
// 展示 NoteMetrics 的确定性结果：等级、KPI、七因子、自动诊断与读法处方。
// 这部分不经过 LLM，报告正文只负责解释它。

struct NoteBriefPanel: View {
    let briefs: [NoteBrief]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("本地指标", systemImage: "function")
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
                Text("确定性计算 · 不经过 LLM")
                    .font(Theme.body(10))
                    .foregroundStyle(Theme.inkSecondary)
            }
            ForEach(briefs) { brief in
                BriefCard(brief: brief)
            }
        }
    }
}

private struct BriefCard: View {
    let brief: NoteBrief

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("《\(brief.bookTitle)》")
                    .font(Theme.serifTitle(15))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer()
                GradeChip(grade: brief.grade)
            }

            Text(brief.grade.verdict)
                .font(Theme.body(12))
                .foregroundStyle(Theme.inkSecondary)
                .lineSpacing(3)

            LazyVGrid(columns: columns, spacing: 8) {
                MetricTile(key: "笔记", value: "\(brief.counts.notes)", note: "条")
                MetricTile(key: "划线", value: "\(brief.counts.underlines)", note: "条")
                MetricTile(key: "想法", value: "\(brief.counts.ideas)", note: "条")
                MetricTile(key: "想法率", value: String(format: "%.2f", brief.ratios.ideaRate), note: "想法/划线")
                MetricTile(key: "章节覆盖", value: "\(brief.counts.chaptersWithNotes)/\(brief.counts.chaptersTotal)", note: "有笔记")
                MetricTile(key: "反思密度", value: "\(percent(brief.ratios.reflectionDensity))%", note: "关键词命中")
                MetricTile(key: "行动标记", value: "\(percent(brief.ratios.actionRate))%", note: "关键词命中")
                MetricTile(key: "可追溯", value: "\(percent(brief.ratios.linkedRate))%", note: "想法挂划线")
            }

            VStack(spacing: 5) {
                ForEach(brief.factors) { factor in
                    FactorRow(factor: factor)
                }
            }
            .padding(8)
            .background(Theme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if !brief.diagnoses.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("自动诊断")
                        .font(Theme.body(10))
                        .foregroundStyle(Theme.inkSecondary)
                    ForEach(Array(brief.diagnoses.prefix(3).enumerated()), id: \.offset) { _, diagnosis in
                        Text("• \(diagnosis)")
                            .font(Theme.body(11))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(2)
                    }
                }
            }

            MethodCard(prescription: brief.prescription)
        }
        .padding(12)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline.opacity(0.7), lineWidth: 1))
    }

    private func percent(_ value: Double) -> Int {
        Int((value * 100).rounded(.down))
    }
}

struct GradeChip: View {
    let grade: NoteGrade

    private var color: Color {
        switch grade.level {
        case "A": return Theme.success
        case "B": return Theme.info
        case "C": return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(grade.level)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text("\(String(format: "%.1f", grade.score))/100")
                .font(Theme.body(11))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .foregroundStyle(color)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 1))
    }
}

private struct MetricTile: View {
    let key: String
    let value: String
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(key)
                .font(Theme.body(10))
                .foregroundStyle(Theme.inkSecondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Text(note)
                .font(Theme.body(9))
                .foregroundStyle(Theme.inkSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Theme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct FactorRow: View {
    let factor: GradeFactor

    var body: some View {
        HStack(spacing: 8) {
            Text(factor.label)
                .font(Theme.body(10))
                .foregroundStyle(Theme.inkSecondary)
                .frame(width: 58, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.hairline.opacity(0.25))
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: max(2, proxy.size.width * factor.normalized))
                }
            }
            .frame(height: 5)

            Text(factor.display)
                .font(Theme.body(10))
                .foregroundStyle(Theme.inkSecondary)
                .frame(width: 100, alignment: .trailing)
                .lineLimit(1)

            Text("\(String(format: "%.1f", factor.points))/\(Int(factor.maxPoints))")
                .font(Theme.body(10))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, alignment: .trailing)
        }
        .help(factor.rule)
    }
}

private struct MethodCard: View {
    let prescription: MethodPrescription

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text("读法处方")
                    .font(Theme.body(10))
                    .foregroundStyle(Theme.inkSecondary)
                Text(prescription.stage.rawValue)
                    .font(Theme.body(9))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Theme.accent.opacity(0.1))
                    .clipShape(Capsule())
                Spacer()
            }
            Text(prescription.combo.joined(separator: " + "))
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.ink)
            Text("触发：\(prescription.trigger)")
                .font(Theme.body(10))
                .foregroundStyle(Theme.inkSecondary)
            Text("明天：\(prescription.firstStep)")
                .font(Theme.body(11))
                .foregroundStyle(Theme.ink)
                .lineSpacing(2)
            Text("会移动：\(prescription.metricMoved)")
                .font(Theme.body(10))
                .foregroundStyle(Theme.inkSecondary)
        }
        .padding(10)
        .background(Theme.accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.accent.opacity(0.18), lineWidth: 1))
    }
}
