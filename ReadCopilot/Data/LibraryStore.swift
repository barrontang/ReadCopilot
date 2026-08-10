import Foundation

// MARK: - 真实数据模型(字段严格对齐 weread skill 文档 v1.0.4)

struct LibraryBook: Identifiable, Hashable {
    let id: String          // bookId
    let title: String
    let author: String
    let cover: String
    let category: String
    let finished: Bool       // finishReading == 1
    let secret: Bool         // secret == 1
    let readUpdateTime: Int
    let isAlbum: Bool        // true = 专辑/有声书
}

// 阅读统计摘要(readStat[])
struct ReadStatItem: Identifiable, Hashable {
    var id: String { stat }
    let stat: String        // 读过/读完/阅读/笔记
    let counts: String      // "12本" 等文案(文档要求原样展示)
}

struct ReadingProfile {
    var totalReadTime: Int = 0      // 秒
    var readDays: Int = 0
    var registTime: Int = 0
    var preferCategoryWord: String = ""
    var preferTimeWord: String = ""
    var preferTime: [Int] = []      // 24 桶,秒;顺序从 6 点起
    var stats: [ReadStatItem] = []
}

// MARK: - LibraryStore:全量拉取书库 + 阅读画像

@MainActor
final class LibraryStore: ObservableObject {
    @Published var books: [LibraryBook] = []
    @Published var profile = ReadingProfile()
    @Published var loading = false
    @Published var error: String?
    @Published var lastSyncedAt: Date?

    // 书架数量口径(文档规定):books + albums + (mp 非空 ? 1 : 0)
    @Published var bookCount = 0
    @Published var albumCount = 0
    @Published var hasMPCollection = false
    var totalShelfItems: Int { bookCount + albumCount + (hasMPCollection ? 1 : 0) }

    private func gateway() -> WeReadGateway? {
        guard let key = Keychain.get(.wereadAPIKey), key.hasPrefix("wrk-") else { return nil }
        return WeReadGateway(apiKey: key)
    }

    /// 全量同步:阅读统计(overall) + 全量书架。
    func syncAll() async {
        guard let gw = gateway() else {
            error = "尚未配置微信读书 Key,请到设置页填入 wrk- 开头的 Key"
            return
        }
        loading = true; error = nil
        defer { loading = false }
        do {
            async let profileJSON = gw.readData(mode: "overall")
            async let shelfJSON = gw.shelf()
            let (pj, sj) = try await (profileJSON, shelfJSON)
            parseProfile(pj)
            parseShelf(sj)
            lastSyncedAt = Date()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: 解析阅读统计
    private func parseProfile(_ j: [String: Any]) {
        var p = ReadingProfile()
        p.totalReadTime = j["totalReadTime"] as? Int ?? 0
        p.readDays = j["readDays"] as? Int ?? 0
        p.registTime = j["registTime"] as? Int ?? 0
        p.preferCategoryWord = j["preferCategoryWord"] as? String ?? ""
        p.preferTimeWord = j["preferTimeWord"] as? String ?? ""
        p.preferTime = j["preferTime"] as? [Int] ?? []
        if let arr = j["readStat"] as? [[String: Any]] {
            p.stats = arr.compactMap {
                guard let stat = $0["stat"] as? String,
                      let counts = $0["counts"] as? String else { return nil }
                return ReadStatItem(stat: stat, counts: counts)
            }
        }
        self.profile = p
    }

    // MARK: 解析书架(电子书 + 有声书专辑)
    private func parseShelf(_ j: [String: Any]) {
        var result: [LibraryBook] = []

        let booksArr = j["books"] as? [[String: Any]] ?? []
        bookCount = booksArr.count
        for b in booksArr {
            guard let id = b["bookId"] as? String else { continue }
            result.append(LibraryBook(
                id: id,
                title: b["title"] as? String ?? "(无题)",
                author: b["author"] as? String ?? "",
                cover: b["cover"] as? String ?? "",
                category: b["category"] as? String ?? "",
                finished: (b["finishReading"] as? Int ?? 0) == 1,
                secret: (b["secret"] as? Int ?? 0) == 1,
                readUpdateTime: b["readUpdateTime"] as? Int ?? 0,
                isAlbum: false
            ))
        }

        let albumsArr = j["albums"] as? [[String: Any]] ?? []
        albumCount = albumsArr.count
        for a in albumsArr {
            let info = a["albumInfo"] as? [String: Any] ?? [:]
            let extra = a["albumInfoExtra"] as? [String: Any] ?? [:]
            guard let aid = info["albumId"] as? String else { continue }
            result.append(LibraryBook(
                id: aid,
                title: info["name"] as? String ?? "(无题专辑)",
                author: info["authorName"] as? String ?? "",
                cover: info["cover"] as? String ?? "",
                category: "有声书",
                finished: (info["finish"] as? Int ?? 0) == 1,
                secret: (extra["secret"] as? Int ?? 0) == 1,
                readUpdateTime: extra["lectureReadUpdateTime"] as? Int ?? 0,
                isAlbum: true
            ))
        }

        // mp 文章收藏入口(非空即 1 个条目)
        if let mp = j["mp"], !(mp is NSNull) {
            hasMPCollection = true
        } else {
            hasMPCollection = false
        }

        // 按最近阅读时间倒序
        result.sort { $0.readUpdateTime > $1.readUpdateTime }
        self.books = result
    }

    // 秒 → "X小时Y分钟"
    static func fmtDuration(_ sec: Int) -> String {
        let h = sec / 3600, m = (sec % 3600) / 60
        if h > 0 { return "\(h)小时\(m)分钟" }
        return "\(m)分钟"
    }
    // 时间戳 → YYYY-MM-DD
    static func fmtDate(_ ts: Int) -> String {
        guard ts > 0 else { return "—" }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }
}
