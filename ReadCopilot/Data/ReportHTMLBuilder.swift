import Foundation

// MARK: - 单文件 HTML 报告
//
// 约定（来自 reading-notes/references/html-report.md）：
// - 一个自包含 .html：内联 CSS，图片只允许 data: URI 或内联 SVG；
// - 照片优先：真实封面（下载后嵌入）或明确标注的排版占位图；
// - Apple 风格 + 高信息密度：等级、KPI、因子条在首屏；
// - 压缩布局，不删除引用、指标口径、A2 或待补录。

struct ReportCover {
    let data: Data
    let mimeType: String
    let source: String
}

enum ReportHTMLBuilder {
    // MARK: 分析报告

    static func report(
        title: String,
        author: String,
        templateName: String,
        report: String,
        briefs: [NoteBrief],
        cover: ReportCover?
    ) -> String {
        let isMulti = briefs.count > 1
        let primary = briefs.first
        let reportHTML = renderMarkdown(report)

        let heroTitle: String
        let heroSub: String
        if isMulti {
            heroTitle = "\(briefs.count) 本书 · \(templateName)"
            heroSub = briefs.map(\.bookTitle).prefix(4).map { "《\($0)》" }.joined(separator: "、")
        } else {
            heroTitle = "《\(title)》"
            heroSub = author.isEmpty ? templateName : "\(author) · \(templateName)"
        }

        let gradeHTML: String
        if let primary, !isMulti {
            gradeHTML = """
            <div class="grade grade-\(esc(primary.grade.level))"><b>\(esc(primary.grade.level))</b><span>\(String(format: "%.1f", primary.grade.score))/100</span></div>
            <p class="verdict">\(esc(primary.grade.verdict))</p>
            """
        } else if isMulti {
            gradeHTML = """
            <div class="grade"><b>\(briefs.count)</b><span>本书对比</span></div>
            <p class="verdict">先看对比表，再看共同主题；单书等级只解释该书笔记，不跨书平均。</p>
            """
        } else {
            gradeHTML = """
            <div class="grade"><b>方法</b><span>咨询</span></div>
            <p class="verdict">本次未提供笔记，以下建议只依据书名、类别与阅读目的，不对书的内容或读者笔记作事实判断。</p>
            """
        }

        let coverHTML = isMulti
            ? coverStrip(briefs)
            : coverBlock(cover: cover, title: title, author: author, width: 180)

        let kpiHTML = briefs.isEmpty
            ? ""
            : (isMulti ? kpiStrip(aggregateKPIs(briefs)) : kpiStrip(kpis(primary)))

        let factorsHTML: String
        if let primary, !isMulti {
            factorsHTML = """
            <section class="card">
              <div class="section-head"><h2>七因子</h2><span class="sub">等级只由这七项决定 · 方法与评分解耦</span></div>
              \(primary.factors.map(factorBar).joined(separator: "\n"))
            </section>
            """
        } else {
            factorsHTML = ""
        }

        let comparisonHTML = isMulti
            ? comparisonTable(briefs)
            : ""

        let footerNotes = briefs.isEmpty
            ? "本次未计算笔记指标。"
            : "指标口径：ideaDepthMix 为字数分档（<15 / 15–39 / 40–119 / ≥120 字）；reflection / action / question 为关键词命中；两个中位数非配对；章节密度仅表示笔记覆盖，不代表读完或跳过。"

        let coverCaption = cover?.source ?? "封面占位图（未获取到封面，示例排版，非真实照片）"

        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(esc(heroTitle)) · \(esc(templateName))</title>
        <style>
        \(css)
        </style>
        </head>
        <body>
        <div class="wrap">
          <header class="hero card">
            \(coverHTML)
            <div class="hero-copy">
              <div class="eyebrow">微信读书 · \(esc(templateName))</div>
              <h1>\(esc(heroTitle))</h1>
              <div class="sub">\(esc(heroSub))</div>
              \(gradeHTML)
              \(kpiHTML)
            </div>
          </header>

          \(factorsHTML)
          \(comparisonHTML)

          <section class="card report">
            \(reportHTML)
          </section>

          <footer>
            <div>数据来源：微信读书划线与想法（本地同步） · 本地指标由 ReadCopilot NoteMetrics 计算 · 报告由「\(esc(templateName))」模板生成</div>
            <div>\(esc(footerNotes))</div>
            <div>封面：\(esc(coverCaption)) · 生成时间：\(esc(timestamp()))</div>
            <div>本文件为单文件离线报告：内联 CSS，无外部脚本、字体或远程图片。</div>
          </footer>
        </div>
        </body>
        </html>
        """
    }

    // MARK: 划线整理本（本地生成，不调用 LLM）

    static func notesBook(book: LibraryBook, notes: [ReadingNote], cover: ReportCover?) -> String {
        var groups: [(chapter: String, notes: [ReadingNote])] = []
        var indexByChapter: [String: Int] = [:]
        for note in notes {
            let chapter = note.chapter.isEmpty ? "未标注章节" : note.chapter
            if let index = indexByChapter[chapter] {
                groups[index].notes.append(note)
            } else {
                indexByChapter[chapter] = groups.count
                groups.append((chapter, [note]))
            }
        }

        var highlightIndex = 0
        var thoughtIndex = 0
        var sectionsHTML: [String] = []
        for group in groups {
            var entries: [String] = []
            for note in group.notes {
                if note.kind == .highlight {
                    highlightIndex += 1
                    entries.append("""
                    <div class="entry">
                      <div class="entry-head"><span class="tag">划线 U\(String(format: "%03d", highlightIndex))</span></div>
                      <blockquote>\(inline(note.sourceText))</blockquote>
                    </div>
                    """)
                } else {
                    thoughtIndex += 1
                    let source = note.sourceText.isEmpty || note.sourceText == "（无对应原文）"
                        ? ""
                        : "<div class=\"quote\">「\(inline(note.sourceText))」</div>"
                    entries.append("""
                    <div class="entry thought">
                      <div class="entry-head"><span class="tag tag-thought">想法 R\(String(format: "%03d", thoughtIndex))</span></div>
                      \(source)
                      <p class="note-text">\(inline(note.noteText))</p>
                    </div>
                    """)
                }
            }
            sectionsHTML.append("""
            <section class="card">
              <div class="section-head"><h2>\(esc(group.chapter))</h2><span class="sub">\(group.notes.count) 条</span></div>
              \(entries.joined(separator: "\n"))
            </section>
            """)
        }

        let toc = groups.map { group in
            "<li><span>\(esc(group.chapter))</span><span class=\"num\">\(group.notes.count)</span></li>"
        }.joined(separator: "\n")

        let coverHTML = coverBlock(cover: cover, title: book.title, author: book.author, width: 130)

        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>《\(esc(book.title))》· 划线整理本</title>
        <style>
        \(css)
        </style>
        </head>
        <body>
        <div class="wrap">
          <header class="hero card compact">
            \(coverHTML)
            <div class="hero-copy">
              <div class="eyebrow">微信读书 · 划线整理本</div>
              <h1>《\(esc(book.title))》</h1>
              <div class="sub">\(esc(book.author.isEmpty ? "作者未知" : book.author)) · \(notes.count) 条记录</div>
              <p class="verdict">按章节与记录顺序整理；原文保持原样，未调用 LLM，不含解释或评价。</p>
              <div class="kpis">
                \(kpi("划线", "\(notes.filter { $0.kind == .highlight }.count)"))
                \(kpi("想法", "\(notes.filter { $0.kind == .thought }.count)"))
                \(kpi("章节", "\(groups.count)"))
                \(kpi("格式", "单文件"))
              </div>
            </div>
          </header>

          <section class="card">
            <div class="section-head"><h2>目录</h2><span class="sub">按出现顺序</span></div>
            <ul class="toc">\(toc)</ul>
          </section>

          \(sectionsHTML.joined(separator: "\n"))

          <footer>
            <div>数据来源：微信读书划线与想法（本地同步） · 本地生成，未调用 LLM</div>
            <div>封面：\(esc(cover?.source ?? "封面占位图（未获取到封面，示例排版，非真实照片）")) · 生成时间：\(esc(timestamp()))</div>
            <div>本文件为单文件离线整理本：内联 CSS，无外部脚本、字体或远程图片。</div>
          </footer>
        </div>
        </body>
        </html>
        """
    }

