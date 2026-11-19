# ReadCopilot

<p align="center">
  <strong>Turn your WeRead highlights into a private, searchable, AI-assisted reading workspace.</strong>
</p>

<p align="center">
  Built with SwiftUI • Local-first • BYOK • Works with cloud LLMs or local Ollama
</p>

<p align="center">
  <a href="./README.zh-CN.md">简体中文</a>
</p>

ReadCopilot helps serious readers move from scattered highlights to reusable knowledge.
Sync your WeRead library, review your reading patterns, export your notes, and run
traceable AI analysis without giving up control of your data.

## Why ReadCopilot

- **Local-first by design** — your books, notes, reports, and knowledge items stay on device.
- **Bring your own key** — connect your own WeRead key and your preferred LLM provider.
- **Readable output, not just raw exports** — turn highlights and notes into Markdown, PDF, and structured knowledge.
- **Traceable AI workflows** — keep source-book provenance from note import to topic extraction.
- **Flexible model setup** — use OpenAI-compatible APIs or keep processing local with Ollama.

## What you can do

### 1) Understand your reading life
ReadCopilot turns synced WeRead data into a dashboard with:

- reading time and reading-day summaries
- completion rate and daily averages
- shelf composition and category distribution
- reading-hour heatmaps
- recently active books

### 2) Analyze books with Copilot workflows
Choose a single book, a category, or your whole library, then pick from eight report templates:

- **Note checkup** — seven-factor grade, KPI, evidence, and an improvement plan
- **Reading coach** — observable note habits plus three rewriting suggestions
- **Critical reading** — arguments, assumptions, counterexamples, and blind spots
- **Action learning** — RIA breakdown, action list, and a seven-day experiment
- **Post-reading loop** — three-sentence summary, one A2 action, Feynman retell, and review questions
- **Cross-book synthesis** — comparison, shared themes, consensus, conflicts, and writing topics
- **Reading method prescription** — a 2–3 method combo matched to purpose and book type
- **Book review workshop** — an editable long-form review with citation IDs

Every note-based template first runs a **local evidence pass**: counts, character-bucket depth mix, chapter density, seven grading factors, ranked evidence IDs, and a method prescription. The configured LLM receives those numbers and explains them; it never recalculates the grade. See [REPORT_TEMPLATES.md](./REPORT_TEMPLATES.md) for the full evidence contract and metric definitions.

### 3) Export notes you can actually reuse
For a selected book, you can:

- export all highlights and notes as Markdown
- export a **single-file HTML notebook** grouped by chapter, generated locally without an LLM
- export AI analysis as Markdown, PDF, or a self-contained HTML report
- keep the local-metrics appendix, citation IDs, and metric definitions in every export
- keep source context attached to imported knowledge

### 4) Build a searchable knowledge base
Import notes into SwiftData and work with:

- de-duplicated note storage
- full-text search across titles, excerpts, and notes
- topic extraction with 1–3 AI-generated topic labels per item
- traceable `topic -> source text -> book` relationships

## Privacy and data flow

ReadCopilot is built for readers who want AI assistance without surrendering ownership.

```text
WeRead API -> LibraryStore -> SwiftData (books and profile)
WeRead notes -> KnowledgeStore -> SwiftData (KnowledgeItem)
KnowledgeItem -> configured LLM -> topic labels
Selected notes -> configured LLM -> analysis report
```

- WeRead keys and cloud-model API keys are stored only in the device Keychain.
- Synced books, notes, reports, and knowledge items are persisted locally in SwiftData.
- Note metrics, grading, method prescriptions, and HTML rendering run on device.
- There is no app-operated cloud sync layer or telemetry pipeline.
- Before analysis runs, the app asks for consent because selected notes are sent to your configured LLM endpoint. The reading-method template can run with book metadata and reading purpose only.
- HTML reports embed the existing WeRead cover URL as a `data:` URI; no additional service is called. If the cover cannot be fetched, the report uses a clearly labeled placeholder.
- If you use Ollama, analysis and topic extraction can stay on your local machine.

