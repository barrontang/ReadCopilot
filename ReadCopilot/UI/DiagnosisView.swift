import SwiftUI

struct CopilotWorkspace: View {
    @ObservedObject var store: LibraryStore
    @ObservedObject var knowledgeStore: KnowledgeStore
    @ObservedObject var sessionStore: DiagnosisSessionStore
    @Binding var selectedBookID: String
    @State private var scope: AnalysisScope = .book
    @State private var template: AnalysisTemplate = .coach
    @State private var purpose = ""
    @State private var selectedCategory = ""
    @State private var showJobList = false
    @State private var showTemplateGallery = false

    private var categories: [String] {
        Array(Set(store.books.map(\.category).filter { !$0.isEmpty })).sorted()
    }

    private static let purposes = ["考试", "研究", "写作", "实用", "消遣"]

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
                HStack(alignment: .firstTextBaseline) {
                    Text("Copilot 分析工作台")
                        .font(Theme.serifTitle(22))
                    Spacer()
                    Button {
                        showJobList = true
                    } label: {
                        if sessionStore.hasRunningJobs {
                            Label("\(sessionStore.runningJobCount) 项分析进行中", systemImage: "clock.arrow.circlepath")
                                .font(Theme.body(12))
                                .foregroundStyle(Theme.accent)
                        } else {
                            Label("已分析工作列表", systemImage: "list.bullet.rectangle")
                                .font(Theme.body(12))
                                .foregroundStyle(Theme.inkSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(sessionStore.jobs.isEmpty)
                }
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
                    Button {
                        showTemplateGallery = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: template.icon)
                            Text("模板：\(template.rawValue)")
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Theme.inkSecondary)
                        }
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.hairline.opacity(0.6), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(template.tagline)
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.inkSecondary)
                        .lineSpacing(3)
                    Spacer()
                    Button("查看全部模板") { showTemplateGallery = true }
                        .buttonStyle(.plain)
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.accent)
                }
                if template == .method {
                    HStack(spacing: 8) {
                        Text("阅读目的")
                            .font(Theme.body(12))
                            .foregroundStyle(Theme.inkSecondary)
                        Picker("阅读目的", selection: $purpose) {
                            Text("未指定").tag("")
                            ForEach(Self.purposes, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 180)
                        Text("目的只影响方法匹配，不上传笔记。")
                            .font(Theme.body(10))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
            }
            .padding(24)

            Divider()

            if selectedBooks.isEmpty {
                ContentUnavailableView(
                    scope == .library ? "书库为空，请先同步" : "选择分析范围",
                    systemImage: "sparkles.rectangle.stack"
                )
            } else {
                DiagnosisColumn(
                    books: selectedBooks,
                    template: template,
                    purpose: purpose,
                    scope: scope,
                    selectedCategory: selectedCategory,
                    knowledgeStore: knowledgeStore,
                    sessionStore: sessionStore
                )
                .id("\(scope.rawValue)-\(selectedBooks.map(\.id).joined())-\(template.rawValue)-\(purpose)")
            }
        }
        .background(Theme.bg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showJobList) {
            DiagnosisJobListView(sessionStore: sessionStore) { job in
                scope = job.scope
                selectedCategory = job.selectedCategory
                if job.scope == .book, let first = job.books.first {
                    selectedBookID = first.id
                }
                template = job.template
                purpose = job.purpose
                showJobList = false
            }
        }
        .sheet(isPresented: $showTemplateGallery) {
            TemplateGalleryView(current: template) { selected in
                template = selected
                if selected != .method { purpose = "" }
            }
        }
    }
}

// MARK: - 诊断详情列
// 当用户在书库选中一本书后显示:书籍信息 + LLM 笔记写作诊断报告

struct DiagnosisColumn: View {
    let books: [LibraryBook]
    let template: AnalysisTemplate
    let purpose: String
    let scope: AnalysisScope
    let selectedCategory: String
    @ObservedObject var knowledgeStore: KnowledgeStore
    @ObservedObject var sessionStore: DiagnosisSessionStore
    @ObservedObject private var model: DiagnosisModel
    @State private var showExportPanel = false
    @State private var showNotesExportPanel = false
    @State private var showConsent = false
    @State private var standaloneNotes: [ReadingNote] = []
    @State private var loadingBookNotes = false
    @State private var bookNotesMessage: String?

    private let jobKey: String

