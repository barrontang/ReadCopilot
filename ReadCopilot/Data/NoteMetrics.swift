import Foundation

// MARK: - 笔记证据层
//
// 这里移植 reading-notes 技能的 build_brief.py：所有计数、比率、字数分档、
// 等级和证据排序都在本地确定性计算。LLM 只负责解释这些数字，不得重算或编造。
// 指标口径（必须随报告一起披露）：
// - ideaDepthMix 是字数分档，不是语义分类；
// - reflection/action/question 是固定关键词命中，不是推理率或实践率；
// - 两个中位数是两组非配对分布；
// - 章节密度只表示笔记覆盖，不代表读者读完或跳过了某章。

struct NoteBrief: Identifiable {
    let id: String
    let bookID: String
    let bookTitle: String
    let author: String
    let category: String

    let counts: NoteCounts
    let ratios: NoteRatios
    let chapters: [ChapterDensity]
    let untouchedChapters: [String]
    let bursts: [BurstDay]
    let dateSpan: DateSpan?
    let ideaMedianChars: Int
    let underlineMedianChars: Int

    let grade: NoteGrade
    let factors: [GradeFactor]
    let diagnoses: [String]
    let evidence: [RankedEvidence]
    let reactions: [RankedEvidence]
    let keywords: [String]
    let prescription: MethodPrescription
    let citationIDs: [String: String]
    let generatedAt: Date
}

struct NoteCounts: Hashable {
    let underlines: Int
    let ideas: Int
    let notes: Int
    let chaptersTotal: Int
    let chaptersWithNotes: Int
}

struct NoteRatios: Hashable {
    let ideaRate: Double
    let ideaDepthMix: DepthMix
    let reflectionDensity: Double
    let actionRate: Double
    let questionRate: Double
    let firstPersonRate: Double
    let linkedRate: Double
    let orphanRate: Double
    let topChapterShare: Double
}

struct DepthMix: Hashable {
    let reaction: Double
    let explain: Double
    let extend: Double
    let synthesize: Double
}

struct NoteGrade: Hashable {
    let score: Double
    let level: String
    let verdict: String
}

struct GradeFactor: Identifiable, Hashable {
    var id: String { key }
    let key: String
    let label: String
    let normalized: Double
    let maxPoints: Double
    let display: String
    let rule: String

    var points: Double { normalized * maxPoints }
}

struct ChapterDensity: Identifiable, Hashable {
    var id: String { chapter }
    let chapter: String
    let underlines: Int
    let ideas: Int
    let notes: Int
}

struct BurstDay: Identifiable, Hashable {
    var id: String { date }
    let date: String
    let notes: Int
}

struct DateSpan: Hashable {
    let first: String
    let last: String
    let distinctTimeKeys: Int
}

struct RankedEvidence: Identifiable, Hashable {
    var id: String { citationID }
    let citationID: String
    let kind: ReadingNote.Kind
    let chapter: String
    let sourceText: String
    let noteText: String
    let score: Int

    var displayText: String { noteText.isEmpty ? sourceText : noteText }
}

struct SharedTheme: Identifiable, Hashable {
    var id: String { keyword }
    let keyword: String
    let bookTitles: [String]
}

enum NoteMetrics {
    // MARK: 关键词表（与 build_brief.py 一致）

    private static let connectives = [
        "因为", "所以", "但是", "然而", "如果", "否则", "对比", "相反", "意味着",
        "因此", "换句话说", "本质", "前提", "边界", "反而", "与其"
    ]
    private static let actions = [
        "我要", "下次", "试试", "落地", "执行", "改成", "开始", "停止", "先", "可以"
    ]
    private static let questions = ["为什么", "如何", "是否", "?", "？"]
    private static let firstPerson = ["我", "我们", "自己", "我的"]

    private static let stopwords: Set<String> = Set("""
    的 了 是 在 我 有 和 就 不 人 都 一 一个 上 也 很 到 说 要 我们 你 他 她 它 这 那
    而 与 及 或 但 被 把 对 从 为 以 之 其 于 着 过 得 地 里 中 下 又 再 更 最 还 会 能 可 可以
    自己 没有 因为 所以 如果 就是 这样 那样 这个 那个 什么 怎么 如何 不是 只是 已经 或者 然后
    the a an and or but if then that this these those of to in on for with is are was were be
    been being it its as at by from not no you your we our they their he she his her
    """.split(separator: " ").map(String.init))

