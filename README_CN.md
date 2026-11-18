# ReadCopilot

> 面向微信读书用户的本地优先 SwiftUI 阅读工作台：将划线和笔记沉淀为可搜索、可追溯的知识，并获得 AI 辅助的阅读分析。

## 功能

- **阅读主页**：展示微信读书画像、阅读时长、阅读天数、完读率、日均阅读、书架构成、类别分布、阅读时段热力图和最近阅读书籍。
- **微信读书同步**：使用用户提供的 `wrk-...` Key 获取阅读数据和书架；同步成功的数据会在本地保存，后续启动可离线查看。
- **Copilot 分析**：支持单本书、类别和全书库范围，提供 8 个报告模板：笔记体检、阅读教练、批判性阅读、行动转化、读后闭环、主题地图、读法处方与书评工坊。需要笔记的模板会先在本地计算七因子等级、KPI 与候选证据，LLM 只负责解释。
- **完整笔记处理**：获取划线，并通过 `synckey` 分页拉取想法/笔记，避免仅获取前 100 条而造成静默遗漏。
- **导出**：可将分析报告导出为 Markdown、PDF 或自包含 HTML（内联 CSS、封面以 data URI 内嵌）；也可将指定书籍的全部划线及其对应笔记导出为 Markdown，或纯本地生成按章节分组的单文件 HTML 划线整理本。
- **知识库**：将笔记去重导入 SwiftData；支持在书名、原文和笔记中全文搜索，并保留来源书籍。
- **主题层**：通过已配置的 LLM 为每条知识条目生成 1-3 个主题标签，实现可过滤、可追溯的 **主题 -> 原文 -> 书籍** 结构。
- **本地 Ollama**：同时支持 OpenAI 兼容的云端 API 和本地 Ollama。Ollama 不需要 API Key，并可在设置中扫描已安装模型。

## 隐私与数据流

ReadCopilot 采用本地优先与 BYOK（自带 Key）设计：

```text
微信读书 API -> LibraryStore -> SwiftData（书籍和阅读画像）
微信读书笔记 -> KnowledgeStore -> SwiftData（KnowledgeItem）
KnowledgeItem -> 已配置 LLM -> 主题标签
选中的笔记 -> 已配置 LLM -> 分析报告
```

- 微信读书和云端模型 API Key 只存储在设备 Keychain 中。
- 书籍数据、笔记、报告和知识条目均持久化在本地 SwiftData 中；应用不提供自有云同步或遥测。
- 笔记指标、等级、读法处方与 HTML 渲染均在本机完成。
- 分析前，界面会征得同意，因为选中的划线和笔记会发送到已配置的 LLM 服务端点。读法处方模板可以只发送书名、作者、类别与阅读目的。
- HTML 报告仅在需要内嵌封面时下载微信读书返回的封面 URL，不调用额外服务；失败时使用明确标注的占位图。
- 使用 Ollama 时，分析和主题提取均在本机完成。

## 环境要求

- 推荐 Xcode 16+
- macOS 目标和开发环境：macOS 14+
- iOS 目标：iOS 17+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- 以 `wrk-...` 开头的微信读书 Agent API Key
- 以下二选一：
  - OpenAI 兼容 API 的 Key、Base URL 和模型名；或
  - 已在本机运行的 [Ollama](https://ollama.com/)

## 快速开始

```bash
# 首次安装 XcodeGen
brew install xcodegen

# project.yml 修改后重新生成工程
xcodegen generate

# 使用 Xcode 打开工程
open ReadCopilot.xcodeproj
```

### 首次使用

1. 打开 **设置**，输入微信读书 `wrk-...` API Key，选择 **验证并保存**。
2. 选择云端 **阅读分析模型**（Key、Base URL、模型）或 **本地 Ollama**。
3. 若使用 Ollama，先启动服务并拉取模型，例如：

   ```bash
   ollama serve
   ollama pull qwen2.5
   ```

   回到设置页，选择 **扫描本地已安装模型**，选定模型后测试并保存连接。
4. 打开 **阅读主页** 并选择 **同步**。
5. 在 **Copilot** 中选择一本书，并使用 **划线与笔记** 导出全部条目或导入知识库。
6. 在 **知识库** 中选择 **AI 提取主题**，为已导入的条目生成可筛选主题。

## 架构

```text
ReadCopilot/
├── App/             应用入口
├── UI/              SwiftUI 页面和复用展示组件
├── Data/            领域模型、SwiftData 模型、Store 与导出
├── Services/        支持依赖注入的业务流程
├── Networking/      精简的微信读书和 OpenAI 兼容 API 客户端
├── Security/        Keychain 凭证存储
└── ReadCopilotTests/
```

### 模块职责

| 组件 | 职责 |
| --- | --- |
| `LibraryStore` | 阅读主页状态、书架/画像同步、本地缓存读取 |
| `WeReadGateway` | 微信读书请求构造与重试 |
| `WeReadNotesService` | 全量笔记拉取与 JSON 到领域对象的解析 |
| `AnalysisService` | LLM 配置、提示词构造和分析调用 |
| `NoteMetrics` | 本地计数、字数分档、七因子等级、证据排序与引用 ID |
| `MethodAdvisor` | 诊断到读法处方的确定性映射 |
| `ReportHTMLBuilder` | 单文件 HTML 报告与本地整理本渲染 |
| `ReportCoverLoader` | 封面下载、压缩与 data URI 编码 |
| `TopicExtractionService` | 批量 LLM 主题提取与 JSON 解析 |
| `KnowledgeStore` | SwiftData 知识库持久化、搜索和主题过滤 |
| `DiagnosisModel` | 分析界面状态、进度、本地指标和本地通知 |
| `ReportExporter` | Markdown、PDF、HTML 与本地指标附录生成 |

`Services` 使用 `KeyStore` 协议，因此无需真实 Keychain 即可测试业务流程。网络客户端使用可注入的 `NetworkSession` 协议，以实现确定性的测试。

## 开发

每次修改 `project.yml` 后，请重新生成 Xcode 工程：

```bash
xcodegen generate
```

运行完整测试：

```bash
xcodebuild \
  -project ReadCopilot.xcodeproj \
  -scheme ReadCopilot \
  -destination 'platform=macOS,arch=arm64' \
  test
```

构建 iOS 目标：

```bash
xcodebuild \
  -project ReadCopilot.xcodeproj \
  -scheme ReadCopilot \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  build
```

## 当前限制

- 知识检索目前采用结构化全文搜索和主题过滤。为避免过早引入存储及索引成本，本地向量嵌入会在知识库规模足够大时再考虑。
- 微信读书网关的接口契约决定可获取哪些阅读指标；阅读主页会展示当前可取得的全部画像、书架、类别和阅读时长指标。
- 主题提取需要配置可连通的 LLM。即使尚未提取主题，已导入笔记仍可被完整搜索。
- 笔记等级是当前笔记本的诊断代理指标，不代表阅读能力，也不承诺提分；A2 行动与复盘结果在真实记录前标注「待补录」。

## 许可证

MIT
