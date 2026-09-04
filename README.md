# ReadCopilot

<p align="center">
  <strong>Turn your WeRead highlights into a private, searchable, AI-assisted reading workspace.</strong>
</p>

<p align="center">
  Built with SwiftUI • Local-first • BYOK • Works with cloud LLMs or local Ollama
</p>

<p align="center">
  <a href="/README.zh-CN.md">简体中文</a>
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
Choose a single book, a category, or your whole library, then generate structured analysis with templates such as:

- Reading coach
- Critical reading
- Action learning
- Cross-book synthesis
- Long-form review

### 3) Export notes you can actually reuse
For a selected book, you can:

- export all highlights and notes as Markdown
- export AI analysis as Markdown or PDF
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
- There is no app-operated cloud sync layer or telemetry pipeline.
- Before analysis runs, the app asks for consent because selected notes are sent to your configured LLM endpoint.
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

5. Return to **Settings**, scan local installed models, then test and save the connection.
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
| `TopicExtractionService` | Batched LLM topic extraction and JSON parsing |
| `KnowledgeStore` | SwiftData knowledge persistence, search, and topic filtering |
| `DiagnosisModel` | UI analysis state, progress, and local notifications |
| `ReportExporter` | Markdown and PDF report generation |

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

## License

MIT