    private static let tokenRegex = try! NSRegularExpression(
        pattern: "[A-Za-z]{3,}|[\\u4e00-\\u9fa5]+"
    )

    // MARK: 主入口

    static func compute(
        notes: [ReadingNote],
        book: LibraryBook,
        chapterTitles: [String] = [],
        idPrefix: String = ""
    ) -> NoteBrief {
        let highlights = notes.filter { $0.kind == .highlight }
        let ideas = notes.filter { $0.kind == .thought }

        var citationIDs: [String: String] = [:]
        for (index, note) in highlights.enumerated() {
            citationIDs[note.id] = citation(prefix: idPrefix, kind: "U", index: index + 1)
        }
        for (index, note) in ideas.enumerated() {
            citationIDs[note.id] = citation(prefix: idPrefix, kind: "R", index: index + 1)
        }

        let ideaTotal = max(ideas.count, 1)
        var bucketCounts = [0, 0, 0, 0]
        for note in ideas {
            bucketCounts[bucketIndex(note.noteText.count)] += 1
        }
        let mix = DepthMix(
            reaction: round2(Double(bucketCounts[0]) / Double(ideaTotal)),
            explain: round2(Double(bucketCounts[1]) / Double(ideaTotal)),
            extend: round2(Double(bucketCounts[2]) / Double(ideaTotal)),
            synthesize: round2(Double(bucketCounts[3]) / Double(ideaTotal))
        )

        let linked = ideas.filter(isLinked).count
        let orphan = ideas.filter { note in
            !isLinked(note) && (note.sourceText.isEmpty || note.sourceText == "（无对应原文）")
        }.count

        let chapterCounts = chapterDensities(highlights: highlights, ideas: ideas)
        let totalNotes = max(chapterCounts.reduce(0) { $0 + $1.notes }, 1)
        let topShare = round2(Double(chapterCounts.first?.notes ?? 0) / Double(totalNotes))
        let untouched = chapterTitles.filter { title in
            !title.isEmpty && !chapterCounts.contains { $0.chapter == title }
        }

        let dayStats = dayStatistics(notes: notes)
        let ideaMedian = median(ideas.map { $0.noteText.count })
        let underlineMedian = median(highlights.map { $0.sourceText.count })

        let counts = NoteCounts(
            underlines: highlights.count,
            ideas: ideas.count,
            notes: highlights.count + ideas.count,
            chaptersTotal: max(chapterTitles.count, chapterCounts.count),
            chaptersWithNotes: chapterCounts.count
        )
        let ratios = NoteRatios(
            ideaRate: round2(Double(ideas.count) / Double(max(highlights.count, 1))),
            ideaDepthMix: mix,
            reflectionDensity: round2(Double(ideas.filter { containsAny($0.noteText, connectives) }.count) / Double(ideaTotal)),
            actionRate: round2(Double(ideas.filter { containsAny($0.noteText, actions) }.count) / Double(ideaTotal)),
            questionRate: round2(Double(ideas.filter { containsAny($0.noteText, questions) }.count) / Double(ideaTotal)),
            firstPersonRate: round2(Double(ideas.filter { containsAny($0.noteText, firstPerson) }.count) / Double(ideaTotal)),
            linkedRate: round2(Double(linked) / Double(ideaTotal)),
            orphanRate: round2(Double(orphan) / Double(ideaTotal)),
            topChapterShare: topShare
        )

        let gradeResult = evaluateGrade(ratios: ratios, counts: counts)
        let rankedIdeas = ideas
            .map { note in
                RankedEvidence(
                    citationID: citationIDs[note.id] ?? "R---",
                    kind: .thought,
                    chapter: note.chapter,
                    sourceText: note.sourceText,
                    noteText: note.noteText,
                    score: scoreIdea(note.noteText)
                )
            }
            .sorted { $0.score > $1.score }

        // 纯划线笔记本没有想法：用最长划线作为代表性证据，而不是伪造想法。
        let rankedHighlights = highlights
            .map { note in
                RankedEvidence(
                    citationID: citationIDs[note.id] ?? "U---",
                    kind: .highlight,
                    chapter: note.chapter,
                    sourceText: note.sourceText,
                    noteText: "",
                    score: scoreIdea(note.sourceText)
                )
            }
            .sorted { $0.score > $1.score }

        let evidence = Array((rankedIdeas.isEmpty ? rankedHighlights : rankedIdeas).prefix(8))
        let reactions = ideas
            .filter { $0.noteText.count <= 15 }
            .prefix(6)
            .map { note in
                RankedEvidence(
                    citationID: citationIDs[note.id] ?? "R---",
                    kind: .thought,
                    chapter: note.chapter,
                    sourceText: note.sourceText,
                    noteText: note.noteText,
                    score: scoreIdea(note.noteText)
                )
            }

        let keywords = keywords(from: notes, limit: 25)
        let prescription = MethodAdvisor.prescribe(
            MethodSignals(
                ideaRate: ratios.ideaRate,
                reactionShare: mix.reaction,
                synthesizeShare: mix.synthesize,
                reflectionDensity: ratios.reflectionDensity,
                actionRate: ratios.actionRate,
                questionRate: ratios.questionRate,
                linkedRate: ratios.linkedRate,
                topChapterShare: ratios.topChapterShare,
                untouchedCount: untouched.count,
                ideaCount: ideas.count,
                bookCount: 1,
                sharedThemeCount: 0
            )
        )

        return NoteBrief(
            id: book.id,
            bookID: book.id,
            bookTitle: book.title,
            author: book.author,
            category: book.category,
            counts: counts,
            ratios: ratios,
            chapters: chapterCounts,
            untouchedChapters: untouched,
            bursts: dayStats.bursts,
            dateSpan: dayStats.span,
            ideaMedianChars: ideaMedian,
            underlineMedianChars: underlineMedian,
            grade: gradeResult.grade,
            factors: gradeResult.factors,
            diagnoses: diagnoses(ratios: ratios, counts: counts),
            evidence: evidence,
            reactions: reactions,
            keywords: keywords,
            prescription: prescription,
            citationIDs: citationIDs,
            generatedAt: Date()
        )
    }

