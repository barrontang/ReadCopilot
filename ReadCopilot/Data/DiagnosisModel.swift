import Foundation
import UserNotifications

// MARK: - 诊断会话仓库
// 职责：按分析目标（范围+书籍+模板）持有对应的 DiagnosisModel 实例，
// 使其生命周期与 App 根视图绑定，而不依赖某个子视图是否在屏幕上。
// 这样用户切到其他 Tab/导航项后，后台分析任务与进度不会被销毁，
// 待分析完成后回到 Copilot 页依然能看到结果（并已发出本地通知）。
// 同时维护「已分析工作列表」，供用户随时查看所有分析任务的状态并跳转查看。
@MainActor
final class DiagnosisSessionStore: ObservableObject {
    /// 一项分析工作的元信息，用于在「已分析工作列表」中展示与重新定位。
    struct Job: Identifiable {
        let id: String
        let scope: AnalysisScope
        let selectedCategory: String
        let books: [LibraryBook]
        let template: AnalysisTemplate
        let createdAt: Date

        var title: String {
            if books.count == 1, let book = books.first {
                return "《\(book.title)》"
            }
            return "\(books.count) 本书"
        }
    }

    @Published private(set) var jobs: [Job] = []
    private var models: [String: DiagnosisModel] = [:]

    /// 获取（或创建）某个分析目标对应的 DiagnosisModel。
    /// key 由调用方基于范围/书籍集合/模板拼出，保证同一目标复用同一实例。
    func model(for key: String) -> DiagnosisModel {
        if let existing = models[key] {
            return existing
        }
        let created = DiagnosisModel()
        models[key] = created
        return created
    }

    /// 已存在的 model（不创建新实例），用于列表展示时只读取状态。
    func existingModel(for key: String) -> DiagnosisModel? {
        models[key]
    }

    /// 用户实际点击「开始分析」时登记一项工作，使其出现在「已分析工作列表」中。
    /// 若同一 key 已登记过（比如重试），仅更新排序时间到最新，不产生重复条目。
    func registerJob(
        key: String,
        scope: AnalysisScope,
        selectedCategory: String,
        books: [LibraryBook],
        template: AnalysisTemplate
    ) {
        jobs.removeAll { $0.id == key }
        jobs.insert(
            Job(
                id: key,
                scope: scope,
                selectedCategory: selectedCategory,
                books: books,
                template: template,
                createdAt: Date()
            ),
            at: 0
        )
    }

    /// 当前是否存在仍在后台运行（获取笔记中/生成中）的分析工作。
    var hasRunningJobs: Bool {
        jobs.contains { job in
            guard let model = models[job.id] else { return false }
            switch model.state {
            case .fetchingNotes, .generating: return true
            default: return false
            }
        }
    }

    var runningJobCount: Int {
        jobs.filter { job in
            guard let model = models[job.id] else { return false }
            switch model.state {
            case .fetchingNotes, .generating: return true
            default: return false
            }
        }.count
    }
}

// MARK: - 诊断编排器
// 职责：状态机 + 进度发布 + 完成通知。
// 取数解析在 WeReadNotesService，Prompt/LLM 在 AnalysisService。

@MainActor
final class DiagnosisModel: ObservableObject {
    @Published var state: State = .idle
    @Published var report: String = ""
    @Published var notes: [ReadingNote] = []
    @Published var completedBooks = 0
    @Published var totalBooks = 0

    enum State: Equatable {
        case idle
        case fetchingNotes
        case generating
        case done
        case failed(String)
    }

    private let notesService: WeReadNotesService
    private let analysisService: AnalysisService

    init(
        notesService: WeReadNotesService = WeReadNotesService(),
        analysisService: AnalysisService = AnalysisService()
    ) {
        self.notesService = notesService
        self.analysisService = analysisService
    }

    // MARK: 主入口 — 后台运行，UI 不需要等待
    /// 启动单书分析流程，会立即切换到加载状态并在后台继续执行。
    func run(book: LibraryBook, template: AnalysisTemplate = .coach) {
        run(books: [book], template: template)
    }

    /// 启动多书分析流程，按顺序抓取笔记后统一请求 LLM 生成报告。
    func run(books: [LibraryBook], template: AnalysisTemplate) {
        report = ""
        notes = []
        completedBooks = 0
        totalBooks = books.count
        state = .fetchingNotes

        // 在独立 Task 里跑，调用方无需 await — 用户可随时切走
        Task {
            await diagnose(books: books, template: template)
        }
    }

    /// 单书全量笔记（供导出/导入知识库直接调用）
    func collectNotes(for book: LibraryBook) async throws -> [ReadingNote] {
        try await notesService.fetchAllNotes(for: book)
    }

    // MARK: 实际异步执行（@MainActor 保证 Published 在主线程更新）
    private func diagnose(books: [LibraryBook], template: AnalysisTemplate) async {
        guard !books.isEmpty else {
            state = .failed("请选择至少一本书。")
            return
        }
        do {
            var collected: [ReadingNote] = []
            for book in books {
                collected.append(contentsOf: try await notesService.fetchAllNotes(for: book))
                completedBooks += 1
            }
            notes = collected

            guard !collected.isEmpty else {
                let msg = "所选范围内暂无划线或想法记录，无法生成分析。"
                state = .failed(msg)
                await notify(title: "分析失败", body: msg, isError: true)
                return
            }

            state = .generating
            let result = try await analysisService.analyze(
                books: books,
                notes: collected,
                template: template
            )
            report = result
            state = .done

            await notify(
                title: "阅读分析完成",
                body: AnalysisService.extractOneLiner(from: result)
                    ?? "\(books.count) 本书的分析报告已生成，点击查看。"
            )
        } catch {
            let msg = error.localizedDescription
            state = .failed(msg)
            await notify(title: "阅读分析失败", body: msg, isError: true)
        }
    }

    // MARK: 发本地通知
    private func notify(title: String, body: String, isError: Bool = false) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = isError ? .defaultCritical : .default

        let req = UNNotificationRequest(
            identifier: "diagnosis-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await center.add(req)
    }
}
