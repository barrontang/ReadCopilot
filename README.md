# ReadCopilot

> A local-first SwiftUI reading workspace for WeRead users: turn highlights and
> notes into searchable, traceable knowledge and AI-assisted reading analysis.

## Features

- **Reading dashboard** - displays WeRead profile statistics, reading time,
  reading days, completion rate, daily average, shelf composition, category
  distribution, reading-hour heatmap, recent books, and clickable drill-down
  detail panels for the main summary cards.
- **Notebook workspace** - caches synced highlights and thoughts locally, then
  presents them in reading-order and calendar modes with book/category filters
  and direct handoff to Copilot or the knowledge base.
- **WeRead synchronization** - uses a user-provided `wrk-...` key to retrieve
  reading data and shelf contents. Successful synchronization is saved locally
  for offline viewing on later launches.
- **Copilot analysis** - supports single-book, category, and library scopes
  with reading-coach, critical-reading, action-learning, synthesis, and
  long-form review templates.
- **Complete note handling** - retrieves highlights and paginates through
  reviews by `synckey`, avoiding silent loss after the first 100 reviews.
- **Export** - exports analysis reports as Markdown or PDF, and exports all
  highlights plus their associated notes from a selected book as Markdown.
- **Knowledge base** - imports notes into SwiftData with de-duplication,
  provides full-text search across book title, source text, and notes, and
  retains source-book provenance.
- **Topic layer** - uses the configured LLM to generate 1-3 topic tags per
  knowledge item, enabling topic filters and a traceable
  **topic -> source text -> book** structure.
- **Local Ollama** - supports OpenAI-compatible cloud APIs and local Ollama.
  Ollama requires no API key; installed models can be discovered in Settings.

## Privacy and data flow

ReadCopilot is local-first and uses BYOK (bring your own key):

```text
WeRead API -> LibraryStore -> SwiftData (books and profile)
WeRead notes -> KnowledgeStore -> SwiftData (KnowledgeItem)
KnowledgeItem -> configured LLM -> topic labels
Selected notes -> configured LLM -> analysis report
```

- WeRead and cloud-model API keys are stored only in the device Keychain.
- Book data, notes, reports, and knowledge items are persisted locally in
  SwiftData. There is no application-operated cloud sync or telemetry.
- Before an analysis request, the UI asks for consent because selected
  highlights and notes are sent to the configured LLM endpoint.
- With Ollama, analysis and topic extraction remain on the local machine.

## Requirements

- Xcode 16+ recommended
- macOS 14+ for development and the macOS target
- iOS 17+ for the iOS target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- A WeRead Agent API key beginning with `wrk-...`
- Either:
  - an OpenAI-compatible API key and endpoint, or
  - [Ollama](https://ollama.com/) running locally

## Quick start

```bash
# Install XcodeGen once
brew install xcodegen

# Generate the project after changing project.yml
xcodegen generate

# Open in Xcode
open ReadCopilot.xcodeproj
```

### First run

1. Open **Settings** and enter your WeRead `wrk-...` API key, then select
   **Verify and Save**.
2. Select either a cloud **Reading Analysis Model** (key, base URL, model) or
   **Local Ollama**.
3. For Ollama, start it and install a model, for example:

   ```bash
   ollama serve
   ollama pull qwen2.5
   ```

   Return to Settings, choose **Scan local installed models**, select a model,
   then test and save the connection.
4. Open **Reading Home** and select **Sync**.
5. In **Copilot**, choose a book and use **Highlights and notes** to export
   all entries or import them into the knowledge base.
6. In **Knowledge Base**, select **AI Extract Topics** to compile imported
   items into filterable topic labels.

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

### Responsibilities

| Component | Responsibility |
| --- | --- |
| `LibraryStore` | Dashboard state, shelf/profile sync, local cache loading |
| `NotebookStore` | Notebook cache loading, per-book note sync, filters, calendar state |
| `WeReadGateway` | WeRead gateway request construction and retry |
| `WeReadNotesService` | Full note retrieval and JSON-to-domain parsing |
| `AnalysisService` | LLM configuration, prompt construction, analysis |
| `TopicExtractionService` | Batched LLM topic extraction and JSON parsing |
| `KnowledgeStore` | SwiftData knowledge persistence, search, topic filtering |
| `DiagnosisModel` | UI analysis state, progress, and local notifications |
| `ReportExporter` | Markdown and PDF report generation |

`Services` use the `KeyStore` protocol so business workflows can be tested
without the real Keychain. Network clients use an injectable `NetworkSession`
protocol for deterministic tests.

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

- Knowledge retrieval is structured full-text and topic filtering. Local vector
  embeddings are intentionally deferred until the knowledge base becomes large
  enough to justify their storage and indexing cost.
- The WeRead gateway contract controls which reading metrics are available.
  The dashboard displays every currently retrieved profile, shelf, category,
  and reading-time metric.
- Topic extraction requires a configured, reachable LLM. Existing imported
  notes remain fully searchable even before topic extraction.

## License

MIT