    // MARK: 等级（七因子，与 analysis.md §3 一致）

    static func evaluateGrade(ratios: NoteRatios, counts: NoteCounts) -> (grade: NoteGrade, factors: [GradeFactor]) {
        let mix = ratios.ideaDepthMix
        let ideaNorm = min(ratios.ideaRate, 1.0)
        let depthRaw = (mix.extend + 2 * mix.synthesize) / 2
        let depthNorm = min(depthRaw, 1.0)
        let reflectionNorm = min(ratios.reflectionDensity, 0.6) / 0.6
        let actionNorm = min(ratios.actionRate, 0.4) / 0.4
        let questionNorm = min(ratios.questionRate, 0.3) / 0.3
        let linkedNorm = min(ratios.linkedRate, 1.0)
        let spreadNorm = 1 - min(ratios.topChapterShare, 1.0)

        let score = round1(
            ideaNorm * 18
            + depthNorm * 22
            + reflectionNorm * 20
            + actionNorm * 15
            + questionNorm * 10
            + linkedNorm * 8
            + spreadNorm * 7
        )

        let level: String
        let verdict: String
        if score >= 75 {
            level = "A"
            verdict = "已形成可复用的个人观点，下一步是体系化整理。"
        } else if score >= 55 {
            level = "B"
            verdict = "有思考，但多停在解释层，较少转化为判断或行动。"
        } else if score >= 35 {
            level = "C"
            verdict = "以划线为主，想法少而短；阅读留下了痕迹，但还没有形成观点。"
        } else {
            level = "D"
            verdict = "接近纯划线；笔记本尚未承担思考功能。"
        }

        let factors = [
            GradeFactor(
                key: "idea", label: "想法率", normalized: ideaNorm, maxPoints: 18,
                display: String(format: "%.2f", ratios.ideaRate),
                rule: "想法数 ÷ 划线条数，封顶 1.0"
            ),
            GradeFactor(
                key: "depth", label: "想法深度", normalized: depthNorm, maxPoints: 22,
                display: "extend \(percent(mix.extend))% · synth \(percent(mix.synthesize))%",
                rule: "(extend 1× + synthesize 2×) ÷ 2，封顶 1.0"
            ),
            GradeFactor(
                key: "reflection", label: "反思密度", normalized: reflectionNorm, maxPoints: 20,
                display: "\(percent(ratios.reflectionDensity))%",
                rule: "因果/转折连接词命中；达到 60% 即满分"
            ),
            GradeFactor(
                key: "action", label: "行动标记", normalized: actionNorm, maxPoints: 15,
                display: "\(percent(ratios.actionRate))%",
                rule: "行动关键词命中；达到 40% 即满分"
            ),
            GradeFactor(
                key: "question", label: "提问率", normalized: questionNorm, maxPoints: 10,
                display: "\(percent(ratios.questionRate))%",
                rule: "问句关键词命中；达到 30% 即满分"
            ),
            GradeFactor(
                key: "linked", label: "可追溯", normalized: linkedNorm, maxPoints: 8,
                display: "\(percent(ratios.linkedRate))%",
                rule: "想法能追溯到具体划线的比例"
            ),
            GradeFactor(
                key: "spread", label: "章节分散", normalized: spreadNorm, maxPoints: 7,
                display: "1 − \(percent(ratios.topChapterShare))%",
                rule: "1 − 最集中章节占比；越分散得分越高"
            )
        ]

        return (NoteGrade(score: score, level: level, verdict: verdict), factors)
    }

