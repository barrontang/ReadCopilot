# ReadCopilot

<p align="center">
  <strong>把微信读书划线与想法，整理成私有、可检索、可追溯的 AI 阅读工作台。</strong>
</p>

<p align="center">
  SwiftUI 构建 • 本地优先 • BYOK • 同时支持云端模型与本地 Ollama
</p>

<p align="center">
  <a href="./README.md">English</a>
</p>

ReadCopilot 面向重度阅读用户：
同步微信读书数据、观察阅读习惯、导出划线笔记，并把分散材料沉淀为可长期复用的知识资产。

## 为什么选择 ReadCopilot

- **本地优先** —— 图书、笔记、报告、知识条目都保存在本机。
- **自带密钥（BYOK）** —— 你自己配置 WeRead Key 与 LLM 服务，不被平台绑定。
- **不止是导出工具** —— 除了导出 Markdown / PDF，还能继续检索、分析、整理。
- **AI 输出可追溯** —— 从主题提取到分析报告，都能保留来源图书与原文上下文。
- **模型配置灵活** —— 既支持 OpenAI 兼容接口，也支持本地 Ollama。

## 你可以用它做什么

### 1）看清自己的阅读全貌
同步后可获得阅读主页，查看：

- 阅读时长与阅读天数
- 完读率与日均阅读
- 书架构成与类别分布
- 阅读时段热力图
- 最近活跃图书

### 2）用 Copilot 模板分析一本书、一类书或整个书库
支持选择单本、分类或全库范围，并生成结构化分析，例如：

- 阅读教练
- 批判阅读
- 行动转化
- 跨书综合
- 长文书评

### 3）导出真正可复用的笔记
针对选中的图书，你可以：

- 导出全部划线与笔记为 Markdown
- 导出 AI 分析结果为 Markdown 或 PDF
- 在导入知识库后继续保留来源信息

### 4）把笔记沉淀为可检索知识库
导入 SwiftData 后，你可以获得：

- 去重后的笔记存储
- 基于书名、原文、笔记的全文检索
- 每条知识项 1–3 个 AI 自动提取主题标签
- 可追溯的 `主题 -> 原文 -> 图书` 关系

## 隐私与数据流

ReadCopilot 为希望使用 AI、又不愿放弃数据控制权的读者而设计。

```text
WeRead API -> LibraryStore -> SwiftData（图书与阅读画像）
WeRead notes -> KnowledgeStore -> SwiftData（KnowledgeItem）
KnowledgeItem -> 已配置 LLM -> topic labels
Selected notes -> 已配置 LLM -> analysis report
```

- WeRead Key 与云模型 API Key 仅保存在设备 Keychain 中。
- 图书、笔记、报告与知识条目保存在本地 SwiftData 中。
- 应用本身不提供云同步，也不内置遥测上传。
- 发起分析前，界面会明确征求同意，因为选中的笔记会发送到你配置的 LLM 端点。
- 如果使用 Ollama，分析与主题提取可以完全留在本机执行。

## 运行要求

- Xcode 16+
- macOS 14+（开发环境与 macOS 目标）
- iOS 17+（iOS 目标）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- 一个以 `wrk-...` 开头的 WeRead Agent API Key
- 以下二选一：
  - OpenAI 兼容接口的 API Key 与 Base URL
  - 本地运行的 [Ollama](https://ollama.com/)

## 快速开始

```bash
# 首次安装 XcodeGen
brew install xcodegen

# 修改 project.yml 后重新生成工程
xcodegen generate

# 用 Xcode 打开项目
open ReadCopilot.xcodeproj
```

## 首次使用流程

1. 打开 **Settings**，填入你的 WeRead `wrk-...` API Key。
2. 点击 **Verify and Save**。
3. 配置以下任一模型来源：
   - 云端 **Reading Analysis Model**（Key、Base URL、模型名）
   - **Local Ollama**
4. 如果使用 Ollama，先启动并拉取模型：

   ```bash
   ollama serve
   ollama pull qwen2.5
   ```

5. 回到 **Settings**，扫描本地模型、选择一个模型，再测试保存。
6. 打开 **阅读主页（Reading Home）**，点击 **Sync**。
7. 打开 **Copilot**，对图书做分析、导出划线，或把笔记导入知识库。
8. 打开 **知识库（Knowledge Base）**，执行 **AI Extract Topics**，生成可筛选的主题标签。

## 项目结构

```text
ReadCopilot/
├── App/             应用入口
├── UI/              SwiftUI 页面与复用展示组件
├── Data/            领域模型、SwiftData 模型、存储与导出
├── Services/        业务流程与可注入依赖
├── Networking/      WeRead 与 OpenAI 兼容接口客户端
├── Security/        Keychain 存储
└── ReadCopilotTests/
```

### 核心职责

| 组件 | 职责 |
| --- | --- |
| `LibraryStore` | 阅读主页状态、书架/画像同步、本地缓存加载 |
| `WeReadGateway` | WeRead 网关请求构造与重试 |
| `WeReadNotesService` | 全量笔记获取与 JSON 解析 |
| `AnalysisService` | LLM 配置、提示词构造与分析执行 |
| `TopicExtractionService` | 批量主题提取与 JSON 解析 |
| `KnowledgeStore` | SwiftData 知识持久化、检索与主题过滤 |
| `DiagnosisModel` | 分析 UI 状态、进度与本地通知 |
| `ReportExporter` | Markdown 与 PDF 报告导出 |

`Services` 依赖 `KeyStore` 协议，因此核心流程无需真实 Keychain 也可测试。
网络客户端依赖可注入的 `NetworkSession` 协议，便于做确定性测试。

## 开发

当 `project.yml` 变化时，重新生成 Xcode 工程：

```bash
xcodegen generate
```

运行测试：

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

- 当前知识检索以结构化全文搜索与主题过滤为主，尚未引入本地向量嵌入。
- 阅读主页可展示哪些指标，受 WeRead 网关返回字段约束。
- 主题提取需要已配置且可访问的 LLM；即使尚未提取主题，已导入笔记仍可正常检索。

## License

MIT
