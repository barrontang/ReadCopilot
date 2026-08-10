# ReadCopilot — PRD v1.0(定稿)

> 微信读书重度用户的**个人阅读教练**。用户自带 key(BYOK),app 拉取全部阅读数据,本地构建阅读知识库,用用户自己的 LLM 诊断笔记写作、提出改进建议,并沉淀为可复用的个人知识资产。Mac 优先,一套 SwiftUI 代码后续覆盖 iOS。

---

## 0. 产品定义
**定位:阅读教练(骨) + 个人知识资产库(肉) + 阅读仪表盘(皮)。**
核心动词是"改进"与"沉淀",不是"看"。纯数据仪表盘会输给微信读书自带功能,故不作为核心。

一句话:**ReadCopilot 是微信读书的"分析副驾"——帮你把散落的阅读与笔记,变成读得更好、写得更好的能力和可复用的知识资产。**

## 1. 目标用户
硬门槛(AND):注册微信读书 + 持有 `wrk-` key + 愿意填 LLM key。
真实画像:重度阅读者、有笔记习惯、有自我提升诉求。
定性:**小众精品工具**,非大众 app。据此把教练做硬核,不讨好所有人。

## 2. 差异化价值(微信读书没有的,按优先级)
1. **笔记写作诊断**(MVP 核心):分析思维模式(摘抄/复述/批判型),指出盲区,给带证据的写作升级建议。
2. **笔记→知识资产**(Should):笔记本地全文可搜索 + LLM 主题打标,沉淀为知识卡片/写作素材。
3. **阅读行为诊断**(Should):完读率、囤书、品类偏食、时段-效率错配 → 可执行调整。
4. **跨书主题关联**(Could):发现反复出现的思考主线。
> 记笔记的目的已确认:**当下思考/输出 + 日后重读检索 两者都要,先做写作诊断。**

## 3. 决策记录(已拍板)
- 用户范围:仅持 `wrk-` key 的微信读书用户。
- weread key:BYOK,Keychain 存储,不落明文。
- LLM key:BYOK,OpenAI 兼容接口。**默认 DeepSeek,支持切换本地 Ollama**;任意 OpenAI 兼容 base_url 均可。
- 后端:无。纯客户端。
- **平台:Mac 优先,SwiftUI 多平台单一代码库,后续出 iOS。最低 macOS 14 / iOS 17(SwiftData)。**
- 知识图谱:**本期 Won't**,待笔记数据沉淀后再做(它是呈现层,非地基)。

## 4. 功能范围(MoSCoW)
| 优先级 | 功能 |
|---|---|
| **Must** | 填 key + 验证;拉画像;拉全量笔记落库(分批限速断点续传);**选一本书→笔记写作诊断+3条建议+1个延伸追问** |
| **Should** | 阅读行为诊断报告;笔记本地全文搜索;主题标签(LLM 打标) |
| **Could** | 跨书主题关联;书单推荐(recommend/similar + LLM 二筛) |
| **Won't(本期)** | 知识图谱可视化;社交/对比;云同步;书籍全文阅读器 |

## 5. 数据源(已验证,skill_version=1.0.4)
入口:`POST https://i.weread.qq.com/api/agent/gateway`,Header `Authorization: Bearer <wrk-key>`,body 平铺参数 + `skill_version`。

| 数据 | api_name | 关键参数 |
|---|---|---|
| 阅读统计 | `/readdata/detail` | mode: weekly/monthly/annually/overall |
| 笔记本概览 | `/user/notebooks` | count, lastSort |
| 某书划线 | `/book/bookmarklist` | bookId |
| 某书个人想法 | `/review/list/mine` | bookid, synckey, count |
| 书架 | `/shelf/sync` | — |
| 书籍信息 | `/book/info` | bookId |
| 章节目录 | `/book/chapterinfo` | bookId |
| 搜索 | `/store/search` | keyword, scope, count |
| 个性推荐 | `/book/recommend` | count, maxIdx |
| 相似书 | `/book/similar` | bookId, count |

展示规范:时间戳→YYYY-MM-DD;时长(秒)→"X小时Y分钟";字段释义以 skill 说明为准,禁止直译。