    // MARK: 自动诊断（只陈述代理指标，不评价人格）

    static func diagnoses(ratios: NoteRatios, counts: NoteCounts) -> [String] {
        var out: [String] = []
        let mix = ratios.ideaDepthMix

        if counts.ideas == 0 {
            out.append("只有划线、没有想法（想法/划线=0）：信息进入了笔记本，但没有用自己的话重写。")
            return out
        }
        if ratios.ideaRate < 0.25 {
            out.append("划线多、想法少（想法/划线=\(String(format: "%.2f", ratios.ideaRate))）：信息进入了笔记本，但没有用自己的话重写。")
        } else if ratios.ideaRate > 1.2 {
            out.append("想法密度很高（想法/划线=\(String(format: "%.2f", ratios.ideaRate))）：思考活跃，但文本可能正在失去锚点。")
        }
        if mix.reaction >= 0.4 {
            out.append("\(percent(mix.reaction))% 的想法是 15 字以内的短反应（按字数分档）：有判断，缺证据。")
        }
        if mix.synthesize <= 0.01 {
            out.append("没有超过 120 字的想法：这本书还没有被用自己的框架重新讲一遍。")
        }
        if ratios.reflectionDensity < 0.3 {
            out.append("只有 \(percent(ratios.reflectionDensity))% 的想法出现因果/转折连接词（关键词命中口径）：多为复述，推理痕迹少。")
        }
        if ratios.actionRate < 0.15 {
            out.append("只有 \(percent(ratios.actionRate))% 的想法出现行动标记（关键词命中口径）：读到了，但没有写下要改变什么。")
        }
        if ratios.linkedRate < 0.5 && counts.ideas >= 5 {
            out.append("只有 \(percent(ratios.linkedRate))% 的想法能追溯到具体划线：主张与文本的链接偏弱。")
        }
        if ratios.topChapterShare >= 0.5 && counts.chaptersWithNotes > 2 {
            out.append("\(percent(ratios.topChapterShare))% 的笔记集中在单一章节：注意力分布高度倾斜。")
        }
        if out.isEmpty {
            out.append("各项代理指标未见明显短板；下一步重点是把笔记转成可复用的输出。")
        }
        return out
    }

    // MARK: 跨书共同主题

    static func sharedThemes(briefs: [NoteBrief]) -> [SharedTheme] {
        guard briefs.count > 1 else { return [] }
        var map: [String: Set<String>] = [:]
        for brief in briefs {
            for keyword in brief.keywords {
                map[keyword, default: []].insert(brief.bookTitle)
            }
        }
        return map
            .filter { $0.value.count >= 2 }
            .map { SharedTheme(keyword: $0.key, bookTitles: $0.value.sorted()) }
            .sorted {
                if $0.bookTitles.count != $1.bookTitles.count {
                    return $0.bookTitles.count > $1.bookTitles.count
                }
                return $0.keyword < $1.keyword
            }
            .prefix(15)
            .map { $0 }
    }

    // MARK: - 内部计算

    private static func citation(prefix: String, kind: String, index: Int) -> String {
        "\(prefix)\(kind)\(String(format: "%03d", index))"
    }

    private static func bucketIndex(_ length: Int) -> Int {
        if length < 15 { return 0 }
        if length < 40 { return 1 }
        if length < 120 { return 2 }
        return 3
    }

