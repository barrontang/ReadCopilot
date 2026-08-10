import Foundation

// MARK: - LLM Client(OpenAI 兼容 /chat/completions)
// 支持 DeepSeek / OpenAI / Ollama / 任意 OpenAI 兼容端点。BYOK,不持久化 key。

enum LLMError: LocalizedError {
    case missingConfig
    case badURL
    case http(Int, String)
    case decoding(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .missingConfig: return "未设置 LLM Key 或 Base URL"
        case .badURL: return "Base URL 格式错误"
        case .http(let c, let m): return "接口错误 HTTP \(c): \(m)"
        case .decoding(let m): return "解析失败: \(m)"
        case .empty: return "模型返回为空"
        }
    }
}

struct LLMClient {
    let apiKey: String
    let baseURL: String      // 形如 https://api.deepseek.com/v1
    let model: String
    var session: URLSession = .shared

    private func endpoint() throws -> URL {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: base + "/chat/completions") else { throw LLMError.badURL }
        return url
    }

    /// 发一条 chat,返回文本内容。
    func chat(system: String, user: String, maxTokens: Int = 512) async throws -> String {
        guard !apiKey.isEmpty, !baseURL.isEmpty else { throw LLMError.missingConfig }
        let url = try endpoint()

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "max_tokens": maxTokens,
            "stream": false
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        req.timeoutInterval = 30

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw LLMError.http(-1, "无响应") }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.http(http.statusCode, String(body.prefix(200)))
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.decoding("响应结构非预期")
        }
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { throw LLMError.empty }
        return text
    }

    /// 验证配置:发一条最小 ping,成功返回模型回话内容。
    func validate() async throws -> String {
        try await chat(system: "你是连接测试助手,只回复:连接成功",
                       user: "ping", maxTokens: 16)
    }
}
