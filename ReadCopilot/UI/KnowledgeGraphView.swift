import SwiftUI

struct KnowledgeGraphView: View {
    let books: [LibraryBook]
    @ObservedObject var knowledgeStore: KnowledgeStore
    @State private var selectedCategory: String?
    @State private var topicMessage: String?

    private var categories: [(name: String, books: [LibraryBook])] {
        Dictionary(grouping: books.filter { !$0.isAlbum }) {
            $0.category.isEmpty ? "未分类" : $0.category
        }
        .map { ($0.key, $0.value) }
        .sorted { $0.books.count > $1.books.count }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("编译式阅读知识库").font(Theme.serifTitle(22))
                    Text("已沉淀 \(knowledgeStore.entries.count) 条划线与笔记；每条知识均保留原文、读者想法与来源图书。")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.inkSecondary)
                }

                if !knowledgeStore.entries.isEmpty {
                    KnowledgeSummary(entries: knowledgeStore.entries, thoughts: knowledgeStore.thoughtCount, sourceBooks: knowledgeStore.sourceBookCount)

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Theme.inkSecondary)
                            .font(.system(size: 13))
                        TextField("搜索原文、笔记或书名", text: $knowledgeStore.searchText)
                            .font(Theme.body(13))
                            .textFieldStyle(.plain)
                        if !knowledgeStore.searchText.isEmpty {
                            Button { knowledgeStore.searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Theme.inkSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.hairline, lineWidth: 1))

                    // MARK: 主题层（主题 ↔ 原文 ↔ 书籍）
                    TopicFilterBar(
                        topics: knowledgeStore.allTopics,
                        selected: $knowledgeStore.selectedTopic,
                        pendingCount: knowledgeStore.pendingTopicCount,
                        extracting: knowledgeStore.extractingTopics,
                        message: topicMessage,
                        onExtract: { Task { await runTopicExtraction() } }
                    )

                    if knowledgeStore.entriesByBook.isEmpty {
                        Text("没有匹配的知识条目")
                            .font(Theme.body(12))
                            .foregroundStyle(Theme.inkSecondary)
                    } else {
                        KnowledgeEvidenceList(groups: knowledgeStore.entriesByBook)
                    }
                }

                if categories.isEmpty {
                    ContentUnavailableView("同步书库后生成知识图谱", systemImage: "point.3.connected.trianglepath.dotted")
                } else {
                    KnowledgeGraphCanvas(categories: Array(categories.prefix(10)), selection: $selectedCategory)
                        .frame(minHeight: 420)
                        .background(Theme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline))

                    if let selectedCategory,
                       let group = categories.first(where: { $0.name == selectedCategory }) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(selectedCategory).font(Theme.serifTitle(17))
                            ForEach(group.books) { book in
                                HStack {
                                    Image(systemName: "book.closed").foregroundStyle(Theme.accent)
                                    Text(book.title)
                                    Spacer()
                                    Text(book.author).foregroundStyle(Theme.inkSecondary)
                                }
                                .font(Theme.body(13))
                            }
                        }
                        .padding(18)
                        .background(Theme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(24)
        }
        .background(Theme.bg)
        .navigationTitle("知识库")
    }

    private func runTopicExtraction() async {
        topicMessage = nil
        do {
            let updated = try await knowledgeStore.extractTopics()
            topicMessage = updated == 0 ? "没有需要提取主题的条目" : "已为 \(updated) 条知识提取主题"
        } catch {
            topicMessage = "提取失败：\(error.localizedDescription)"
        }
    }
}

// MARK: - 主题过滤条（主题层）
private struct TopicFilterBar: View {
    let topics: [(topic: String, count: Int)]
    @Binding var selected: String?
    let pendingCount: Int
    let extracting: Bool
    let message: String?
    let onExtract: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("主题").font(Theme.serifTitle(15))
                Spacer()
                if pendingCount > 0 {
                    Button {
                        onExtract()
                    } label: {
                        if extracting {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("提取中…").font(Theme.body(12))
                            }
                        } else {
                            Label("AI 提取主题（\(pendingCount) 条待处理）", systemImage: "sparkles")
                                .font(Theme.body(12))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(extracting)
                }
            }

