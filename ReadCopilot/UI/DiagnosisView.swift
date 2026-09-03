import SwiftUI

struct CopilotWorkspace: View {
    @ObservedObject var store: LibraryStore
    @ObservedObject var knowledgeStore: KnowledgeStore
    @Binding var selectedBookID: String
    @State private var scope: AnalysisScope = .book
    @State private var template: AnalysisTemplate = .coach
    @State private var selectedCategory = ""

    private var categories: [String] {
        Array(Set(store.books.map(\.category).filter { !$0.isEmpty })).sorted()
    }

    private var selectedBooks: [LibraryBook] {
        switch scope {
        case .book:
            return store.books.filter { $0.id == selectedBookID }
        case .category:
            return store.books.filter { $0.category == selectedCategory && !$0.isAlbum }
        case .library:
            return store.books.filter { !$0.isAlbum }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Copilot 分析工作台")
                    .font(Theme.serifTitle(22))
                Picker("范围", selection: $scope) {
                    ForEach(AnalysisScope.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                HStack {
                    if scope == .book {
                        Picker("图书", selection: $selectedBookID) {
                            Text("选择一本书").tag("")
                            ForEach(store.books.filter { !$0.isAlbum }) { Text($0.title).tag($0.id) }
                        }
                    } else if scope == .category {
                        Picker("类别", selection: $selectedCategory) {
                            Text("选择类别").tag("")
                            ForEach(categories, id: \.self) { Text($0).tag($0) }
                        }
                    }
                    Picker("模板", selection: $template) {
                        ForEach(AnalysisTemplate.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Text(template.description)
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.inkSecondary)
            }
            .padding(24)

            Divider()

            if selectedBooks.isEmpty {
                ContentUnavailableView(
                    scope == .library ? "书库为空，请先同步" : "选择分析范围",
                    systemImage: "sparkles.rectangle.stack"
                )
            } else {
                DiagnosisColumn(books: selectedBooks, template: template, knowledgeStore: knowledgeStore)
                    .id("\(scope.rawValue)-\(selectedBooks.map(\.id).joined())-\(template.rawValue)")
            }
        }
        .background(Theme.bg)
    }
}

// MARK: - 诊断详情列
// 当用户在书库选中一本书后显示:书籍信息 + LLM 笔记写作诊断报告

struct DiagnosisColumn: View {
    let books: [LibraryBook]
    let template: AnalysisTemplate
    @ObservedObject var knowledgeStore: KnowledgeStore
    @StateObject private var model = DiagnosisModel()
    @State private var showExportPanel = false
    @State private var showNotesExportPanel = false
    @State private var showConsent = false
    @State private var standaloneNotes: [ReadingNote] = []
    @State private var loadingBookNotes = false
    @State private var bookNotesMessage: String?

    private var primaryBook: LibraryBook? { books.first }
    private var analysisTitle: String {
        if let primaryBook, books.count == 1 {
            return "《\(primaryBook.title)》"
        }
        return "\(books.count) 本书"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: 书籍头部
                if let primaryBook, books.count == 1 {
                    BookHeader(book: primaryBook)
                } else {
                    Label("\(books.count) 本书 · \(template.rawValue)", systemImage: "books.vertical")
                        .font(Theme.serifTitle(18))
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                }

                Divider().padding(.horizontal, 24).padding(.vertical, 20)

                // MARK: 诊断区域
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Label(template.rawValue, systemImage: "sparkles")
                            .font(Theme.serifTitle(17))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        if let primaryBook, books.count == 1 {
                            Menu {
                                Button {
                                    Task { await loadBookNotes(for: primaryBook, exportAfterLoading: true) }
                                } label: {
                                    Label("导出全部划线与笔记", systemImage: "square.and.arrow.up")
                                }
                                Button {
                                    Task { await importBookNotes(for: primaryBook) }
                                } label: {
                                    Label("导入知识库", systemImage: "tray.and.arrow.down")
                                }
                            } label: {
                                if loadingBookNotes {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Label("划线与笔记", systemImage: "highlighter")
                                        .font(Theme.body(12))
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                            .disabled(loadingBookNotes)
                        }
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

                    if let bookNotesMessage {
                        Text(bookNotesMessage)
                            .font(Theme.body(12))
                            .foregroundStyle(Theme.inkSecondary)
                    }

                    switch model.state {
                    case .idle:
                        DiagnosisIdleView(
                            title: analysisTitle,
                            template: template,
                            start: { showConsent = true }
                        )
                    case .fetchingNotes:
                        DiagnosisProgressView(
                            message: "正在获取笔记与划线… \(model.completedBooks)/\(model.totalBooks)"
                        )
                    case .generating:
                        DiagnosisProgressView(message: "AI 诊断中，请稍候…")
                    case .done:
                        DiagnosisReportView(report: model.report)
                    case .failed(let msg):
                        DiagnosisErrorView(
                            message: msg,
                            retry: { showConsent = true }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .background(Theme.bg)
        .navigationTitle(analysisTitle)
        .sheet(isPresented: $showExportPanel) {
            ExportPanel(books: books, report: model.report, notes: model.notes)
        }
        .sheet(isPresented: $showNotesExportPanel) {
            if let primaryBook {
                ExportPanel.NotesExportPanel(book: primaryBook, notes: standaloneNotes)
            }
        }
        .alert("发送笔记进行分析？", isPresented: $showConsent) {
            Button("取消", role: .cancel) {}
            Button("同意并开始") {
                model.run(books: books, template: template)
            }
        } message: {
            Text("将把所选 \(books.count) 本书的划线与笔记发送到你配置的 LLM 服务商。私密内容请勿继续。")
        }
    }

    private func loadBookNotes(for book: LibraryBook, exportAfterLoading: Bool) async {
        loadingBookNotes = true
        bookNotesMessage = nil
        defer { loadingBookNotes = false }
        do {
            standaloneNotes = try await model.collectNotes(for: book)
            bookNotesMessage = "已获取 \(standaloneNotes.count) 条划线与笔记"
            if exportAfterLoading {
                showNotesExportPanel = true
            }
        } catch {
            bookNotesMessage = "获取失败：\(error.localizedDescription)"
        }
    }

    private func importBookNotes(for book: LibraryBook) async {
        loadingBookNotes = true
        bookNotesMessage = nil
        defer { loadingBookNotes = false }
        do {
            let notes = try await model.collectNotes(for: book)
            let importedCount = knowledgeStore.importNotes(notes)
            bookNotesMessage = importedCount == 0 ? "这 \(notes.count) 条记录已在知识库中" : "已导入知识库 \(importedCount) 条记录"
        } catch {
            bookNotesMessage = "导入失败：\(error.localizedDescription)"
        }
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
                        TagChip("✓ 读完", color: Theme.success)
                    }
                    if book.isAlbum {
                        TagChip("有声书", color: Theme.info)
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
    let title: String
    let template: AnalysisTemplate
    let start: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "pencil.and.outline")
                .font(.system(size: 40))
                .foregroundStyle(Theme.hairline)
            Text("AI 将使用「\(template.rawValue)」模板分析\(title)中的划线与想法。")
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            Button {
                start()
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
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ErrorBanner(message: message)
            Button {
                retry()
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
    let books: [LibraryBook]
    let report: String
    let notes: [ReadingNote]
    @State private var exportingMarkdown = false
    @State private var exportingPDF = false
    @State private var exportError: String?

    private var markdownContent: String {
        ReportExporter.markdown(
            title: books.count == 1 ? "《\(books.first?.title ?? "未命名")》阅读分析" : "跨书阅读分析",
            author: books.count == 1 ? books.first?.author ?? "" : "",
            report: report,
            notes: notes
        )
    }

    struct NotesExportPanel: View {
        @Environment(\.dismiss) var dismiss
        let book: LibraryBook
        let notes: [ReadingNote]
        @State private var exportingMarkdown = false
        @State private var exportError: String?

        private var content: String {
            ReportExporter.notesMarkdown(title: book.title, author: book.author, notes: notes)
        }

        var body: some View {
            VStack(spacing: 20) {
                Text("导出划线与笔记")
                    .font(Theme.serifTitle(18))
                Text("《\(book.title)》共 \(notes.count) 条记录")
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.inkSecondary)
                if let exportError {
                    ErrorBanner(message: exportError)
                }
                HStack(spacing: 12) {
                    Button("导出 Markdown") { exportingMarkdown = true }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .fileExporter(
                            isPresented: $exportingMarkdown,
                            document: ReportDocument(data: Data(content.utf8)),
                            contentType: .plainText,
                            defaultFilename: "\(sanitize(book.title))_划线与笔记_\(DateFormatter.compact.string(from: Date())).md"
                        ) { result in
                            if case .failure(let error) = result {
                                exportError = error.localizedDescription
                            }
                        }
                    Button("关闭") { dismiss() }
                        .buttonStyle(.bordered)
                }
            }
            .padding(32)
            .frame(minWidth: 360, minHeight: 190)
            .background(Theme.bg)
        }

        private func sanitize(_ text: String) -> String {
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "\u{4E00}-\u{9FFF}"))
            return text.map { scalar in
                scalar.unicodeScalars.allSatisfy(allowed.contains) ? String(scalar) : "_"
            }.joined().prefix(30).description
        }
    }

    private var filename: String {
        sanitize(books.count == 1 ? books.first?.title ?? "阅读分析" : "跨书阅读分析")
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("导出诊断报告")
                .font(Theme.serifTitle(18))
                .foregroundStyle(Theme.ink)

            Text(books.count == 1 ? "《\(books.first?.title ?? "未命名")》" : "\(books.count) 本书")
                .font(Theme.body(14))
                .foregroundStyle(Theme.inkSecondary)

            if let err = exportError {
                ErrorBanner(message: err)
            }

            HStack(spacing: 12) {
                Button("导出 Markdown") { exportingMarkdown = true }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .fileExporter(
                        isPresented: $exportingMarkdown,
                        document: ReportDocument(data: Data(markdownContent.utf8)),
                        contentType: .plainText,
                        defaultFilename: "\(filename)_\(DateFormatter.compact.string(from: Date())).md"
                    ) { result in handle(result) }
                Button("导出 PDF") { exportingPDF = true }
                    .buttonStyle(.bordered)
                    .fileExporter(
                        isPresented: $exportingPDF,
                        document: ReportDocument(data: ReportExporter.pdf(from: markdownContent)),
                        contentType: .pdf,
                        defaultFilename: "\(filename)_\(DateFormatter.compact.string(from: Date())).pdf"
                    ) { result in handle(result) }
                Button("关闭") { dismiss() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(32)
        .frame(minWidth: 360, minHeight: 200)
        .background(Theme.bg)
    }

    private func sanitize(_ s: String) -> String {
        // 保留中文、字母、数字，其余替换为下划线
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "\u{4E00}-\u{9FFF}"))
        return s.map { c in
            c.unicodeScalars.allSatisfy({ allowed.contains($0) }) ? String(c) : "_"
        }.joined()
        .prefix(30).description
    }

    private func handle(_ result: Result<URL, Error>) {
        if case .failure(let error) = result {
            exportError = error.localizedDescription
        }
    }
}

extension DateFormatter {
    static let compact: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f
    }()
}