    // MARK: 首屏组件

    private static func kpis(_ brief: NoteBrief?) -> [(String, String, String)] {
        guard let brief else {
            return [
                ("笔记", "0", "条"),
                ("划线", "0", "条"),
                ("想法", "0", "条"),
                ("章节", "0", "个")
            ]
        }
        return [
            ("笔记", "\(brief.counts.notes)", "条"),
            ("划线", "\(brief.counts.underlines)", "条"),
            ("想法", "\(brief.counts.ideas)", "条"),
            ("想法率", String(format: "%.2f", brief.ratios.ideaRate), "想法/划线"),
            ("章节覆盖", "\(brief.counts.chaptersWithNotes)/\(brief.counts.chaptersTotal)", "有笔记/目录"),
            ("反思密度", "\(percent(brief.ratios.reflectionDensity))%", "关键词命中"),
            ("行动标记", "\(percent(brief.ratios.actionRate))%", "关键词命中"),
            ("可追溯", "\(percent(brief.ratios.linkedRate))%", "想法挂划线")
        ]
    }

    private static func aggregateKPIs(_ briefs: [NoteBrief]) -> [(String, String, String)] {
        let notes = briefs.reduce(0) { $0 + $1.counts.notes }
        let underlines = briefs.reduce(0) { $0 + $1.counts.underlines }
        let ideas = briefs.reduce(0) { $0 + $1.counts.ideas }
        let chapters = briefs.reduce(0) { $0 + $1.counts.chaptersWithNotes }
        let ideaRate = underlines > 0 ? Double(ideas) / Double(underlines) : 0
        let reflection = ideas > 0 ? briefs.reduce(0.0) { $0 + $1.ratios.reflectionDensity * Double($1.counts.ideas) } / Double(ideas) : 0
        let action = ideas > 0 ? briefs.reduce(0.0) { $0 + $1.ratios.actionRate * Double($1.counts.ideas) } / Double(ideas) : 0
        let linked = ideas > 0 ? briefs.reduce(0.0) { $0 + $1.ratios.linkedRate * Double($1.counts.ideas) } / Double(ideas) : 0
        return [
            ("书", "\(briefs.count)", "本"),
            ("笔记", "\(notes)", "条"),
            ("划线", "\(underlines)", "条"),
            ("想法", "\(ideas)", "条"),
            ("想法率", String(format: "%.2f", ideaRate), "加权"),
            ("章节", "\(chapters)", "有笔记"),
            ("反思密度", "\(percent(reflection))%", "加权"),
            ("行动标记", "\(percent(action))%", "加权"),
            ("可追溯", "\(percent(linked))%", "加权")
        ]
    }