    init(
        books: [LibraryBook],
        template: AnalysisTemplate,
        purpose: String,
        scope: AnalysisScope,
        selectedCategory: String,
        knowledgeStore: KnowledgeStore,
        sessionStore: DiagnosisSessionStore
    ) {
        self.books = books
        self.template = template
        self.purpose = purpose
        self.scope = scope
        self.selectedCategory = selectedCategory
        self.knowledgeStore = knowledgeStore
        self.sessionStore = sessionStore
        // key 与外层 .id() 保持一致的语义，确保同一分析目标始终复用同一个
        // DiagnosisModel 实例，即使承载它的视图（DiagnosisColumn）被重建/切走。
        let key = "\(books.map(\.id).sorted().joined(separator: ","))-\(template.rawValue)-\(purpose)"
        self.jobKey = key
        _model = ObservedObject(wrappedValue: sessionStore.model(for: key))
    }

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
                            purpose: purpose,
                            start: { showConsent = true }
                        )
                    case .fetchingNotes:
                        DiagnosisProgressView(
                            message: "正在获取笔记与划线… \(model.completedBooks)/\(model.totalBooks)"
                        )
                    case .generating:
                        VStack(alignment: .leading, spacing: 16) {
                            if !model.briefs.isEmpty {
                                NoteBriefPanel(briefs: model.briefs)
                            }
                            DiagnosisProgressView(message: "AI 诊断中，请稍候…")
                        }
                    case .done:
                        VStack(alignment: .leading, spacing: 16) {
                            if !model.briefs.isEmpty {
                                NoteBriefPanel(briefs: model.briefs)
                            }
                            DiagnosisReportView(report: model.report)
                        }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(analysisTitle)
        #if DEBUG
        .task { model.loadDemoReportIfNeeded() }
        #endif
        .sheet(isPresented: $showExportPanel) {
            ExportPanel(
                books: books,
                report: model.report,
                notes: model.notes,
                briefs: model.briefs,
                templateName: template.rawValue
            )
        }
        .sheet(isPresented: $showNotesExportPanel) {
            if let primaryBook {
                ExportPanel.NotesExportPanel(book: primaryBook, notes: standaloneNotes)
            }
        }
        .alert("发送笔记进行分析？", isPresented: $showConsent) {
            Button("取消", role: .cancel) {}
            Button("同意并开始") {
                sessionStore.registerJob(
                    key: jobKey,
                    scope: scope,
                    selectedCategory: selectedCategory,
                    books: books,
                    template: template,
                    purpose: purpose
                )
                model.run(books: books, template: template, purpose: purpose)
            }
        } message: {
            if template.requiresNotes {
                Text("将把所选 \(books.count) 本书的划线与笔记发送到你配置的 LLM 服务商。私密内容请勿继续。")
            } else {
                Text("将把所选 \(books.count) 本书的书名、作者、类别与阅读目的发送到你配置的 LLM 服务商。本次不发送笔记。")
            }
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
    let purpose: String
    let start: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: template.icon)
                .font(.system(size: 40))
                .foregroundStyle(Theme.hairline)
            Text(idleText)
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            Button {
                start()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text(template.requiresNotes ? "开始笔记诊断" : "生成读法处方")
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

    private var idleText: String {
        if template.requiresNotes {
            return "AI 将使用「\(template.rawValue)」模板分析\(title)中的划线与想法。"
        }
        let purposeText = purpose.isEmpty ? "尚未指定阅读目的" : "阅读目的：\(purpose)"
        return "「\(template.rawValue)」不需要笔记。AI 将依据\(title)的书名、作者、类别与\(purposeText)匹配读法。"
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

// MARK: - 诊断报告（逐块 Markdown 渲染，支持标题、列表、表格与段落）
struct DiagnosisReportView: View {
    let report: String

    private enum Kind { case heading, body, list, table }

    private struct Block {
        var kind: Kind
        var text: String = ""
        var items: [String] = []
        var rows: [[String]] = []
        var ordered: Bool = false
    }

    private var blocks: [Block] {
        let lines = report.components(separatedBy: .newlines)
        var result: [Block] = []
        var bodyBuffer: [String] = []
        var listBuffer: [String] = []
        var listOrdered = false

        func flushBody() {
            let joined = bodyBuffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty {
                result.append(Block(kind: .body, text: joined))
            }
            bodyBuffer = []
        }

        func flushList() {
            if !listBuffer.isEmpty {
                result.append(Block(kind: .list, items: listBuffer, ordered: listOrdered))
            }
            listBuffer = []
            listOrdered = false
        }

        var index = 0
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("|"), index + 1 < lines.count, Self.isTableSeparator(lines[index + 1]) {
                flushBody()
                flushList()
                var rows: [[String]] = [Self.parseRow(trimmed)]
                index += 2
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard candidate.hasPrefix("|") else { break }
                    rows.append(Self.parseRow(candidate))
                    index += 1
                }
                result.append(Block(kind: .table, rows: rows))
            } else if trimmed.hasPrefix("## ") || trimmed.hasPrefix("### ") {
                flushBody()
                flushList()
                let heading = trimmed.drop(while: { $0 == "#" || $0 == " " })
                result.append(Block(kind: .heading, text: String(heading)))
                index += 1
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") || trimmed.hasPrefix("* ") {
                flushBody()
                if listOrdered { flushList() }
                listBuffer.append(String(trimmed.dropFirst(2)))
                index += 1
            } else if let ordered = Self.orderedListText(trimmed) {
                flushBody()
                if !listBuffer.isEmpty && !listOrdered { flushList() }
                listOrdered = true
                listBuffer.append(ordered)
                index += 1
            } else {
                flushList()
                bodyBuffer.append(line)
                index += 1
            }
        }
        flushBody()
        flushList()
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block.kind {
                case .heading:
                    Text(block.text)
                        .font(Theme.serifTitle(16))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 8)
                case .body:
                    paragraph(block.text)
                case .list:
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(block.items.enumerated()), id: \.offset) { index, item in
                            HStack(alignment: .firstTextBaseline, spacing: 7) {
                                Text(block.ordered ? "\(index + 1)." : "•")
                                    .font(Theme.body(13))
                                    .foregroundStyle(Theme.accent)
                                paragraph(item)
                            }
                        }
                    }
                case .table:
                    tableView(block.rows)
                }
            }
        }
        .padding(20)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
    }

    private func paragraph(_ text: String) -> some View {
        Text((try? AttributedString(markdown: text)) ?? AttributedString(text))
            .font(Theme.body(14))
            .foregroundStyle(Theme.ink)
            .lineSpacing(5)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tableView(_ rows: [[String]]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text((try? AttributedString(markdown: cell)) ?? AttributedString(cell))
                                .font(Theme.body(12))
                                .fontWeight(rowIndex == 0 ? .semibold : .regular)
                                .foregroundStyle(Theme.ink)
                                .lineSpacing(3)
                                .frame(minWidth: 76, maxWidth: 320, alignment: .leading)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 7)
                                .background(rowIndex == 0 ? Theme.bg : Theme.panel)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(Theme.hairline.opacity(0.4))
                                        .frame(height: 1)
                                }
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.hairline.opacity(0.6), lineWidth: 1))
        }
    }

    private static func orderedListText(_ line: String) -> String? {
        guard let dot = line.firstIndex(of: ".") else { return nil }
        let prefix = line[line.startIndex..<dot]
        guard !prefix.isEmpty, prefix.allSatisfy({ $0.isNumber }) else { return nil }
        let afterDot = line[line.index(after: dot)...]
        guard afterDot.hasPrefix(" ") else { return nil }
        return String(afterDot.dropFirst()).trimmingCharacters(in: .whitespaces)
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("-") else { return false }
        let allowed = CharacterSet(charactersIn: "|-: ")
        return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func parseRow(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }
        return trimmed
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\\|", with: "|") }
    }
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