## 6. 关键流程(MVP)
```
首次:启动 → 引导填 weread key → 一键验证(真实调 /readdata/detail)
     → 后台全量同步(画像+书架+逐书笔记,分批/限速/断点续传/进度可见)→ Dashboard

主循环(留存引擎):
  Dashboard 一句话诊断 → 点一本有笔记的书
  → [明示:将把 N 条笔记发送给 <provider>] 确认
  → LLM 输出:①思考模式判定(引用你原话为证据)②3条写作改进(含改写示范)③1个延伸追问
  → 可保存建议 / 复制笔记卡片
```

## 7. LLM 分析设计(产品成败核心)
- **上下文结构化**:喂给模型的不只是笔记文本,还含书名/品类/阅读时长/划线数/想法数/完读状态。
- **输出结构化 + 可证伪**:禁止"很有深度"类废话;强制格式 = 模式判定 + 引用原话证据 + 具体改写示范。
- **证据强制**:每条诊断必须引用用户原笔记,否则视为无效输出。
- **Provider 抽象**:统一 OpenAI 兼容 `/chat/completions`;默认 DeepSeek(`https://api.deepseek.com/v1`),可切 Ollama(`http://localhost:11434/v1`)或任意兼容端点。一份 `LLMClient` 代码适配全部。
- **质量优先原则**:MVP 阶段用 DeepSeek 验证"诊断是否值得做";确认价值后再评估是否为省钱/隐私切本地模型。不在 MVP 为免费牺牲核心体验。

## 8. LLM Provider 选项参考
| 方案 | 成本 | 中文 | 隐私 | 备注 |
|---|---|---|---|---|
| DeepSeek(默认) | 极低 | 强 | 数据出境至 DeepSeek | OpenAI 兼容,首选验证质量 |
| 本地 Ollama(Qwen 等) | 免费 | 中-良 | 最佳(不出本机) | Mac 端优势,效果依模型大小 |
| OpenAI gpt-4o(-mini) | 中 | 良 | 出境 | 生态标准 |
| Gemini / GLM / OpenRouter | 部分免费额度 | 良 | 出境 | 额度政策易变,需用户自查 |

## 9. 隐私与安全
- 两 key 仅 Keychain(`AccessibleAfterFirstUnlockThisDeviceOnly`),不进 UserDefaults/明文文件,不上传。
- 笔记默认仅本地;走 LLM 分析前**明示"将发送 N 条笔记给 <provider>"**,默认关闭自动分析。
- 范围可选:可只发某本书、可勾选排除私密笔记。
- 无遥测:app 自身不收集任何用户数据、不打点。
- 设置页提供"清除全部本地数据 + key"。

## 9b. 界面设计规范(UI/UX)
**气质定案(默认,可改):Things 3 / Reeder 路线——macOS 原生、暖中性色、书卷气。**
对标参考:Things 3(留白与原生质感)、Reeder/NetNewsWire(三栏阅读式)、Bear(笔记卡片与中文排版)、GitHub 热力图(时段可视化)。刻意避开 Linear 式冷科技感——阅读 app 该有纸感。

设计原则:
1. **三栏骨架**:导航侧栏(仪表盘/书库/诊断/设置) | 列表栏(书单+搜索) | 详情栏(书详情/诊断报告)。
2. **中文排版是命门**:正文 PingFang SC,标题可配衬线(思源宋体/Songti);行高 1.6–1.8,字号克制。
3. **单一强调色**:暖中性灰白底 + 一个强调色(墨绿或赭石,呼应书卷);忌多色。
4. **数据可视化极简**:Swift Charts,去网格线/边框、弱化坐标轴,只留数据。
5. **诊断报告像一封信,不像仪表盘**:教练建议用可阅读的叙述体,而非评分卡。这是产品灵魂。

MVP 四屏:
- 仪表盘:顶部一句话诊断(教练口吻)+ 画像(时长趋势/品类雷达/时段热力图)。
- 书库:有笔记的书列表,可搜索,显示笔记数。
- 诊断:选书 → 明示数据出境 → 叙述体诊断报告 → [生成 PDF]。
- 设置:两个 key(已实现)。

