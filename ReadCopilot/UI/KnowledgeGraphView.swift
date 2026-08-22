import SwiftUI

struct KnowledgeGraphView: View {
    let books: [LibraryBook]
    @State private var selectedCategory: String?

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
                    Text("编译式阅读知识库")
                        .font(Theme.serifTitle(22))
                    Text("当前图谱以图书品类建立可解释连接；后续同步笔记主题后，将主题、证据与写作素材编译为可追溯节点。")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.inkSecondary)
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
                            Text(selectedCategory)
                                .font(Theme.serifTitle(17))
                            ForEach(group.books) { book in
                                HStack {
                                    Image(systemName: "book.closed")
                                        .foregroundStyle(Theme.accent)
                                    Text(book.title)
                                    Spacer()
                                    Text(book.author)
                                        .foregroundStyle(Theme.inkSecondary)
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
