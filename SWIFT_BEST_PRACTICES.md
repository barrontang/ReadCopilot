# ReadCopilot - Swift Architecture & Best Practices Guide

## 📐 Architecture Overview

ReadCopilot follows a **Clean Architecture** pattern with clear separation of concerns:

```
┌─────────────────────────────────────────┐
│           UI Layer (SwiftUI)             │
│  RootView, DashboardView, SettingsView   │
└────────────────┬────────────────────────┘
                 │ @Published
┌────────────────▼────────────────────────┐
│      Application Layer (@MainActor)      │
│  LibraryStore, DiagnosisModel            │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│    Domain Layer (Business Logic)         │
│  AnalysisTemplate, ReadingNote           │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│    Data Layer (Persistence & Networking)│
│  PersistenceManager, WeReadGateway,      │
│  LLMClient, Keychain                     │
└─────────────────────────────────────────┘
```

### Key Principles

1. **Unidirectional Data Flow**: UI → ViewModel → Service → Data
2. **@MainActor Protection**: All UI updates happen on main thread
3. **Dependency Injection**: Pass dependencies rather than accessing singletons
4. **Async/Await**: Modern concurrency, no completion handlers
5. **BYOK Design**: Never store or log sensitive credentials

---

## 🔐 Security Best Practices

### Keychain Usage

✅ **DO**: Always store secrets in Keychain
```swift
// ✅ Correct
Keychain.set("my-secret-key", for: .wereadAPIKey)
```

❌ **DON'T**: Store secrets in UserDefaults or environment
```swift
// ❌ Wrong
UserDefaults.standard.set("my-secret-key", forKey: "apiKey")
```

### API Key Handling

✅ **DO**: Use actual key in Authorization header
```swift
// ✅ Correct
req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
```

❌ **DON'T**: Use placeholders
```swift
// ❌ Wrong - won't authenticate!
req.setValue("Bearer ******", forHTTPHeaderField: "Authorization")
```

### Data Privacy

✅ **DO**: 
- Ask user permission before sending data to LLM
- Show what data is being analyzed
- Provide one-click delete-all
- No telemetry without consent

❌ **DON'T**:
- Send data to external services automatically
- Store API responses in logs
- Persist keys in UserDefaults
- Collect usage analytics without disclosure

---

## 🧪 Testing Strategy

### Unit Tests

Test each layer independently:

```swift
// ❌ Don't: Test the whole app
func testAppWorks() { ... }

// ✅ Do: Test individual functions
func testWeReadGatewayAuthorizationHeader() { ... }
func testDiagnosisPromptBuilding() { ... }
```

### Using MockURLSession

```swift
class WeReadGatewayTests: XCTestCase {
    func testValidateKey() async throws {
        let mockSession = MockURLSession()
        let gateway = WeReadGateway(apiKey: "wrk-test", session: mockSession)
        
        // Setup mock response
        mockSession.mockData = validJSON
        mockSession.mockResponse = HTTPURLResponse(statusCode: 200)
        
        // Test
        let result = try await gateway.validateKey()
        XCTAssertTrue(result)
    }
}
```

### Test Files

- `WeReadGatewayTests.swift`: API client logic
- `LLMClientTests.swift`: LLM integration
- `DiagnosisModelTests.swift`: Diagnosis engine
- `PersistenceManagerTests.swift`: Data storage
- `KeychainTests.swift`: Security

---

## 🎯 Concurrency Patterns

### Proper Async Task Management

✅ **DO**: Use TaskGroup for concurrent work
```swift
// ✅ Correct: Concurrent book processing
private func diagnose(books: [LibraryBook]) async {
    var results: [DiagnosisResult] = []
    
    await withThrowingTaskGroup(of: DiagnosisResult.self) { group in
        for book in books {
            group.addTask {
                try await analyzeBook(book)
            }
        }
        
        for try await result in group {
            results.append(result)
        }
    }
}
```

❌ **DON'T**: Sequential loops for parallel work
```swift
// ❌ Slow: Processes one book at a time
for book in books {
    results.append(try await analyzeBook(book))  // Waits for each one
}
```

### Cancellation Support

```swift
// ✅ Store task handle for cancellation
var analysisTask: Task<Void, Never>?

func startAnalysis() {
    analysisTask = Task {
        try await diagnosisModel.diagnose(...)
    }
}

func cancelAnalysis() {
    analysisTask?.cancel()
}
```

---

## 📊 Data Persistence Patterns

### Using SwiftData

✅ **DO**: Use SwiftData for complex relationships
```swift
@Model
final class Book {
    @Attribute(.unique) var id: String
    @Relationship(deleteRule: .cascade, inverse: \Note.book)
    var notes: [Note] = []
}
```

✅ **DO**: Use PersistenceManager singleton
```swift
try await PersistenceManager.shared.saveBooks(books)
let books = try await PersistenceManager.shared.fetchBooks()
```

❌ **DON'T**: Direct ModelContext usage everywhere
```swift
// ❌ Scattered logic
let context = ModelContext(container)
context.insert(book)
try context.save()  // Repeated in 10 places
```

---

## 🔄 Error Handling

### Current: Simple Error Types

```swift
enum WeReadError: LocalizedError {
    case missingKey
    case http(Int)
    case gateway(code: Int, message: String)
    case decoding(String)
    
    var errorDescription: String? { ... }
}
```

### Future: Result Type with Retry