## 9c. 分析报告 PDF + 自动索引
**报告存储定案(默认,可改):app 内管理 + 可导出到用户文件夹。**

PDF 生成:
- macOS 用 PDFKit / SwiftUI `ImageRenderer` + `NSPrintOperation` 渲染排版精良的 PDF。
- 模板:封面(书名+日期+封面图)→ 阅读数据摘要 → 思考模式诊断 → 写作建议 → 延伸追问 → 附录(本次分析的笔记原文)。

自动索引(双层,禁止只丢散文件):
```
<用户选定目录>/ReadCopilot/Reports/
├── index.json                    ← 机器可读索引(SwiftData 镜像导出)
├── 2026-08-10_三生万物_诊断.pdf
└── ...
```
- **SwiftData 存 `Diagnosis`**(书/日期/模式判定/建议摘要/PDF 路径),app 内按 书/日期/关键词/思考模式 检索。
- 同步导出 `index.json`,脱离 app 也可被外部工具(含 Hermes)检索。
- 文件命名 `日期_书名_类型.pdf`,天然可排序。
- 真检索靠 SwiftData;文件夹与 index.json 是可移植产物。
- macOS 导出到用户目录需用安全作用域书签(security-scoped bookmark)持久化访问权限。

## 10. 技术架构
```
ReadCopilot (SwiftUI 多平台: macOS 14+ / iOS 17+)
├─ Networking
│   ├─ WeReadGateway   (URLSession + async/await)
│   └─ LLMClient       (OpenAI 兼容 chat/completions + embeddings)
├─ Persistence: SwiftData (Book, Note, ReadStat, Diagnosis)
├─ Security: Keychain (weread key, llm key/baseURL/model)
├─ Analysis
│   ├─ ProfileBuilder  (纯 Swift 统计画像)
│   └─ Coach           (LLM prompt 编排 → 诊断/建议)
└─ UI: Dashboard / Library / BookDetail(诊断) / Settings
```

## 11. 数据模型(SwiftData 草案)
- `Book`: bookId, title, author, category, cover, finished, readTime, noteCount
- `Note`: id, bookId, chapterUid, type(划线/想法/书签), content, createTime
- `ReadStat`: mode, baseTime, totalReadTime, readDays, preferCategory[], preferTime[24]
- `Diagnosis`: id, bookId, createdAt, mode(模式判定), suggestions[], followUpQuestion, saved(Bool)

## 12. 成功指标(MVP)
1. **激活率**:填 key 用户中完成 ≥1 次笔记诊断的比例(目标 ≥60%)。
2. **建议采纳感**:诊断后点"保存/有用"的比例(建议质量唯一诚实信号)。

## 13. 非目标
不做:社交/PK、云同步、多账号、Android、书籍全文阅读器、替代微信读书。

## 14. 风险登记
| 风险 | 等级 | 处置 |
|---|---|---|
| 网关非公开 API,上架可能被拒/被封 [FRAME→REALITY, LOW,非法律意见] | 高 | 自用/TestFlight 先行;上架前求证授权 |
| LLM 建议流于废话 [INFERRED, MED] | 高 | 结构化 prompt + 证据强制 + 默认用 DeepSeek 验证 |
| 首次全量同步慢/频控 [INFERRED, MED] | 中 | 分批 + 限速 + 断点续传 + 进度可见 |
| 接口字段变更 [INFERRED, MED] | 中 | 容错解析 + upgrade_info 处理 |
| 免费/小模型诊断质量不足 [INFERRED, MED] | 中 | MVP 不赌免费;Provider 可切换 |
| 用户不想被诊断笔记 [INFERRED, post-hoc, MED] | 中 | 诊断与"整理/炼金"均可选 |

## 15. 里程碑
- **M0**:Xcode 多平台工程可编译(Mac 跑起来)。
- **M1(MVP)**:填 key→画像→选书→笔记诊断闭环(默认 DeepSeek)。
- **M2**:全量同步 + 本地笔记搜索 + 阅读行为诊断报告。
- **M3**:主题打标 + 跨书关联。
- **M4**:知识图谱(呈现层)。