// MARK: - 已分析工作列表（后台分析任务的进行中/已完成状态一览）
struct DiagnosisJobListView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var sessionStore: DiagnosisSessionStore
    let onSelect: (DiagnosisSessionStore.Job) -> Void

    var body: some View {
        NavigationStack {
            List {
                if sessionStore.jobs.isEmpty {
                    ContentUnavailableView("暂无分析任务", systemImage: "sparkles.rectangle.stack")
                } else {
                    ForEach(sessionStore.jobs) { job in
                        Button {
                            onSelect(job)
                        } label: {
                            JobRow(job: job, model: sessionStore.existingModel(for: job.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("已分析工作列表")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 360)
        #endif
    }

    private struct JobRow: View {
        let job: DiagnosisSessionStore.Job
        let model: DiagnosisModel?

        var body: some View {
            HStack(spacing: 12) {
                statusIcon
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.title)
                        .font(Theme.body(14))
                        .foregroundStyle(Theme.ink)
                    Text(job.purpose.isEmpty
                         ? "\(job.template.rawValue) · \(job.scope.rawValue)"
                         : "\(job.template.rawValue) · \(job.scope.rawValue) · 目的：\(job.purpose)")
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                statusLabel
            }
            .padding(.vertical, 4)
        }

        @ViewBuilder private var statusIcon: some View {
            switch model?.state {
            case .fetchingNotes, .generating:
                ProgressView().controlSize(.small)
            case .done:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            default:
                Image(systemName: "circle.dashed").foregroundStyle(Theme.inkSecondary)
            }
        }

        @ViewBuilder private var statusLabel: some View {
            switch model?.state {
            case .fetchingNotes:
                Text("获取笔记中…").font(Theme.body(12)).foregroundStyle(Theme.inkSecondary)
            case .generating:
                Text("分析进行中…").font(Theme.body(12)).foregroundStyle(Theme.inkSecondary)
            case .done:
                Text("已完成").font(Theme.body(12)).foregroundStyle(Theme.success)
            case .failed:
                Text("失败").font(Theme.body(12)).foregroundStyle(.orange)
            default:
                Text("待开始").font(Theme.body(12)).foregroundStyle(Theme.inkSecondary)
            }
        }
    }
}

// MARK: - 导出面板 (Sheet)
struct ExportPanel: View {
    @Environment(\.dismiss) var dismiss
    let books: [LibraryBook]
    let report: String
    let notes: [ReadingNote]
    var briefs: [NoteBrief] = []
    var templateName: String = "阅读分析"

    @State private var exportingMarkdown = false
    @State private var exportingPDF = false
    @State private var exportingHTML = false
    @State private var exportError: String?
    @State private var cover: ReportCover?
    @State private var coverState: CoverState = .idle

    private enum CoverState {
        case idle, loading, embedded, placeholder
    }

    private var title: String {
        books.count == 1 ? books.first?.title ?? "未命名" : "跨书阅读分析"
    }

    private var markdownContent: String {
        ReportExporter.markdown(
            title: books.count == 1 ? "《\(title)》阅读分析" : "跨书阅读分析",
            author: books.count == 1 ? books.first?.author ?? "" : "",
            report: report,
            notes: notes,
            briefs: briefs
        )
    }

    private var htmlContent: String {
        ReportExporter.html(
            title: title,
            author: books.count == 1 ? books.first?.author ?? "" : "",
            templateName: templateName,
            report: report,
            briefs: briefs,
            cover: cover
        )
    }

    var body: some View {
        VStack(spacing: 18) {
            Text("导出诊断报告")
                .font(Theme.serifTitle(18))
                .foregroundStyle(Theme.ink)

            VStack(spacing: 4) {
                Text(books.count == 1 ? "《\(title)》" : "\(books.count) 本书")
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.inkSecondary)
                Text("\(templateName) · \(notes.count) 条划线与想法\(briefs.isEmpty ? "" : " · \(briefs.count) 份本地指标")")
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.inkSecondary)
            }

            coverStatus

            if let err = exportError {
                ErrorBanner(message: err)
            }

            HStack(spacing: 12) {
                Button("导出 HTML") { exportingHTML = true }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .fileExporter(
                        isPresented: $exportingHTML,
                        document: ReportDocument(data: Data(htmlContent.utf8)),
                        contentType: .html,
                        defaultFilename: "\(filename)_\(DateFormatter.compact.string(from: Date())).html"
                    ) { result in handle(result) }
                Button("导出 Markdown") { exportingMarkdown = true }
                    .buttonStyle(.bordered)
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

            Text("HTML 为单文件离线报告：内联 CSS，封面以 data URI 内嵌，不含脚本与远程图片。")
                .font(Theme.body(10))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(minWidth: 460, minHeight: 260)
        .background(Theme.bg)
        .task { await loadCoverIfNeeded() }
    }

    @ViewBuilder private var coverStatus: some View {
        switch coverState {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("正在下载并压缩封面…")
                    .font(Theme.body(10))
                    .foregroundStyle(Theme.inkSecondary)
            }
        case .embedded:
            Label("封面已内嵌为 data URI", systemImage: "photo.badge.checkmark")
                .font(Theme.body(10))
                .foregroundStyle(Theme.success)
        case .placeholder:
            Label("未获取到封面，将使用带标注的排版占位图", systemImage: "photo")
                .font(Theme.body(10))
                .foregroundStyle(Theme.inkSecondary)
        }
    }

    private func loadCoverIfNeeded() async {
        guard books.count == 1, let book = books.first, !book.cover.isEmpty else {
            coverState = .placeholder
            return
        }
        coverState = .loading
        cover = await ReportCoverLoader.load(urlString: book.cover)
        coverState = cover == nil ? .placeholder : .embedded
    }

    private var filename: String {
        sanitize(books.count == 1 ? books.first?.title ?? "阅读分析" : "跨书阅读分析")
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

    // MARK: 划线与笔记导出

    struct NotesExportPanel: View {
        @Environment(\.dismiss) var dismiss
        let book: LibraryBook
        let notes: [ReadingNote]
        @State private var exportingMarkdown = false
        @State private var exportingPDF = false
        @State private var exportingHTML = false
        @State private var exportError: String?
        @State private var cover: ReportCover?
        @State private var coverState: CoverState = .idle

        private enum CoverState {
            case idle, loading, embedded, placeholder
        }

        private var content: String {
            ReportExporter.notesMarkdown(title: book.title, author: book.author, notes: notes)
        }

        private var htmlContent: String {
            ReportExporter.notesHTML(book: book, notes: notes, cover: cover)
        }

        private var chapterCount: Int {
            Set(notes.map { $0.chapter.isEmpty ? "未标注章节" : $0.chapter }).count
        }

        var body: some View {
            VStack(spacing: 18) {
                Text("导出划线与笔记")
                    .font(Theme.serifTitle(18))
                VStack(spacing: 4) {
                    Text("《\(book.title)》共 \(notes.count) 条记录")
                        .font(Theme.body(14))
                        .foregroundStyle(Theme.inkSecondary)
                    Text("\(chapterCount) 个章节 · 原文不改写 · 本地生成，不调用 LLM")
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.inkSecondary)
                }
                coverStatus
                if let exportError {
                    ErrorBanner(message: exportError)
                }
                HStack(spacing: 12) {
                    Button("导出 HTML") { exportingHTML = true }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .fileExporter(
                            isPresented: $exportingHTML,
                            document: ReportDocument(data: Data(htmlContent.utf8)),
                            contentType: .html,
                            defaultFilename: "\(sanitize(book.title))_划线与笔记_\(DateFormatter.compact.string(from: Date())).html"
                        ) { result in
                            if case .failure(let error) = result {
                                exportError = error.localizedDescription
                            }
                        }
                    Button("导出 Markdown") { exportingMarkdown = true }
                        .buttonStyle(.bordered)
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
                    Button("导出 PDF") { exportingPDF = true }
                        .buttonStyle(.bordered)
                        .fileExporter(
                            isPresented: $exportingPDF,
                            document: ReportDocument(data: ReportExporter.pdf(from: content)),
                            contentType: .pdf,
                            defaultFilename: "\(sanitize(book.title))_划线与笔记_\(DateFormatter.compact.string(from: Date())).pdf"
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
            .frame(minWidth: 460, minHeight: 240)
            .background(Theme.bg)
            .task { await loadCover() }
        }

        @ViewBuilder private var coverStatus: some View {
            switch coverState {
            case .idle:
                EmptyView()
            case .loading:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("正在下载并压缩封面…")
                        .font(Theme.body(10))
                        .foregroundStyle(Theme.inkSecondary)
                }
            case .embedded:
                Label("封面已内嵌为 data URI", systemImage: "photo.badge.checkmark")
                    .font(Theme.body(10))
                    .foregroundStyle(Theme.success)
            case .placeholder:
                Label("未获取到封面，将使用带标注的排版占位图", systemImage: "photo")
                    .font(Theme.body(10))
                    .foregroundStyle(Theme.inkSecondary)
            }
        }

        private func loadCover() async {
            guard !book.cover.isEmpty else {
                coverState = .placeholder
                return
            }
            coverState = .loading
            cover = await ReportCoverLoader.load(urlString: book.cover)
            coverState = cover == nil ? .placeholder : .embedded
        }

        private func sanitize(_ text: String) -> String {
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "\u{4E00}-\u{9FFF}"))
            return text.map { scalar in
                scalar.unicodeScalars.allSatisfy(allowed.contains) ? String(scalar) : "_"
            }.joined().prefix(30).description
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