```swift
struct APIClient<T> {
    func call() async -> Result<T, WeReadError> {
        for attempt in 1...3 {
            do {
                return .success(try await performRequest())
            } catch {
                if attempt == 3 { return .failure(error as! WeReadError) }
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
            }
        }
        return .failure(.unknown)
    }
}
```

---

## 🎨 UI Patterns

### SwiftUI Best Practices

✅ **DO**: Use @StateObject in root, @State in children
```swift
struct RootView: View {
    @StateObject private var store = LibraryStore()  // Owner
    
    var body: some View {
        ChildView(store: store)  // Pass down
    }
}

struct ChildView: View {
    @ObservedReferencedObject var store: LibraryStore
    @State private var isExpanded = false  // Local state
}
```

✅ **DO**: Extract subviews for reusability
```swift
struct BookRow: View {
    let book: LibraryBook
    
    var body: some View { ... }
}
```

❌ **DON'T**: Capture store in closures
```swift
// ❌ Memory leak risk
Button("Delete") {
    store.deleteBook(id)  // Captures store
}
```

---

## 📝 Code Organization

### File Structure

```
ReadCopilot/
├── App/
│   └── ReadCopilotApp.swift          # @main entry point
├── Networking/
│   ├── WeReadGateway.swift           # WeChat Reading API
│   └── LLMClient.swift               # LLM integration
├── Security/
│   └── Keychain.swift                # Secure storage
├── Data/
│   ├── LibraryStore.swift            # ViewModel
│   ├── DiagnosisModel.swift          # Analysis engine
│   ├── AnalysisModels.swift          # Domain models
│   ├── PersistenceModels.swift       # SwiftData models
│   ├── PersistenceManager.swift      # Storage abstraction
│   └── ReportExporter.swift          # Export logic
├── UI/
│   ├── RootView.swift                # Main navigation
│   ├── DashboardView.swift           # Home screen
│   ├── DiagnosisView.swift           # Analysis UI
│   ├── BookListView.swift            # Books list
│   ├── KnowledgeGraphView.swift      # Knowledge graph
│   ├── SettingsView.swift            # Configuration
│   └── Theme.swift                   # Design system
└── Info.plist
```

### MARK Organization

```swift
// MARK: - Properties
@Published var loading = false

// MARK: - Initialization
init() { ... }

// MARK: - Public Methods
func syncAll() async { ... }

// MARK: - Private Methods
private func parseProfile(_ j: [String: Any]) { ... }

// MARK: - Helpers
private func fmtDuration(_ sec: Int) -> String { ... }
```

---

## 🚀 Performance Guidelines

### Network Request Optimization

✅ **DO**: Use concurrent requests
```swift
async let profileJSON = gw.readData()
async let shelfJSON = gw.shelf()
let (profile, shelf) = try await (profileJSON, shelfJSON)
```

❌ **DON'T**: Sequential requests
```swift
let profile = try await gw.readData()
let shelf = try await gw.shelf()  // Waits for profile first
```

### Memory Management

✅ **DO**: Use weak self in closures
```swift
Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
    self?.updateUI()
}
```

✅ **DO**: Cancel background tasks on dealloc
```swift
deinit {
    analysisTask?.cancel()
}
```

---

## 📚 Documentation Standards

### Required Documentation

```swift
/// Fetches all books from the WeChat Reading library.
/// - Parameter mode: Time range ("weekly", "monthly", "annually", "overall")
/// - Returns: Dictionary with book metadata and statistics
/// - Throws: WeReadError if network fails or API returns error
func shelf(mode: String = "overall") async throws -> [String: Any]
```

### Code Comments

Use comments for **why**, not **what**:

```swift
// ❌ Don't: Comments repeat what code says
i += 1  // Increment i

// ✅ Do: Comments explain intent
// Limit concurrent book analysis to 3 to avoid rate limiting
let maxConcurrent = 3
```

---

## ✅ Pre-Commit Checklist

Before pushing code:

- [ ] No hardcoded API keys or secrets
- [ ] No `print()` statements (use Logger)
- [ ] All public methods have documentation
- [ ] Unit tests added for new logic
- [ ] No force unwraps (`!`) unless documented
- [ ] All async functions use proper error handling
- [ ] MARK sections organize code
- [ ] Keychain used for all credentials
- [ ] @MainActor used correctly
- [ ] No memory cycles in closures

---

## 🔧 Troubleshooting

### Issue: "API Key Error 401"
**Cause**: Authorization header not including actual key
**Fix**: Verify `weReadGateway.swift` line 42 has `Bearer \(apiKey)`

### Issue: "Data Lost on App Restart"
**Cause**: No SwiftData persistence
**Fix**: Use `PersistenceManager.shared.saveBooks()` after sync

### Issue: "UI Freezes During Diagnosis"
**Cause**: Network calls on main thread
**Fix**: Ensure `@MainActor` on UI class, offload work to background

### Issue: "No Test Coverage"
**Cause**: MockURLSession not available
**Fix**: Use `CoreTests.swift` as template, follow pattern

---

## 📖 Additional Resources

- [Swift Concurrency](https://developer.apple.com/wwdc23/110350)
- [SwiftData](https://developer.apple.com/xcode/swiftdata/)
- [Security Best Practices](https://developer.apple.com/security/)
- [Testing with Swift](https://developer.apple.com/xcode/testing/)
- [SwiftUI App Architecture](https://developer.apple.com/wwdc23/10026)

---

**Last Updated**: September 1, 2026  
**Maintainer**: Swift Expert  
**Version**: 1.0
