import SwiftUI

// MARK: - 诊断详情列
// 当用户在书库选中一本书后显示:书籍信息 + LLM 笔记写作诊断报告

struct DiagnosisColumn: View {
    let book: LibraryBook
    @StateObject private var model = DiagnosisModel()
    @State private var showExportPanel = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: 书籍头部
                BookHeader(book: book)

                Divider().padding(.horizontal, 24).padding(.vertical, 20)

                // MARK: 诊断区域
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Label("笔记写作诊断", systemImage: "sparkles")
                            .font(Theme.serifTitle(17))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        switch model.state {
                        case .done:
                            Button {
                                showExportPanel = true
                            } label: {
                                Label("导出报告", systemImage: "square.and.arrow.up")
                                    .font(Theme.body(12))
                                    .foregroundStyle(Theme.accent)
                            }
                            .buttonStyle(.plain)
                        default:
                            EmptyView()
                        }
                    }

                    switch model.state {
                    case .idle:
                        DiagnosisIdleView(book: book, model: model)
                    case .fetchingNotes:
                        DiagnosisProgressView(message: "正在获取笔记与划线…")
                    case .generating:
                        DiagnosisProgressView(message: "AI 诊断中，请稍候…")
                    case .done:
                        DiagnosisReportView(report: model.report)
                    case .failed(let msg):
                        DiagnosisErrorView(message: msg, book: book, model: model)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .background(Theme.bg)
        .navigationTitle(book.title)
        .sheet(isPresented: $showExportPanel) {
            ExportPanel(book: book, report: model.report)
        }
        // 切书时重置
        .id(book.id)
    }
}

// MARK: - 书籍头部(封面 + 元信息)
struct BookHeader: View {
    let book: LibraryBook

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            AsyncImage(url: URL(string: book.cover)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fit)
                default:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.hairline)
                        .overlay(
                            Image(systemName: book.isAlbum ? "headphones" : "book.closed.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Theme.inkSecondary)
                        )
                }
            }
            .frame(width: 80, height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 8) {
                Text(book.title)
                    .font(Theme.serifTitle(20))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(3)
                if !book.author.isEmpty {
                    Text(book.author)
                        .font(Theme.body(14))
                        .foregroundStyle(Theme.inkSecondary)
                }
                HStack(spacing: 8) {
                    if !book.category.isEmpty {
                        TagChip(book.category)
                    }
                    if book.finished {
                        TagChip("✓ 读完", color: .green)
                    }
                    if book.isAlbum {
                        TagChip("有声书", color: .blue)
                    }
                }
                if book.readUpdateTime > 0 {
                    Text("最近阅读 \(LibraryStore.fmtDate(book.readUpdateTime))")
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }
}

// MARK: - 待开始状态
struct DiagnosisIdleView: View {
    let book: LibraryBook
    @ObservedObject var model: DiagnosisModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "pencil.and.outline")
                .font(.system(size: 40))
                .foregroundStyle(Theme.hairline)
            Text("AI 将分析你在《\(book.title)》中的划线与想法，\n诊断笔记思维模式，给出写作改进建议。")
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            Button {
                model.run(book: book)   // 后台运行，完成时通知
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("开始笔记诊断")
                }
                .font(Theme.body(14))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - 生成中
struct DiagnosisProgressView: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView().controlSize(.regular)
            Text(message)
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - 诊断报告（逐块 Markdown 渲染，支持 ## 标题 + 正文）
struct DiagnosisReportView: View {
    let report: String

    /// 将报告按行切块：连续非标题行合并为段落，## 行单独成块
    private var blocks: [Block] {
        enum Kind { case heading, body }
        struct Line { var kind: Kind; var text: String }

        let lines = report.components(separatedBy: .newlines)
        var result: [Block] = []
        var pendingBody: [String] = []
        func flush(_ buf: [String]) -> Block? {
            let joined = buf.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return joined.isEmpty ? nil : Block(isHeading: false, text: joined)
        }
        for line in lines {
            if line.hasPrefix("## ") || line.hasPrefix("### ") {
                if let b = flush(pendingBody) { result.append(b) }
                pendingBody = []
                let heading = line.drop(while: { $0 == "#" || $0 == " " })
                result.append(Block(isHeading: true, text: String(heading)))
            } else {
                pendingBody.append(line)
            }
        }
        if let b = flush(pendingBody) { result.append(b) }
        return result
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                if block.isHeading {
                    Text(block.text)
                        .font(Theme.serifTitle(16))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 8)
                } else {
                    // 段落内保留 **粗体** 等行内 Markdown
                    Text((try? AttributedString(markdown: block.text)) ?? AttributedString(block.text))
                        .font(Theme.body(14))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(5)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(20)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
    }
    struct Block { var isHeading: Bool; var text: String }
}

// MARK: - 出错
struct DiagnosisErrorView: View {
    let message: String
    let book: LibraryBook
    @ObservedObject var model: DiagnosisModel

    var body: some View {
        VStack(spacing: 12) {
            ErrorBanner(message: message)
            Button {
                model.run(book: book)
            } label: {
                Label("重试", systemImage: "arrow.clockwise")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 导出面板 (Sheet)
struct ExportPanel: View {
    @Environment(\.dismiss) var dismiss
    let book: LibraryBook
    let report: String
    @State private var saved = false
    @State private var saveError: String?

    private var markdownContent: String {
        "# 《\(book.title)》笔记诊断报告\n\n**作者:** \(book.author)\n**品类:** \(book.category)\n**诊断时间:** \(Date().formatted(.dateTime.year().month().day()))\n\n---\n\n\(report)"
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("导出诊断报告")
                .font(Theme.serifTitle(18))
                .foregroundStyle(Theme.ink)

            Text("《\(book.title)》")
                .font(Theme.body(14))
                .foregroundStyle(Theme.inkSecondary)

            if saved {
                Label("已保存", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(Theme.body(14))
            } else if let err = saveError {
                ErrorBanner(message: err)
            } else {
                HStack(spacing: 12) {
                    Button("保存 Markdown") {
                        saveMarkdown()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)

                    Button("关闭") { dismiss() }
                        .buttonStyle(.bordered)
                }
            }

            if saved {
                Button("关闭") { dismiss() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(32)
        .frame(minWidth: 360, minHeight: 200)
        .background(Theme.bg)
    }

    private func saveMarkdown() {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let filename = "ReadCopilot_\(sanitize(book.title))_\(DateFormatter.compact.string(from: Date())).md"
        let url = desktop.appendingPathComponent(filename)
        do {
            try markdownContent.write(to: url, atomically: true, encoding: .utf8)
            saved = true
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func sanitize(_ s: String) -> String {
        // 保留中文、字母、数字，其余替换为下划线
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "\u{4E00}-\u{9FFF}"))
        return s.map { c in
            c.unicodeScalars.allSatisfy({ allowed.contains($0) }) ? String(c) : "_"
        }.joined()
        .prefix(30).description
    }
}

extension DateFormatter {
    static let compact: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f
    }()
}
