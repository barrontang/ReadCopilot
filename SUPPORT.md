# ReadCopilot 支持 / Support

## 系统要求 / Requirements

- macOS 14 Sonoma 或更高版本
- 微信读书 Agent API Key（`wrk-...`）
- 以下 AI 服务之一：
  - OpenAI 兼容接口（自备 API Key、Base URL、模型名）
  - 本地 [Ollama](https://ollama.com/)

## 首次使用 / Getting started

1. 打开 **设置**，填入微信读书 `wrk-...` Key，点击 **验证并保存**。
2. 配置 **阅读分析模型**：
   - 云端：填写 API Key、Base URL 和模型名；或
   - 本地：启动 Ollama，安装模型（如 `ollama pull qwen2.5`），在设置中扫描并选择模型。
3. 进入 **阅读首页**，点击 **同步** 拉取书架与阅读统计。
4. 进入 **Copilot** 选择书籍或分类，运行分析模板，或导入笔记到知识库。
5. 进入 **知识库**，运行 **AI 提取主题** 整理条目。

## 常见问题 / FAQ

### 同步失败或提示未授权

- 确认 Key 以 `wrk-` 开头，且未过期。
- 在设置中重新点击 **验证并保存**。
- 确认网络可以访问微信读书接口；本应用不经过开发者服务器代理。

### AI 分析失败

- 云端模型：检查 API Key、Base URL（需包含 `/v1` 等路径）和模型名是否正确，并确认账户有余额。
- Ollama：确认 `ollama serve` 正在运行，且所选模型已下载。
- 分析会把选中的笔记发送到你配置的端点，请确认已同意该次传输。

### 报告导出到哪里

导出文件会写入你在系统文件选择器中指定的位置。应用只拥有你授权目录的读写权限。

### 删除数据

- 在应用内删除书籍、笔记或知识库条目。
- 在设置中清除 API Key。
- 卸载应用会删除沙盒内数据；钥匙串条目可在“钥匙串访问”中删除。

### 应用是免费的吗

是。ReadCopilot 免费提供，不包含内购，也不含广告或追踪。

## 隐私 / Privacy

请阅读 [隐私政策](./PRIVACY.md)。

Read the [Privacy Policy](./PRIVACY.md).

## 联系 / Contact

提交问题或功能建议：

<https://github.com/barrontang/ReadCopilot/issues>

Open an issue at the link above. Please include:

- macOS 版本
- 应用版本（设置 → 关于）
- 复现步骤
- 相关错误提示（请先移除 API Key 等敏感信息）