    private static func kpiStrip(_ items: [(String, String, String)]) -> String {
        let tiles = items.map { item in
            "<div class=\"kpi\"><span class=\"k\">\(esc(item.0))</span><span class=\"v\">\(esc(item.1))</span><span class=\"n\">\(esc(item.2))</span></div>"
        }.joined(separator: "\n")
        return "<div class=\"kpis\">\(tiles)</div>"
    }

    private static func kpi(_ key: String, _ value: String, _ note: String = "") -> String {
        "<div class=\"kpi\"><span class=\"k\">\(esc(key))</span><span class=\"v\">\(esc(value))</span><span class=\"n\">\(esc(note))</span></div>"
    }

    private static func factorBar(_ factor: GradeFactor) -> String {
        let width = max(2, min(100, factor.normalized * 100))
        return """
        <div class="bar">
          <span class="bar-label">\(esc(factor.label))</span>
          <div class="track"><i style="width:\(String(format: "%.1f", width))%"></i></div>
          <span class="num bar-value">\(esc(factor.display))</span>
          <span class="num bar-points">\(String(format: "%.1f", factor.points))/\(Int(factor.maxPoints))</span>
        </div>
        """
    }

    private static func comparisonTable(_ briefs: [NoteBrief]) -> String {
        let rows = briefs.map { brief in
            """
            <tr>
              <td>《\(esc(brief.bookTitle))》</td>
              <td><span class="grade-mini grade-\(esc(brief.grade.level))">\(esc(brief.grade.level))</span> \(String(format: "%.1f", brief.grade.score))</td>
              <td class="num">\(String(format: "%.2f", brief.ratios.ideaRate))</td>
              <td class="num">\(percent(brief.ratios.reflectionDensity))%</td>
              <td class="num">\(percent(brief.ratios.actionRate))%</td>
              <td class="num">\(percent(brief.ratios.topChapterShare))%</td>
            </tr>
            """
        }.joined(separator: "\n")
        return """
        <section class="card">
          <div class="section-head"><h2>各书本地指标</h2><span class="sub">等级只解释单书笔记，不跨书平均</span></div>
          <div class="scroll">
            <table>
              <caption>跨书对比 · 原始指标</caption>
              <thead><tr><th>书</th><th>等级</th><th>想法率</th><th>反思密度</th><th>行动标记</th><th>章节集中度</th></tr></thead>
              <tbody>\(rows)</tbody>
            </table>
          </div>
        </section>
        """
    }