            if topics.isEmpty {
                Text("尚未提取主题。点击「AI 提取主题」把原文与笔记编译为可追溯的主题节点。")
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.inkSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(topics, id: \.topic) { item in
                            Button {
                                selected = selected == item.topic ? nil : item.topic
                            } label: {
                                Text("\(item.topic) \(item.count)")
                                    .font(Theme.body(12))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(selected == item.topic ? Theme.accent.opacity(0.16) : Theme.bg)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(selected == item.topic ? Theme.accent : Theme.hairline))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if let message {
                Text(message)
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .padding(14)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
    }
}

private struct KnowledgeSummary: View {
    let entries: [KnowledgeEntry]
    let thoughts: Int
    let sourceBooks: Int

    var body: some View {
        HStack(spacing: 12) {
            metric("原文", value: entries.count, icon: "highlighter")
            metric("笔记", value: thoughts, icon: "text.bubble")
            metric("来源书籍", value: sourceBooks, icon: "books.vertical")
        }
    }

    private func metric(_ title: String, value: Int, icon: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)").font(Theme.serifTitle(20))
                Text(title).font(Theme.body(11)).foregroundStyle(Theme.inkSecondary)
            }
        } icon: {
            Image(systemName: icon).foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct KnowledgeEvidenceList: View {
    let groups: [(title: String, entries: [KnowledgeEntry])]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("原文与笔记").font(Theme.serifTitle(17))
            Text("按来源保留划线原文与读者笔记，供后续分析综合。")
                .font(Theme.body(12))
                .foregroundStyle(Theme.inkSecondary)
            ForEach(groups, id: \.title) { group in
                VStack(alignment: .leading, spacing: 10) {
                    Label("\(group.title) · \(group.entries.count) 条", systemImage: "book.closed")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.accent)
                    ForEach(group.entries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.sourceText).font(Theme.body(13)).lineLimit(3)
                            if !entry.noteText.isEmpty {
                                Text("笔记：\(entry.noteText)")
                                    .font(Theme.body(12))
                                    .foregroundStyle(Theme.inkSecondary)
                                    .lineLimit(3)
                            }
                            if !entry.topics.isEmpty {
                                HStack(spacing: 6) {
                                    ForEach(entry.topics, id: \.self) { topic in
                                        Text(topic)
                                            .font(.system(size: 10))
                                            .foregroundStyle(Theme.accent)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(Theme.accent.opacity(0.10))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(Theme.bg)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(16)
                .background(Theme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

private struct KnowledgeGraphCanvas: View {
    let categories: [(name: String, books: [LibraryBook])]
    @Binding var selection: String?

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            ZStack {
                Canvas { context, _ in
                    for index in categories.indices {
                        let point = position(index: index, center: center)
                        var path = Path()
                        path.move(to: center)
                        path.addLine(to: point)
                        context.stroke(path, with: .color(Theme.hairline), lineWidth: 1.5)
                    }
                }

                Text("我的阅读")
                    .font(Theme.serifTitle(16))
                    .padding(16)
                    .background(Theme.accent)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
                    .position(center)

                ForEach(categories.indices, id: \.self) { index in
                    let category = categories[index]
                    Button {
                        selection = category.name
                    } label: {
                        VStack(spacing: 3) {
                            Text(category.name)
                                .font(Theme.body(12))
                                .lineLimit(1)
                            Text("\(category.books.count) 本")
                                .font(Theme.body(10))
                                .foregroundStyle(Theme.inkSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(selection == category.name ? Theme.accent.opacity(0.16) : Theme.bg)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(selection == category.name ? Theme.accent : Theme.hairline))
                    }
                    .buttonStyle(.plain)
                    .position(position(index: index, center: center))
                }
            }
        }
    }

    private func position(index: Int, center: CGPoint) -> CGPoint {
        let angle = (Double(index) / Double(max(categories.count, 1))) * 2 * Double.pi - Double.pi / 2
        let radius = min(center.x, center.y) * 0.68
        return CGPoint(
            x: center.x + CGFloat(cos(angle)) * radius,
            y: center.y + CGFloat(sin(angle)) * radius
        )
    }
}
