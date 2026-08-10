import SwiftUI

// 跨平台:iOS 关闭自动大写,macOS 无此 API 时为 no-op
extension View {
    @ViewBuilder func noAutocap() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never).autocorrectionDisabled()
        #else
        self.autocorrectionDisabled()
        #endif
    }
}

// MARK: - 设置页:用户填入两个 BYOK key 的界面
// weread key(必填) + LLM key(选填,做分析时才需要)

@MainActor
final class SettingsModel: ObservableObject {
    @Published var wereadKey: String = Keychain.get(.wereadAPIKey) ?? ""
    @Published var llmKey: String = Keychain.get(.llmAPIKey) ?? ""
    @Published var llmBaseURL: String = Keychain.get(.llmBaseURL) ?? "https://api.deepseek.com/v1"
    @Published var llmModel: String = Keychain.get(.llmModel) ?? "deepseek-chat"

    // 微信读书验证状态
    @Published var wrValidating = false
    @Published var wrMessage: String?
    @Published var wrOK = false

    // LLM 验证状态
    @Published var llmValidating = false
    @Published var llmMessage: String?
    @Published var llmOK = false

    func saveWeRead() {
        Keychain.set(wereadKey.trimmingCharacters(in: .whitespacesAndNewlines), for: .wereadAPIKey)
    }

    func saveLLM() {
        Keychain.set(llmKey.trimmingCharacters(in: .whitespacesAndNewlines), for: .llmAPIKey)
        Keychain.set(llmBaseURL.trimmingCharacters(in: .whitespacesAndNewlines), for: .llmBaseURL)
        Keychain.set(llmModel.trimmingCharacters(in: .whitespacesAndNewlines), for: .llmModel)
    }

    func validateWeRead() async {
        wrValidating = true; wrMessage = nil; wrOK = false
        defer { wrValidating = false }
        let key = wereadKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.hasPrefix("wrk-") else {
            wrMessage = "格式错误:key 应以 wrk- 开头"; return
        }
        do {
            let ok = try await WeReadGateway(apiKey: key).validateKey()
            wrOK = ok
            wrMessage = ok ? "✅ 微信读书 Key 有效,已连通" : "验证失败"
            if ok { saveWeRead() }
        } catch {
            wrMessage = "❌ \(error.localizedDescription)"
        }
    }

    /// 你要求的:LLM config 设定后必须验证是否正常
    func validateLLM() async {
        llmValidating = true; llmMessage = nil; llmOK = false
        defer { llmValidating = false }
        let key = llmKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = llmBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let mdl = llmModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !base.isEmpty, !mdl.isEmpty else {
            llmMessage = "请填写 Key、Base URL 和 Model"; return
        }
        guard base.lowercased().hasPrefix("http") else {
            llmMessage = "Base URL 应以 http(s):// 开头"; return
        }
        do {
            let client = LLMClient(apiKey: key, baseURL: base, model: mdl)
            let reply = try await client.validate()
            llmOK = true
            llmMessage = "✅ LLM 连接正常 · 模型回话:\(reply.prefix(30))"
            saveLLM()
        } catch {
            llmOK = false
            llmMessage = "❌ \(error.localizedDescription)"
        }
    }

    func clearAll() {
        Keychain.deleteAll()
        wereadKey = ""; llmKey = ""
        llmBaseURL = "https://api.deepseek.com/v1"; llmModel = "deepseek-chat"
        wrMessage = "已清除全部本地 Key"; wrOK = false
        llmMessage = nil; llmOK = false
    }
}

struct SettingsView: View {
    @StateObject private var model = SettingsModel()

    var body: some View {
        Form {
            // MARK: 微信读书
            Section {
                SecureField("wrk-xxxxxxxx", text: $model.wereadKey)
                    .noAutocap()
                    .foregroundStyle(Theme.ink)
                Button {
                    Task { await model.validateWeRead() }
                } label: {
                    HStack {
                        Text("验证并保存")
                        if model.wrValidating { Spacer(); ProgressView().controlSize(.small) }
                    }
                }
                .disabled(model.wereadKey.isEmpty || model.wrValidating)
                if let msg = model.wrMessage {
                    Text(msg).font(.footnote)
                        .foregroundStyle(model.wrOK ? .green : Theme.inkSecondary)
                }
            } header: {
                Text("微信读书 API Key(必填)").foregroundStyle(Theme.ink)
            } footer: {
                Text("在微信读书 Agent 平台获取 wrk- 开头的 Key。仅存本机 Keychain,不上传。")
                    .foregroundStyle(Theme.inkSecondary)
            }

            // MARK: LLM
            Section {
                SecureField("sk-xxxxxxxx", text: $model.llmKey)
                    .noAutocap().foregroundStyle(Theme.ink)
                TextField("Base URL", text: $model.llmBaseURL)
                    .noAutocap().foregroundStyle(Theme.ink)
                TextField("Model", text: $model.llmModel)
                    .noAutocap().foregroundStyle(Theme.ink)

                // 预设快捷
                HStack(spacing: 8) {
                    Button("DeepSeek") {
                        model.llmBaseURL = "https://api.deepseek.com/v1"; model.llmModel = "deepseek-chat"
                    }.buttonStyle(.bordered).controlSize(.small)
                    Button("OpenAI") {
                        model.llmBaseURL = "https://api.openai.com/v1"; model.llmModel = "gpt-4o-mini"
                    }.buttonStyle(.bordered).controlSize(.small)
                    Button("Ollama 本地") {
                        model.llmBaseURL = "http://localhost:11434/v1"; model.llmModel = "qwen2.5"
                    }.buttonStyle(.bordered).controlSize(.small)
                }

                Button {
                    Task { await model.validateLLM() }
                } label: {
                    HStack {
                        Text("测试连接并保存")
                        if model.llmValidating { Spacer(); ProgressView().controlSize(.small) }
                    }
                }
                .disabled(model.llmKey.isEmpty || model.llmValidating)

                if let msg = model.llmMessage {
                    Text(msg).font(.footnote)
                        .foregroundStyle(model.llmOK ? .green : Theme.inkSecondary)
                }
            } header: {
                Text("大模型 API Key(用于阅读分析)").foregroundStyle(Theme.ink)
            } footer: {
                Text("支持任意 OpenAI 兼容接口。分析时你的笔记会发送到此 endpoint,请确认信任该服务商。默认 DeepSeek。")
                    .foregroundStyle(Theme.inkSecondary)
            }

            Section {
                Button("清除全部本地数据与 Key", role: .destructive) {
                    model.clearAll()
                }
            }
        }
        .formStyle(.grouped)
        .foregroundStyle(Theme.ink)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .navigationTitle("设置")
    }
}

#Preview { SettingsView() }
