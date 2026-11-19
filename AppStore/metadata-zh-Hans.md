# App Store 资料 / App Store Metadata

ReadCopilot 的 Mac App Store 上架资料。所有截图均使用演示数据生成，不包含真实阅读记录或 API Key。

## 基本信息

| 字段 | 值 |
| --- | --- |
| App 名称 | ReadCopilot |
| Bundle ID | `com.readcopilot.ReadCopilot` |
| SKU | `READCOPILOT2026` |
| 主要语言 | 简体中文（zh-Hans） |
| 平台 | macOS |
| 价格 | 免费 |
| 类别 | 效率（Productivity） |
| 年龄分级 | 4+ |
| 版本 | 0.2.0（Build 2） |
| 版权 | Copyright © 2026 Barron Tang |

## 商店文案（简体中文）

**副标题（≤30 字）**

把微信读书划线变成可检索的知识库

**推广文本（≤170 字）**

把散落在微信读书里的划线与想法，整理成可检索、可追溯、可导出的阅读知识库。自带微信读书 Key 与模型 Key，数据留在本机；支持 Markdown、PDF 与单文件 HTML 报告。

**关键词（≤100 字，逗号分隔）**

微信读书,笔记,知识库,AI,阅读,划线,导出,Markdown,PDF,读书笔记,本地优先,效率

**描述**

ReadCopilot 是一款本地优先的阅读笔记工作台，帮助认真阅读的人把微信读书里的划线、想法与阅读统计，整理成可检索、可追溯、可复用的知识。

主要功能：

• 阅读主页 — 汇总累计阅读时长、阅读天数、完读率、日均阅读、阅读时段热力图与书架品类分布。

• Copilot 分析 — 选择单本书、一个类别或整个书库，使用八种报告模板：笔记体检、阅读教练、批判性阅读、行动转化、读后闭环、主题地图、读法处方、书评工坊。

• 本地证据 — 分析前先在设备上计算笔记数量、想法率、章节覆盖、反思密度等确定性指标；大模型只负责解释，不重算等级。

• 可追溯知识库 — 导入的每条知识都保留原文、你的想法与来源图书，支持全文搜索与主题标签。

• 导出与留存 — 导出 Markdown、PDF、单文件 HTML 报告，或按章节生成完整的笔记手册。

隐私与数据：

• 微信读书 Key 与大模型 Key 仅保存在本机钥匙串。

• 图书、笔记、报告与知识条目保存在本地，不使用开发者云同步，也不含广告或追踪 SDK。

• 只有在你主动发起分析并同意后，选中的笔记才会发送到你配置的模型端点；使用 Ollama 时可全程留在本机。

使用前需要自备微信读书 Agent Key（wrk- 开头），以及一个 OpenAI 兼容接口或本地 Ollama。

隐私政策：
https://github.com/barrontang/ReadCopilot/blob/main/PRIVACY.md

使用支持：
https://github.com/barrontang/ReadCopilot/blob/main/SUPPORT.md

**版本更新说明**

首个 Mac App Store 版本：阅读主页、八种 Copilot 分析模板、可追溯知识库，以及 Markdown / PDF / HTML 导出。

## 截图

目录：`AppStore/Screenshots/`

| 文件 | 尺寸 | 内容 |
| --- | --- | --- |
| `01-reading-home.png` | 2880×1800 | 阅读主页 |
| `02-copilot-report.png` | 2880×1800 | Copilot 分析报告 |
| `03-template-gallery.png` | 2880×1800 | 报告模板画廊 |
| `04-knowledge-base.png` | 2880×1800 | 知识库 |

## 审核信息

- 隐私政策 URL：`https://github.com/barrontang/ReadCopilot/blob/main/PRIVACY.md`
- 支持 URL：`https://github.com/barrontang/ReadCopilot/blob/main/SUPPORT.md`
- 营销 URL：`https://github.com/barrontang/ReadCopilot`
- 演示账号：不适用。应用没有账号系统，使用用户自备的微信读书 Key 与模型 Key。
- 审核备注：应用的核心同步功能需要真实微信读书 Agent Key。提交审核前应补充可离线体验的演示模式，或在审核备注中提供测试 Key。
