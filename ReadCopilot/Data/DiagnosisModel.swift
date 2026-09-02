import Foundation
import UserNotifications

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
    func run(book: LibraryBook, template: AnalysisTemplate = .coach) {
        run(books: [book], template: template)
    }

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
