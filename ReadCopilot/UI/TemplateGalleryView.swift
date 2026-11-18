import SwiftUI

// MARK: - 模板画廊
//
// 八个模板共享同一套证据规则，区别只在问题与报告结构。
// 画廊只负责挑选模板，不改变分析范围、笔记语料和本地指标。

struct TemplateGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    let current: AnalysisTemplate
    let onSelect: (AnalysisTemplate) -> Void

    @State private var category: AnalysisTemplate.Category?

    private let columns = [
        GridItem(.flexible(minimum: 260), spacing: 14),
        GridItem(.flexible(minimum: 260), spacing: 14)
    ]

    private var templates: [AnalysisTemplate] {
        AnalysisTemplate.allCases.filter { category == nil || $0.category == category }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("先选问题，再选模板")
                            .font(Theme.serifTitle(22))
                            .foregroundStyle(Theme.ink)
                        Text("模板只改变报告结构与追问方式；引用规则、指标口径和隐私边界完全相同。")
                            .font(Theme.body(12))
                            .foregroundStyle(Theme.inkSecondary)
                            .lineSpacing(3)
                    }

                    categoryFilter

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                        ForEach(templates) { template in
                            TemplateCard(
                                template: template,
                                isCurrent: template == current,
                                select: {
                                    onSelect(template)
                                    dismiss()
                                }
                            )
                        }
                    }

                    Label(
                        "模板不会重算等级，也不会补写书中内容。证据不足时报告会写「待补录」。",
                        systemImage: "checkmark.shield"
                    )
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.inkSecondary)
                }
                .padding(24)
            }
            .background(Theme.bg)
            .navigationTitle("选择报告模板")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 680, minHeight: 620)
        #endif
    }

    private var categoryFilter: some View {
        HStack(spacing: 8) {
            FilterChip(title: "全部", selected: category == nil) {
                category = nil
            }
            ForEach(AnalysisTemplate.Category.allCases, id: \.self) { item in
                FilterChip(title: item.rawValue, selected: category == item) {
                    category = item
                }
            }
        }
    }
}

// MARK: - 模板卡片

private struct TemplateCard: View {
    let template: AnalysisTemplate
    let isCurrent: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: template.icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 34, height: 34)
                        .background(Theme.accent.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 9))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.rawValue)
                            .font(Theme.serifTitle(16))
                            .foregroundStyle(Theme.ink)
                        Text("\(template.category.rawValue) · 约 \(template.estimatedMinutes) 分钟")
                            .font(Theme.body(10))
                            .foregroundStyle(Theme.inkSecondary)
                    }

                    Spacer(minLength: 4)

                    if isCurrent {
                        Text("当前")
                            .font(Theme.body(10))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Theme.accent.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                Text(template.tagline)
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.inkSecondary)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("报告结构")
                        .font(Theme.body(10))
                        .foregroundStyle(Theme.inkSecondary)
                    Text(template.sections.joined(separator: " · "))
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 6) {
                    Image(systemName: template.requiresNotes ? "highlighter" : "book.closed")
                        .font(.system(size: 9))
                    Text(template.requiresNotes ? "需要该书的划线或想法" : "可只用书名、类别与阅读目的")
                        .font(Theme.body(10))
                }
                .foregroundStyle(template.requiresNotes ? Theme.inkSecondary : Theme.info)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCurrent ? Theme.accent.opacity(0.55) : Theme.hairline.opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(template.rawValue)，\(template.tagline)")
    }
}

private struct FilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.body(12))
                .foregroundStyle(selected ? .white : Theme.inkSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(selected ? Theme.accent : Theme.panel)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(selected ? Color.clear : Theme.hairline.opacity(0.6), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
