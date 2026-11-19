# ReadCopilot 隐私政策 / Privacy Policy

最后更新：2026 年 11 月 18 日 · Last updated: November 18, 2026

ReadCopilot（以下简称“本应用”）是一款本地优先的阅读笔记工作台。本政策说明本应用如何处理你的数据。

ReadCopilot ("the App") is a local-first reading workspace. This policy explains how the App handles your data.

---

## 1. 我们收集哪些数据 / What we collect

**我们不收集、不上传、不存储任何个人数据到开发者服务器。**

- 本应用没有开发者运营的账号系统、云同步服务、分析 SDK 或广告 SDK。
- 本应用不进行跨应用或跨网站追踪，也不使用广告标识符。
- 开发者不会访问你的书籍、笔记、阅读统计或 AI 报告。

**We do not collect, transmit, or store any personal data on developer-operated servers.**

- The App has no developer-operated account system, cloud sync, analytics SDK, or advertising SDK.
- The App does not track you across apps or websites and does not use advertising identifiers.
- The developer has no access to your books, notes, reading statistics, or AI reports.

---

## 2. 数据存储在哪里 / Where your data lives

以下数据仅保存在你的 Mac 上：

- 微信读书书籍、笔记、阅读统计的本地缓存
- 导入知识库的条目、主题标签与来源信息
- 生成的阅读报告、Markdown / PDF / HTML 导出文件
- 应用偏好设置

其中：

- **API 密钥**（微信读书 Agent Key、云端大模型 Key）仅保存在系统钥匙串（Keychain）中，不会写入明文文件或偏好设置。
- **业务数据**使用 SwiftData 存储在应用沙盒内。
- **导出文件**仅写入你通过系统文件选择器指定的位置。

The following data is stored only on your Mac:

- Local cache of WeRead books, notes, and reading statistics
- Knowledge-base items, topic labels, and source references
- Generated reading reports and Markdown / PDF / HTML exports
- App preferences

API keys (WeRead Agent Key and cloud model keys) are stored only in the macOS Keychain. Business data is stored with SwiftData inside the App Sandbox. Exported files are written only to locations you choose in the system file picker.

---

## 3. 网络请求 / Network requests

本应用仅在以下情况发起网络请求：

1. **微信读书同步**：使用你提供的微信读书 Agent Key，直接连接微信读书官方接口，获取你的书架、笔记和阅读统计。
2. **AI 分析**：使用你配置的 OpenAI 兼容接口或本地 Ollama，将你选择分析的笔记内容发送到该服务，以生成报告或主题标签。
3. **封面图片**：生成 HTML 报告时，从微信读书封面地址下载书籍封面并嵌入报告文件。

这些请求由你主动触发，并直接发送到你自己配置的服务端点。开发者不代理、不记录、不存储这些请求。第三方服务如何处理数据，取决于该服务自身的隐私政策。

The App makes network requests only to:

1. **WeRead sync** — using your WeRead Agent Key, directly against WeRead's official API.
2. **AI analysis** — against the OpenAI-compatible endpoint or local Ollama instance you configure.
3. **Book covers** — downloaded from WeRead cover URLs and embedded into HTML reports.

All requests are initiated by you and go directly to endpoints you configure. The developer does not proxy, log, or store them. Third-party processing is governed by those services' own privacy policies.

---

## 4. 数据共享 / Data sharing

我们不出售、不出租、不共享你的数据。除上述你主动触发的网络请求外，本应用不会向任何第三方传输数据。

We do not sell, rent, or share your data. Apart from the user-initiated requests described above, the App transmits nothing to third parties.

---

## 5. 数据删除 / Deleting your data

- 在应用内删除书籍、笔记或知识库条目，即可删除对应本地数据。
- 在“设置”中清除 API 密钥，即可从钥匙串中移除凭据。
- 卸载本应用会一并删除应用沙盒内的数据；钥匙串条目可通过“钥匙串访问”手动删除。

- Delete books, notes, or knowledge items in the App to remove the corresponding local data.
- Clear API keys in Settings to remove credentials from the Keychain.
- Uninstalling the App removes its sandboxed data. Keychain items can be removed with Keychain Access.

---

## 6. 儿童隐私 / Children's privacy

本应用不面向 13 岁以下儿童，也不会有意收集儿童的个人信息。

The App is not directed to children under 13 and does not knowingly collect personal information from children.

---

## 7. 政策变更 / Changes

如果本政策发生实质性变更，我们会更新本页面顶部的日期，并在仓库提交记录中保留变更历史。

If this policy changes materially, we will update the date at the top of this page and keep the change history in the repository.

---

## 8. 联系方式 / Contact

如有隐私相关问题，请通过 GitHub Issues 联系：

<https://github.com/barrontang/ReadCopilot/issues>

For privacy questions, please open an issue at the link above.
