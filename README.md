# ReadCopilot

> **微信读书重度用户的个人阅读教练。**  
> 帮你把散落的阅读、笔记和想法，变成更好的写作能力与可复用的知识资产。

**ReadCopilot** 是一款面向微信读书用户的 **Mac 优先 SwiftUI 应用**。  
它通过用户自带 key（BYOK）拉取微信读书数据，在本地构建阅读知识库，并借助你自己的 LLM 对笔记进行分析、诊断和改进建议输出。

---

## ✨ 这是什么

ReadCopilot 不是另一个"读书统计工具"。  
它更像一个 **阅读副驾**：

- 帮你判断笔记写得好不好
- 帮你识别自己的思维模式
- 帮你把零散笔记沉淀成知识资产
- 帮你发现阅读习惯中的问题
- 帮你把阅读真正转化为输出能力

---

## 🚀 核心能力

### 笔记写作诊断
分析你的笔记属于哪种思维模式，例如：

- 摘抄型
- 复述型
- 批判型

并输出：

- 证据引用
- 诊断结论
- 3 条可执行改进建议
- 1 个延伸追问

---

### 笔记 → 知识资产
支持将笔记本地化管理，并进一步整理为：

- 可全文搜索的知识库
- LLM 主题标签
- 知识卡片
- 写作素材

---

### 阅读行为诊断
帮助你发现阅读习惯中的问题，例如：

- 完读率
- 囤书情况
- 品类偏食
- 阅读时段与效率错配

---

### 跨书主题关联
后续将支持识别你在不同书中反复出现的思考主线。

---

## 🎯 产品定位

- **阅读教练**：核心是"改进"
- **知识资产库**：核心是"沉淀"
- **阅读仪表盘**：核心是"看见"

> ReadCopilot 的重点不是展示数据，而是帮助你把阅读变成更强的思考与写作能力。

---

## 🛠️ 技术栈

- **Swift**
- **SwiftUI**
- **SwiftData**
- **Keychain**
- **URLSession + async/await**
- **Swift Charts**
- **PDFKit / ImageRenderer**

---

## 🔐 隐私优先

ReadCopilot 采用本地优先与 BYOK 设计：

- 微信读书 key 与 LLM key 仅存储于 Keychain
- 默认不上传笔记
- 发送给 LLM 前会明确提示
- 支持只分析单本书
- 支持排除私密笔记
- 不收集遥测数据
- 支持一键清除本地数据

---

## 📦 平台支持

- **macOS 14+**
- **iOS 17+**（规划中）

当前以 **Mac 优先**，后续使用同一套 SwiftUI 代码库扩展到 iOS。

---

## 📋 项目概览

### 架构

```
ReadCopilot/
├─ App/                 应用入口 (ReadCopilotApp.swift)
├─ Data/                数据模型与存储 (LibraryStore, DiagnosisModel)
├─ Networking/          API 客户端 (WeReadGateway, LLMClient)
├─ Security/            Keychain 安全存储
└─ UI/                  SwiftUI 视图 (RootView, SettingsView, Theme)
```

### 工作流程

应用启动时加载 `ReadCopilotApp`，打开 `RootView`。用户在 `SettingsView` 中配置微信读书和 LLM API Key（安全存储在 Keychain）。`LibraryStore` 通过 `WeReadGateway` 同步用户的读书库，解析书籍和阅读统计数据。`DiagnosisModel` 将个别笔记发送给 `LLMClient` 进行分析。结果使用 SwiftData 本地存储。应用展示阅读仪表盘，支持选择特定书籍，触发 LLM 动力的笔记质量诊断。

---

## 🚀 快速开始

### 环境要求

- Xcode 14+
- macOS 14+ (开发环境)
- WeChat Reading API Key (以 `wrk-` 开头)
- LLM API Key (OpenAI、Claude 等)

### 构建与运行

```bash
# 安装 XcodeGen（如已安装可跳过）
brew install xcodegen

# 从 project.yml 生成 Xcode 项目
xcodegen generate

# 用 Xcode 打开项目
open ReadCopilot.xcodeproj

# 或使用命令行构建
xcodebuild -scheme ReadCopilot -destination 'platform=macOS' build
```

### 首次使用

1. 启动应用后，进入 **Settings** 页面
2. 填入 WeChat Reading API Key（`wrk-` 开头）
3. 填入你的 LLM API Key（OpenAI、Claude 等）
4. 点击同步，应用会拉取你的读书库和笔记
5. 选择要诊断的书籍和笔记，应用会给出改进建议

> **注意**：所有 Key 仅存储在本地 Keychain，不会上传到任何服务器。

---

## 🧭 路线图

### M1 — MVP
- 填 key
- 拉画像
- 同步笔记
- 选书诊断
- 输出写作建议

### M2
- 全量同步
- 本地笔记搜索
- 阅读行为诊断报告

### M3
- 主题打标
- 跨书关联

### M4
- 知识图谱呈现层

---

## 🧩 架构概览（详细版）

```text
ReadCopilot
├─ Networking
│  ├─ WeReadGateway
│  └─ LLMClient
├─ Persistence
│  └─ SwiftData
├─ Security
│  └─ Keychain
├─ Analysis
│  ├─ ProfileBuilder
│  └─ Coach
└─ UI
   ├─ Dashboard
   ├─ Library
   ├─ BookDetail
   └─ Settings
```