## Requirements

- Xcode 16+
- macOS 14+ for development and the macOS app target
- iOS 17+ for the iOS target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- A WeRead Agent API key beginning with `wrk-...`
- One of the following:
  - an OpenAI-compatible API key and endpoint
  - [Ollama](https://ollama.com/) running locally

## Quick start

```bash
# Install XcodeGen once
brew install xcodegen

# Regenerate the Xcode project after changing project.yml
xcodegen generate

# Open the app in Xcode
open ReadCopilot.xcodeproj
```

## First-run setup

1. Open **Settings** and enter your WeRead `wrk-...` API key.
2. Select **Verify and Save**.
3. Configure either:
   - a cloud **Reading Analysis Model** with key, base URL, and model name, or
   - **Local Ollama**.
4. If using Ollama, start it and install a model:

   ```bash
   ollama serve
   ollama pull qwen2.5
   ```

5. Return to **Settings**, scan local installed models, select a model, then test and save the connection.
6. Open **Reading Home** and select **Sync**.
7. Open **Copilot** to analyze a book, export highlights, or import notes into the knowledge base.
8. Open **Knowledge Base** and run **AI Extract Topics** to organize imported items into topic labels.

## Architecture

```text
ReadCopilot/
├── App/             Application entry point
├── UI/              SwiftUI screens and reusable presentation components
├── Data/            Domain models, SwiftData models, stores, and export
├── Services/        Business workflows with injectable dependencies
├── Networking/      Thin WeRead and OpenAI-compatible API clients
├── Security/        Keychain storage
└── ReadCopilotTests/
```

### Core responsibilities

| Component | Responsibility |
| --- | --- |
| `LibraryStore` | Dashboard state, shelf/profile sync, local cache loading |
| `WeReadGateway` | WeRead gateway request construction and retry |
| `WeReadNotesService` | Full note retrieval and JSON-to-domain parsing |
| `AnalysisService` | LLM configuration, prompt construction, and analysis |
| `NoteMetrics` | Deterministic counts, depth mix, seven-factor grade, evidence ranking, citation IDs |
| `MethodAdvisor` | Diagnosis-to-prescription mapping for reading methods |
| `ReportHTMLBuilder` | Single-file HTML report and local notebook rendering |
| `ReportCoverLoader` | Cover download, downscale, and `data:` URI encoding |
| `TopicExtractionService` | Batched LLM topic extraction and JSON parsing |
| `KnowledgeStore` | SwiftData knowledge persistence, search, and topic filtering |
| `DiagnosisModel` | UI analysis state, progress, local metrics, and local notifications |
| `ReportExporter` | Markdown, PDF, HTML, and local-metrics appendix generation |

`Services` depend on the `KeyStore` protocol so core workflows can be tested without the real Keychain.
Network clients depend on an injectable `NetworkSession` protocol for deterministic tests.

## Development

Regenerate the Xcode project whenever `project.yml` changes:

```bash
xcodegen generate
```

Run the test suite:

```bash
xcodebuild \
  -project ReadCopilot.xcodeproj \
  -scheme ReadCopilot \
  -destination 'platform=macOS,arch=arm64' \
  test
```

Build the iOS target:

```bash
xcodebuild \
  -project ReadCopilot.xcodeproj \
  -scheme ReadCopilot \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  build
```

## Current limitations

- Knowledge retrieval currently focuses on structured full-text search and topic filtering rather than local embeddings.
- The WeRead gateway contract determines which reading metrics are available to the dashboard.
- Topic extraction requires a configured, reachable LLM, although imported notes remain searchable before extraction.
- Note grades are diagnostic proxies for the current notebook, not a measure of reading ability and not a promise of improvement.
- A2 actions and review questions are marked 待补录 until you record real outcomes.

## Privacy and support

- [Privacy Policy](./PRIVACY.md)
- [Support and FAQ](./SUPPORT.md)

## License

MIT