    private static func coverBlock(cover: ReportCover?, title: String, author: String, width: Int) -> String {
        if let cover {
            return """
            <figure class="cover-fig" style="width:\(width)px">
              <div class="cover"><img src="data:\(cover.mimeType);base64,\(cover.data.base64EncodedString())" alt="《\(esc(title))》封面"></div>
              <figcaption>\(esc(cover.source))</figcaption>
            </figure>
            """
        }
        let authorLine = author.isEmpty ? "" : "<small>\(esc(author))</small>"
        return """
        <figure class="cover-fig" style="width:\(width)px">
          <div class="cover cover-ph"><span>\(esc(title))</span>\(authorLine)<small>封面占位图<br>未获取到封面，示例排版，非真实照片</small></div>
          <figcaption>封面占位图（未获取到封面）</figcaption>
        </figure>
        """
    }

    private static func coverStrip(_ briefs: [NoteBrief]) -> String {
        let tiles = briefs.prefix(8).map { brief in
            """
            <figure class="mini">
              <div class="cover cover-ph mini-cover"><span>\(esc(brief.bookTitle))</span></div>
              <figcaption>占位图</figcaption>
            </figure>
            """
        }.joined(separator: "\n")
        return "<div class=\"cover-strip-wrap\"><div class=\"cover-strip\">\(tiles)</div><div class=\"sub\">多书报告使用排版占位图；未获取到各书封面。</div></div>"
    }

    // MARK: Markdown → HTML

    static func renderMarkdown(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        var html: [String] = []
        var index = 0

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                index += 1
                continue
            }
            if line.hasPrefix("### ") {
                html.append("<h3>\(inline(String(line.dropFirst(4))))</h3>")
                index += 1
                continue
            }
            if line.hasPrefix("## ") {
                html.append("<h2>\(inline(String(line.dropFirst(3))))</h2>")
                index += 1
                continue
            }
            if line.hasPrefix("# ") {
                html.append("<h2>\(inline(String(line.dropFirst(2))))</h2>")
                index += 1
                continue
            }
            if line.hasPrefix("|") {
                var tableLines: [String] = []
                while index < lines.count, lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    tableLines.append(lines[index].trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                html.append(renderTable(tableLines))
                continue
            }
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                var items: [String] = []
                while index < lines.count {
                    let item = lines[index].trimmingCharacters(in: .whitespaces)
                    guard item.hasPrefix("- ") || item.hasPrefix("* ") else { break }
                    items.append(String(item.dropFirst(2)))
                    index += 1
                }
                html.append("<ul>" + items.map { "<li>\(inline($0))</li>" }.joined() + "</ul>")
                continue
            }
            if line.hasPrefix("> ") {
                var quotes: [String] = []
                while index < lines.count {
                    let item = lines[index].trimmingCharacters(in: .whitespaces)
                    guard item.hasPrefix("> ") else { break }
                    quotes.append(String(item.dropFirst(2)))
                    index += 1
                }
                html.append("<blockquote>\(inline(quotes.joined(separator: " ")))</blockquote>")
                continue
            }
            if line == "---" {
                html.append("<hr>")
                index += 1
                continue
            }