    private static func isLinked(_ note: ReadingNote) -> Bool {
        if let quote = note.quoteID, !quote.isEmpty { return true }
        let source = note.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !source.isEmpty && source != "（无对应原文）"
    }

    private static func chapterDensities(highlights: [ReadingNote], ideas: [ReadingNote]) -> [ChapterDensity] {
        struct Counts {
            var underlines = 0
            var ideas = 0
        }
        var map: [String: Counts] = [:]
        for note in highlights {
            let chapter = note.chapter.isEmpty ? "未标注章节" : note.chapter
            map[chapter, default: Counts()].underlines += 1
        }
        for note in ideas {
            let chapter = note.chapter.isEmpty ? "未标注章节" : note.chapter
            map[chapter, default: Counts()].ideas += 1
        }
        return map.map { chapter, counts in
            ChapterDensity(
                chapter: chapter,
                underlines: counts.underlines,
                ideas: counts.ideas,
                notes: counts.underlines + counts.ideas
            )
        }
        .sorted {
            if $0.notes != $1.notes { return $0.notes > $1.notes }
            return $0.chapter < $1.chapter
        }
    }

    private static func dayStatistics(notes: [ReadingNote]) -> (span: DateSpan?, bursts: [BurstDay]) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        var byDay: [String: Int] = [:]
        for note in notes where note.createdAt > 0 {
            let date = Date(timeIntervalSince1970: TimeInterval(note.createdAt))
            byDay[formatter.string(from: date), default: 0] += 1
        }
        let ordered = byDay.sorted { $0.key < $1.key }
        guard !ordered.isEmpty else { return (nil, []) }
        let span = DateSpan(
            first: ordered.first!.key,
            last: ordered.last!.key,
            distinctTimeKeys: ordered.count
        )
        var bursts: [BurstDay] = []
        for (index, item) in ordered.enumerated() {
            let previous = index > 0 ? ordered[index - 1].value : 0
            if item.value >= 3 && item.value >= previous * 2 {
                bursts.append(BurstDay(date: item.key, notes: item.value))
            }
        }
        return (span, bursts)
    }

    private static func median(_ values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return Int((Double(sorted[mid - 1] + sorted[mid]) / 2).rounded(.down))
        }
        return sorted[mid]
    }

    private static func containsAny(_ text: String, _ pool: [String]) -> Bool {
        pool.contains { text.contains($0) }
    }

    private static func countAny(_ text: String, _ pool: [String]) -> Int {
        pool.reduce(0) { $0 + (text.contains($1) ? 1 : 0) }
    }

    private static func scoreIdea(_ text: String) -> Int {
        var score = 0
        let length = text.count
        if (30...220).contains(length) { score += 6 }
        score += 3 * min(countAny(text, connectives), 2)
        if countAny(text, firstPerson) > 0 { score += 2 }
        if countAny(text, actions) > 0 { score += 2 }
        if countAny(text, questions) > 0 { score += 3 }
        if text.rangeOfCharacter(from: .decimalDigits) != nil { score += 2 }
        if length < 12 { score -= 4 }
        return score
    }

    private static func keywords(from notes: [ReadingNote], limit: Int) -> [String] {
        var frequency: [String: Int] = [:]
        for note in notes {
            for text in [note.sourceText, note.noteText] {
                for token in tokens(text) {
                    frequency[token, default: 0] += 1
                }
            }
        }
        return frequency
            .filter { $0.value >= 2 }
            .sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                return $0.key < $1.key
            }
            .prefix(limit)
            .map { $0.key }
    }

    private static func tokens(_ text: String) -> [String] {
        let nsText = text as NSString
        let matches = tokenRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        var out: [String] = []
        for match in matches {
            let chunk = nsText.substring(with: match.range)
            guard let first = chunk.unicodeScalars.first else { continue }
            if (0x4E00...0x9FFF).contains(first.value) {
                let characters = Array(chunk)
                guard characters.count >= 2 else { continue }
                for index in 0..<(characters.count - 1) {
                    let gram = String(characters[index...index + 1])
                    if !stopwords.contains(gram) { out.append(gram) }
                }
            } else {
                let word = chunk.lowercased()
                if !stopwords.contains(word) { out.append(word) }
            }
        }
        return out
    }

    private static func percent(_ value: Double) -> Int {
        Int((value * 100).rounded(.down))
    }

    private static func round2(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    private static func round1(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}
