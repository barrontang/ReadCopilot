import Foundation

protocol NetworkSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkSession {}

// MARK: - WeRead Gateway Client
// 直接对接 https://i.weread.qq.com/api/agent/gateway
// BYOK: key 由调用方从 Keychain 取出传入,本类不持久化 key。

enum WeReadError: LocalizedError {
    case missingKey
    case http(Int)
    case gateway(code: Int, message: String)
    case upgradeRequired(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "未设置微信读书 API Key(wrk-...)"
        case .http(let c): return "网络错误 HTTP \(c)"
        case .gateway(let code, let msg): return "接口错误[\(code)]: \(msg)"
        case .upgradeRequired(let m): return "需要升级: \(m)"
        case .decoding(let m): return "解析失败: \(m)"
        }
    }
}

struct WeReadGateway {
    static let endpoint = URL(string: "https://i.weread.qq.com/api/agent/gateway")!
    static let skillVersion = "1.0.4"

    let apiKey: String                 // wrk-...
    var session: any NetworkSession = URLSession.shared

    /// 通用调用:api_name + 平铺业务参数。返回原始 JSON 字典。
    /// 对网络错误与 5xx 做一次指数退避重试。
    func call(_ apiName: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        do {
            return try await callOnce(apiName, params: params)
        } catch {
            guard isRetryable(error) else { throw error }
            try await Task.sleep(nanoseconds: 800_000_000)
            return try await callOnce(apiName, params: params)
        }
    }

    private func isRetryable(_ error: Error) -> Bool {
        if case WeReadError.http(let code) = error { return code >= 500 || code == -1 }
        return error is URLError
    }

    private func callOnce(_ apiName: String, params: [String: Any]) async throws -> [String: Any] {
        guard apiKey.hasPrefix("wrk-") else { throw WeReadError.missingKey }

        var body: [String: Any] = params
        body["api_name"] = apiName
        body["skill_version"] = Self.skillVersion   // 每次必带

        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw WeReadError.http(-1) }
        guard (200..<300).contains(http.statusCode) else { throw WeReadError.http(http.statusCode) }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WeReadError.decoding("响应非 JSON 对象")
        }
        // 版本升级强制处理
        if let upgrade = json["upgrade_info"] as? [String: Any] {
            let msg = (upgrade["message"] as? String) ?? "服务端要求升级 skill_version"
            throw WeReadError.upgradeRequired(msg)
        }
        if let code = json["errcode"] as? Int, code != 0 {
            let msg = (json["errmsg"] as? String) ?? "未知错误"
            throw WeReadError.gateway(code: code, message: msg)
        }
        return json
    }

    // MARK: 便捷方法

    /// 阅读统计画像。mode: weekly / monthly / annually / overall
    func readData(mode: String = "overall") async throws -> [String: Any] {
        try await call("/readdata/detail", params: ["mode": mode])
    }

    /// 书架
    func shelf() async throws -> [String: Any] {
        try await call("/shelf/sync")
    }

    /// 有笔记的书(翻页)
    func notebooks(count: Int = 100, lastSort: Int? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["count": count]
        if let lastSort { p["lastSort"] = lastSort }
        return try await call("/user/notebooks", params: p)
    }

    /// 某书个人想法/笔记
    func myReviews(bookId: String, synckey: Int = 0, count: Int = 100) async throws -> [String: Any] {
        try await call("/review/list/mine", params: ["bookid": bookId, "synckey": synckey, "count": count])
    }

    /// 某书划线
    func bookmarks(bookId: String) async throws -> [String: Any] {
        try await call("/book/bookmarklist", params: ["bookId": bookId])
    }

    /// 搜索(bookId 解析)
    func search(keyword: String, scope: Int = 10, count: Int = 15) async throws -> [String: Any] {
        try await call("/store/search", params: ["keyword": keyword, "scope": scope, "count": count])
    }

    /// 连通性 & key 有效性自检:成功返回 true
    func validateKey() async throws -> Bool {
        _ = try await readData(mode: "overall")
        return true
    }
}