            var paragraph: [String] = []
            while index < lines.count {
                let item = lines[index].trimmingCharacters(in: .whitespaces)
                if item.isEmpty || item.hasPrefix("#") || item.hasPrefix("|")
                    || item.hasPrefix("- ") || item.hasPrefix("* ")
                    || item.hasPrefix("> ") || item == "---" {
                    break
                }
                paragraph.append(item)
                index += 1
            }
            if !paragraph.isEmpty {
                html.append("<p>\(inline(paragraph.joined(separator: " ")))</p>")
            }
        }

        return html.joined(separator: "\n")
    }

    private static func renderTable(_ lines: [String]) -> String {
        let rows = lines.map { line -> [String] in
            var text = line
            if text.hasPrefix("|") { text.removeFirst() }
            if text.hasSuffix("|") { text.removeLast() }
            return text.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
        }
        guard let header = rows.first else { return "" }
        let body = rows.dropFirst().filter { row in
            !row.allSatisfy { cell in
                !cell.isEmpty && cell.allSatisfy { $0 == "-" || $0 == ":" || $0 == " " }
            }
        }

        var html = "<div class=\"scroll\"><table><thead><tr>"
        for cell in header {
            html += "<th>\(inline(cell))</th>"
        }
        html += "</tr></thead><tbody>"
        for row in body {
            html += "<tr>"
            for cell in row {
                html += "<td>\(inline(cell))</td>"
            }
            html += "</tr>"
        }
        html += "</tbody></table></div>"
        return html
    }

    private static func inline(_ text: String) -> String {
        var value = esc(text)
        value = value.replacingOccurrences(
            of: #"\*\*(.+?)\*\*"#,
            with: "<strong>$1</strong>",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"`([^`]+)`"#,
            with: "<code>$1</code>",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"[（(](?:B\d+-)?[UR]\d{3}[）)]"#,
            with: "<span class=\"cite\">$0</span>",
            options: .regularExpression
        )
        return value
    }

    private static func esc(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func percent(_ value: Double) -> Int {
        Int((value * 100).rounded(.down))
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: Date())
    }

    // MARK: CSS（Apple 风格 token + 高密度）

    private static let css = """
    :root{
      --bg:#f5f5f7;--surface:#fff;--ink:#1d1d1f;--ink2:#6e6e73;--line:#d2d2d7;
      --accent:#0071e3;--fill:#f5f5f7;--shadow:0 1px 2px rgba(0,0,0,.04),0 8px 24px rgba(0,0,0,.04);
      --radius:14px;--gap:10px;
    }
    @media (prefers-color-scheme:dark){
      :root{--bg:#000;--surface:#1c1c1e;--ink:#f5f5f7;--ink2:#a1a1a6;--line:#38383a;
            --accent:#2997ff;--fill:#2c2c2e;--shadow:0 1px 2px rgba(0,0,0,.5),0 8px 24px rgba(0,0,0,.4)}
    }
    *{box-sizing:border-box}
    html{-webkit-text-size-adjust:100%}
    body{
      margin:0;padding:20px 16px 48px;background:var(--bg);color:var(--ink);
      font:13px/1.45 -apple-system,BlinkMacSystemFont,"SF Pro Display","SF Pro Text","Helvetica Neue","PingFang SC","Hiragino Sans GB","Microsoft YaHei",sans-serif;
      font-variant-numeric:tabular-nums;
    }
    .wrap{max-width:1200px;margin:0 auto}
    h1,h2,h3{margin:0;letter-spacing:-.02em;font-weight:650}
    h1{font-size:28px;line-height:1.15}
    h2{font-size:16px;margin-bottom:8px}
    h3{font-size:13px;margin:12px 0 4px}
    p{margin:0 0 6px}
    small,.sub{color:var(--ink2);font-size:11px}
    .eyebrow{font-size:10px;letter-spacing:.12em;text-transform:uppercase;color:var(--ink2);font-weight:650}
    .card{background:var(--surface);border:1px solid var(--line);border-radius:var(--radius);box-shadow:var(--shadow);padding:12px;margin-bottom:var(--gap)}
    .hero{display:grid;grid-template-columns:180px 1fr;gap:14px;align-items:start}
    .hero.compact{grid-template-columns:130px 1fr}
    .cover-fig{margin:0}
    .cover{width:100%;aspect-ratio:2/3;border-radius:12px;overflow:hidden;background:var(--fill);border:1px solid var(--line);box-shadow:var(--shadow)}
    .cover img{width:100%;height:100%;object-fit:cover;display:block}
    .cover-ph{display:flex;flex-direction:column;justify-content:flex-end;gap:4px;padding:14px;background:linear-gradient(160deg,var(--fill),var(--surface));font-weight:650;font-size:15px;line-height:1.25}
    .cover-ph small{font-weight:400;font-size:10px;line-height:1.35}
    figcaption{color:var(--ink2);font-size:10px;margin-top:4px;line-height:1.3}
    .hero-copy{min-width:0}
    .hero h1{margin:2px 0 4px}
    .grade{display:inline-flex;align-items:baseline;gap:6px;padding:3px 9px;border-radius:999px;background:var(--fill);border:1px solid var(--line);font-weight:700;margin-top:6px}
    .grade b{font-size:20px;letter-spacing:-.03em}
    .grade-A{color:#1a7f37;border-color:#1a7f37}
    .grade-B{color:#0071e3;border-color:#0071e3}
    .grade-C{color:#b25000;border-color:#b25000}
    .grade-D{color:#c62828;border-color:#c62828}
    .grade-mini{display:inline-block;padding:0 5px;border-radius:5px;border:1px solid currentColor;font-weight:700;font-size:10px;margin-right:3px}
    .verdict{font-size:13px;margin:8px 0 10px;max-width:82ch}
    .kpis{display:grid;grid-template-columns:repeat(8,1fr);gap:8px;margin:8px 0 2px}
    .hero.compact .kpis{grid-template-columns:repeat(4,1fr)}
    .kpi{background:var(--fill);border:1px solid var(--line);border-radius:10px;padding:7px 9px;min-width:0}
    .kpi .k{display:block;font-size:10px;color:var(--ink2);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    .kpi .v{display:block;font-size:18px;font-weight:680;letter-spacing:-.03em;line-height:1.2}
    .kpi .n{display:block;font-size:9.5px;color:var(--ink2);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    .section-head{display:flex;align-items:baseline;justify-content:space-between;gap:8px;margin-bottom:8px}
    .bar{display:grid;grid-template-columns:72px 1fr 110px 52px;gap:8px;align-items:center;font-size:10.5px;padding:2px 0}
    .bar-label{color:var(--ink2);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    .track{height:6px;background:var(--fill);border-radius:999px;overflow:hidden;border:1px solid var(--line)}
    .track i{display:block;height:100%;background:var(--accent);border-radius:999px}
    .num{text-align:right;white-space:nowrap;color:var(--ink2)}
    .bar-value{color:var(--ink2)}
    .bar-points{color:var(--ink)}
    table{width:100%;border-collapse:collapse;font-size:12px}
    caption{text-align:left;color:var(--ink2);font-size:10px;padding-bottom:4px}
    th,td{text-align:left;padding:6px 8px;border-bottom:1px solid var(--line);vertical-align:top}
    thead th{font-size:10px;letter-spacing:.04em;text-transform:uppercase;color:var(--ink2);font-weight:650;background:var(--fill)}
    tbody tr:last-child td{border-bottom:0}
    .cite{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:10.5px;color:var(--accent);white-space:nowrap}
    .tag{display:inline-block;padding:1px 6px;border-radius:6px;background:var(--fill);border:1px solid var(--line);font-size:10px;color:var(--ink2);margin-right:4px}
    .tag-thought{color:var(--accent)}
    blockquote{border-left:2px solid var(--accent);padding-left:8px;color:var(--ink);margin:4px 0;font-size:12.5px}
    .quote{color:var(--ink2);font-size:12px;margin:2px 0 4px}
    .note-text{font-size:13px;margin:2px 0}
    .entry{padding:8px 0;border-bottom:1px solid var(--line)}
    .entry:last-child{border-bottom:0}
    .entry-head{margin-bottom:3px}
    .toc{list-style:none;margin:0;padding:0;columns:2;column-gap:18px;font-size:12px}
    .toc li{display:flex;justify-content:space-between;gap:8px;padding:3px 0;border-bottom:1px dotted var(--line);break-inside:avoid}
    .report h2{padding-top:12px;border-top:1px solid var(--line);margin-top:12px}
    .report h2:first-child{border-top:0;padding-top:0;margin-top:0}
    .report ul{margin:4px 0 8px;padding-left:18px}
    .report li{margin:2px 0}
    .report strong{font-weight:650}
    .report code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:11px;background:var(--fill);padding:1px 4px;border-radius:4px}
    .scroll{overflow-x:auto}
    .cover-strip-wrap{min-width:0}
    .cover-strip{display:flex;gap:8px;overflow-x:auto;padding-bottom:4px}
    .mini{margin:0;flex:0 0 72px;width:72px}
    .mini-cover{aspect-ratio:2/3;font-size:9px;padding:6px;border-radius:8px}
    .mini figcaption{font-size:8.5px}
    footer{margin-top:16px;padding-top:10px;border-top:1px solid var(--line);color:var(--ink2);font-size:10.5px;line-height:1.6}
    @media (max-width:820px){
      .hero,.hero.compact{grid-template-columns:110px 1fr}
      .kpis{grid-template-columns:repeat(4,1fr)}
      .bar{grid-template-columns:64px 1fr 84px 44px}
      h1{font-size:23px}
      .toc{columns:1}
    }
    @media print{
      :root{--bg:#fff;--surface:#fff;--ink:#000;--ink2:#555;--line:#ccc;--fill:#f3f3f3;--shadow:none}
      body{padding:0;font-size:11px}
      .card,.kpi,section,tr{break-inside:avoid}
      *{-webkit-print-color-adjust:exact;print-color-adjust:exact}
    }
    """
}
