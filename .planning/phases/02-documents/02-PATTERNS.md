# Phase 2: Documents — Pattern Map

**Mapped:** 2026-04-19
**Files analyzed:** 18 (13 new + 5 modified)
**Analogs found:** 13 / 18 (remaining 5 are Apple-framework bridges with no Phase 1 analog)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| **MODIFY** `Travellify/Models/Document.swift` | model | CRUD | `Travellify/Models/Trip.swift` + existing `Document.swift` placeholder | exact (same file, additive) |
| **MODIFY** `Travellify/App/AppDestination.swift` | navigation enum | request-response | `Travellify/App/AppDestination.swift` (existing `.tripDetail`) | exact (same file, additive case) |
| **MODIFY** `Travellify/ContentView.swift` | router | request-response | `Travellify/ContentView.swift` (existing `navigationDestination` switch) | exact (same file, add case) |
| **MODIFY** `Travellify/Features/Trips/TripDetailView.swift` | view (card wire-up) | request-response | `TripDetailView.swift` (existing placeholder `SectionCard`) | exact |
| **MODIFY** `Travellify/Features/Trips/TripListView.swift` *(only if trip cascade file-cleanup hook lands here)* | view | CRUD | `TripListView.swift` `confirmationDialog` delete flow | exact |
| **NEW** `Travellify/Features/Documents/DocumentListView.swift` | view (screen) | CRUD | `Travellify/Features/Trips/TripListView.swift` | exact (role + flow match) |
| **NEW** `Travellify/Features/Documents/DocumentRow.swift` | view (row) | presentation | `Travellify/Features/Trips/TripRow.swift` | exact |
| **NEW** `Travellify/Features/Documents/EmptyDocumentsView.swift` | view (empty state) | presentation | `Travellify/Features/Trips/TripEmptyState.swift` | exact |
| **NEW** `Travellify/Features/Documents/DocumentViewer.swift` | view (fullScreenCover) | file-I/O read + presentation | `TripEditSheet.swift` (sheet lifecycle only); PDFView body has **no analog** (UIViewRepresentable + PDFKit) | partial — chrome from Phase 1, body new |
| **NEW** `Travellify/Features/Documents/Import/ScanView.swift` | bridge (UIViewControllerRepresentable) | event-driven (delegate) | **no analog** — first UIViewControllerRepresentable in codebase | no-analog (use RESEARCH.md Pattern 2) |
| **NEW** `Travellify/Features/Documents/Import/PhotosImporter.swift` | bridge + importer pipeline | file-I/O write | **no analog** — first PhotosPicker use | no-analog (use RESEARCH.md Pattern 3) |
| **NEW** `Travellify/Features/Documents/Import/FilesImporter.swift` | bridge (UIViewControllerRepresentable) | file-I/O write | **no analog** — first UIDocumentPickerViewController bridge | no-analog (use RESEARCH.md Pattern 4) |
| **NEW** `Travellify/Services/FileStorage.swift` | utility (domain service) | file-I/O | `Travellify/Features/Trips/TripPartition.swift` (enum + static methods shape only) | role-only (shape-match, not semantics) |
| **NEW** `Travellify/Shared/DocumentKind.swift` *(or inline in `Document.swift`)* | model enum | — | none — enum with String raw value (trivial) | no analog needed |
| **NEW** `TravellifyTests/FileStorageTests.swift` | test | file-I/O | `TravellifyTests/PartitionTests.swift` | role-match (utility test) |
| **NEW** `TravellifyTests/DocumentTests.swift` | test | CRUD | `TravellifyTests/TripTests.swift` | exact |
| **NEW** `TravellifyTests/ImportTests.swift` | test | file-I/O + CRUD | `TravellifyTests/TripTests.swift` (SwiftData harness only) | partial — harness from Phase 1, happy-path new |
| **NEW** `TravellifyTests/ViewerTests.swift` *(optional; resolve-URL-missing-file case only)* | test | file-I/O | `TravellifyTests/PartitionTests.swift` | role-match |

---

## Pattern Assignments

### MODIFY `Travellify/Models/Document.swift` (model, CRUD)

**Analog:** `Travellify/Models/Trip.swift` + existing `Document.swift` placeholder.

**Existing placeholder to extend** (`Travellify/Models/Document.swift` lines 1–12):
```swift
import SwiftData
import Foundation

extension TravellifySchemaV1 {
    @Model
    final class Document {
        var id: UUID = UUID()
        var trip: Trip?

        init() {}
    }
}
```

**CloudKit-safe default-values pattern from `Trip.swift` lines 6–12 (copy verbatim):**
```swift
@Model
final class Trip {
    var id: UUID = UUID()
    var name: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    var createdAt: Date = Date()
    // ...
}
```
Rule to follow: every new stored property gets a default value. No `@Attribute(.unique)`. No `.deny` delete rule. Enum stored as raw `String` (see RESEARCH.md Pattern 1).

**Imports pattern:** copy from `Trip.swift` lines 1–2 (`import SwiftData` + `import Foundation` only; no `SwiftUI`).

**Final shape (from RESEARCH.md Pattern 1):** add `displayName: String = ""`, `fileRelativePath: String = ""`, `kindRaw: String = DocumentKind.pdf.rawValue`, `importedAt: Date = Date()`, plus computed `kind` accessor. Keep `init()` parameterless to match Phase 1 style (all setters post-init).

---

### MODIFY `Travellify/App/AppDestination.swift` (navigation enum)

**Analog:** same file (`AppDestination.swift` lines 1–6).

**Current state:**
```swift
import Foundation
import SwiftData

enum AppDestination: Hashable {
    case tripDetail(PersistentIdentifier)   // PersistentIdentifier is Hashable + Sendable
}
```

**Pattern:** add one case, same comment style, same `PersistentIdentifier` parameter type. Final enum:
```swift
enum AppDestination: Hashable {
    case tripDetail(PersistentIdentifier)
    case documentList(PersistentIdentifier)
}
```

Consumer-side change belongs to `ContentView.swift` switch (see next entry).

---

### MODIFY `Travellify/ContentView.swift` (router)

**Analog:** `ContentView.swift` lines 10–15 (existing switch).

**Existing switch:**
```swift
.navigationDestination(for: AppDestination.self) { dest in
    switch dest {
    case .tripDetail(let id):
        TripDetailView(tripID: id)
    }
}
```

**Pattern:** add a second `case .documentList(let id):` arm returning `DocumentListView(tripID: id)`. Keep switch exhaustive (no `default`). Navigation push is then driven by `NavigationLink(value: AppDestination.documentList(trip.persistentModelID))` from the TripDetail card.

---

### MODIFY `Travellify/Features/Trips/TripDetailView.swift` (card wire-up)

**Analog:** lines 33–44 (current placeholder Documents card).

**Existing placeholder:**
```swift
HStack(spacing: 12) {
    SectionCard(
        title: "Documents",
        systemImage: "doc.text",
        message: "Documents will appear here."
    )
    SectionCard(
        title: "Packing",
        systemImage: "checklist",
        message: "Your packing list will appear here."
    )
}
```

**`SectionCard` internals to preserve** (lines 71–99):
```swift
private struct SectionCard: View {
    let title: String
    let systemImage: String
    let message: String
    var minHeight: CGFloat = 140
    // VStack(alignment: .leading, spacing: 10) { HStack { Image + Text(title) }; Text(message); Spacer }
    // .padding(16); .background(RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .secondarySystemBackground)))
}
```

**Pattern changes to apply:**
- Keep the `doc.text` SF Symbol (UI-SPEC rule — icon represents the section, not kind).
- Replace the hardcoded `message` with a computed string derived from `trip.documents` count + latest `displayName` (UI-SPEC TripDetail Documents Card table).
- Wrap the card in `NavigationLink(value: AppDestination.documentList(trip.persistentModelID))` OR apply `.contentShape(Rectangle())` + `.onTapGesture { path.append(...) }`. UI-SPEC permits either; `NavigationLink(value:)` matches Phase 1 `TripListView.swift` line 84 pattern and is preferred.

**Reference line 84 for `NavigationLink(value:)` usage:**
```swift
NavigationLink(value: AppDestination.tripDetail(trip.persistentModelID)) {
    TripRow(trip: trip)
}
```

---

### NEW `Travellify/Features/Documents/DocumentListView.swift` (view, CRUD)

**Analog:** `Travellify/Features/Trips/TripListView.swift` (best match — same screen role, CRUD flow, toolbar "+" entry, confirmationDialog delete).

**Imports pattern** (TripListView.swift lines 1–2):
```swift
import SwiftUI
import SwiftData
```

**`@Query` + `@Environment` pattern** (TripListView.swift lines 5–8):
```swift
@Query(sort: \Trip.startDate, order: .forward)
private var allTrips: [Trip]

@Environment(\.modelContext) private var modelContext
```
For documents: use `@Query(filter: #Predicate<Document> { $0.trip?.persistentModelID == tripID }, sort: \Document.importedAt, order: .reverse)` — scoping by injected `tripID: PersistentIdentifier` parameter. See `TripDetailView.swift` line 5 for the `let tripID: PersistentIdentifier` parameter convention.

**View-local `@State` pattern** (TripListView.swift lines 10–11):
```swift
@State private var showNewTrip = false
@State private var tripPendingDelete: Trip?
```
For documents: `@State private var docPendingDelete: Document?`, `@State private var docPendingRename: Document?`, `@State private var renameDraft: String = ""`, `@State private var openedDocument: Document?`, `@State private var isImporting = false`, `@State private var showScanSheet = false`, `@State private var showFilesSheet = false`, `@State private var photosItem: PhotosPickerItem?`.

**Empty-state branch pattern** (TripListView.swift lines 22–44):
```swift
Group {
    if allTrips.isEmpty {
        TripEmptyState()
    } else {
        List { /* sections */ }
        .listStyle(.insetGrouped)
    }
}
.navigationTitle("Trips")
.navigationBarTitleDisplayMode(.large)
```
Copy verbatim; swap `TripEmptyState()` → `EmptyDocumentsView()`, title → `"Documents"`.

**Toolbar "+" pattern** (TripListView.swift lines 47–56): Phase 1 uses a plain `Button`. Phase 2 changes it to a `Menu` per D11:
```swift
ToolbarItem(placement: .navigationBarTrailing) {
    Menu {
        Button { showScanSheet = true } label: { Label("Scan Document", systemImage: "camera") }
        // PhotosPicker as a Menu item — see RESEARCH.md Pattern 3
        Button { showFilesSheet = true } label: { Label("Import from Files", systemImage: "folder") }
    } label: {
        if isImporting { ProgressView().controlSize(.small) }
        else { Image(systemName: "plus") }
    }
    .accessibilityLabel("Add Document")
}
```
Phase 1 accessibility label style (`.accessibilityLabel("New Trip")`, line 54) is the convention to follow.

**Confirmation dialog pattern (copy structure verbatim from TripListView.swift lines 60–79):**
```swift
.confirmationDialog(
    tripPendingDelete.map { "Delete \"\($0.name)\"?" } ?? "",
    isPresented: Binding(
        get: { tripPendingDelete != nil },
        set: { if !$0 { tripPendingDelete = nil } }
    ),
    titleVisibility: .visible,
    presenting: tripPendingDelete
) { trip in
    Button("Delete Trip", role: .destructive) {
        modelContext.delete(trip)
        try? modelContext.save()
        tripPendingDelete = nil
    }
    Button("Cancel", role: .cancel) { tripPendingDelete = nil }
} message: { _ in
    Text("This will also delete all documents, packing items, and activities for this trip.")
}
```
For documents: swap `Trip` → `Document`, `trip.name` → `doc.displayName`, message per UI-SPEC (`"This removes the file from your device and cannot be undone."`), delete body becomes:
```swift
try? FileStorage.remove(relativePath: doc.fileRelativePath)
modelContext.delete(doc)
try? modelContext.save()
```

**Row + context menu pattern (replaces swipeActions):** Phase 1 uses `.swipeActions` (line 87) — Phase 2 must NOT (per D15). Use `.contextMenu` attached to the row inside `ForEach`:
```swift
ForEach(documents) { doc in
    DocumentRow(document: doc)
        .contentShape(Rectangle())
        .onTapGesture { openedDocument = doc }
        .contextMenu {
            Button {
                docPendingRename = doc
                renameDraft = doc.displayName
            } label: { Label("Rename", systemImage: "pencil") }
            Button(role: .destructive) {
                docPendingDelete = doc
            } label: { Label("Delete", systemImage: "trash") }
        }
}
```

**Error handling convention** (TripEditSheet.swift lines 141–146):
```swift
do {
    try modelContext.save()
} catch {
    assertionFailure("modelContext.save failed: \(error)")
}
```
Follow this in Phase 2 for catch blocks; do not surface errors to UI beyond the alerts listed in UI-SPEC "Error States".

**Preview pattern to include** (TripListView.swift lines 97–114):
```swift
#if DEBUG
#Preview("With documents") {
    NavigationStack {
        DocumentListView(tripID: /* from previewContainer */)
    }
    .modelContainer(previewContainer)
}

#Preview("Empty") {
    NavigationStack {
        DocumentListView(tripID: /* fresh-trip ID */)
    }
    .modelContainer(try! ModelContainer(
        for: Trip.self, Destination.self, Document.self,
             PackingItem.self, Activity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    ))
}
#endif
```

---

### NEW `Travellify/Features/Documents/DocumentRow.swift` (view, presentation)

**Analog:** `Travellify/Features/Trips/TripRow.swift` (exact role + flow).

**Full pattern to copy** (TripRow.swift lines 1–37):
```swift
import SwiftUI

struct TripRow: View {
    let trip: Trip

    private var dateRangeText: String { /* DateFormatter, MMM d, yyyy */ }
    private var destinationCountText: String { /* pluralized count */ }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(trip.name)
                .font(.body)
                .foregroundStyle(.primary)
            Text("\(dateRangeText) • \(destinationCountText)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
```

**Apply for DocumentRow:**
- `let document: Document` parameter.
- Leading SF Symbol branch on `document.kind` (`doc.richtext` for `.pdf`, `photo` for `.image`) wrapped in `HStack` around the existing `VStack`; symbol is `.secondary`, `.body` size per UI-SPEC.
- Primary: `document.displayName`, `.body`, `.primary`.
- Secondary: formatted `importedAt` via `.formatted(.dateTime.year().month().day())` (not the `DateFormatter` used in TripRow — UI-SPEC specifies the `FormatStyle` API for this string).
- Keep `.accessibilityElement(children: .combine)`.
- No trailing chevron inside the row itself — UI-SPEC lists "chevron.right" as a trailing accessory; `NavigationLink` would add one automatically, but this row uses `.onTapGesture` (not NavigationLink) because tap opens a fullScreenCover, not a push. Render the chevron manually at trailing edge if the UI-SPEC row table is taken literally.

**Preview pattern** (TripRow.swift lines 39–52): same `List { Row(...) }.modelContainer(previewContainer)` shape.

---

### NEW `Travellify/Features/Documents/EmptyDocumentsView.swift` (view, presentation)

**Analog:** `Travellify/Features/Trips/TripEmptyState.swift` (exact).

**Full pattern to copy** (TripEmptyState.swift lines 1–24):
```swift
import SwiftUI

struct TripEmptyState: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
            Text("No Trips Yet")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.bottom, 8)
            Text("Create your first trip to get started.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No trips yet. Create your first trip to get started.")
    }
}
```

**Substitutions (from UI-SPEC Empty State table):**
- Icon `airplane.departure` → `doc.text` (same `.system(size: 56)`, same `.secondary`).
- Heading `"No Trips Yet"` → `"No Documents Yet"`.
- Body copy → `"Tap + to scan, pick a photo, or import a file."` — UI-SPEC specifies `.subheadline` (not `.body` as in TripEmptyState); apply the UI-SPEC value.
- Rebuild `.accessibilityLabel` with matching copy.

Spacing tokens (32pt bottom of icon, 8pt between heading and body) already match UI-SPEC; keep as-is.

---

### NEW `Travellify/Features/Documents/DocumentViewer.swift` (view, file-I/O + presentation)

**Analog:** no direct screen analog. Chrome and dismissal patterns borrow from `TripEditSheet.swift` (sheet lifecycle). Body rendering has no Phase 1 analog — use RESEARCH.md Pattern 6 for PDFView (UIViewRepresentable) and image ScrollView+MagnificationGesture.

**Dismiss pattern** (TripEditSheet.swift lines 11–12):
```swift
@Environment(\.dismiss) private var dismiss
```
Apply to DocumentViewer; wire to the top-chrome `xmark` button.

**Parameter-injected model pattern** (TripDetailView.swift lines 5, 12–14):
```swift
let tripID: PersistentIdentifier

@Environment(\.modelContext) private var modelContext
@Environment(\.dismiss) private var dismiss

private var trip: Trip? {
    modelContext.model(for: tripID) as? Trip
}
```
For DocumentViewer: take `let document: Document` directly (not an ID) — the fullScreenCover is presented with `.fullScreenCover(item: $openedDocument)` and SwiftUI passes the non-optional Document into the closure.

**File-URL resolution (no analog — use FileStorage):**
```swift
let url = FileStorage.resolveURL(for: document)
// PDF: PDFDocument(url: url)  → PDFKitView(pdf: ...)
// image: UIImage(contentsOfFile: url.path) → Image(uiImage:) in ScrollView
```

**Error-body pattern (no analog — new):** per UI-SPEC Error States, when `FileManager.fileExists(atPath:)` is false OR `PDFDocument(url:)` returns nil OR `UIImage(contentsOfFile:)` returns nil, render a VStack with `exclamationmark.triangle` symbol + `"This document is unavailable."` text. `X` close button must remain functional.

**No shared analog to copy for:**
- `UIViewRepresentable` wrapping `PDFView` — follow RESEARCH.md Pattern 6 verbatim.
- `MagnificationGesture` + double-tap reset — follow RESEARCH.md Pattern 6.

---

### NEW `Travellify/Features/Documents/Import/ScanView.swift` (bridge)

**No Phase 1 analog.** This is the first `UIViewControllerRepresentable` in the codebase.

**Source:** RESEARCH.md Pattern 2 (copy the full `struct ScanView: UIViewControllerRepresentable { ... }` + `Coordinator` including `documentCameraViewController(_:didFinishWith:)`, `documentCameraViewControllerDidCancel`, `documentCameraViewController(_:didFailWithError:)`).

**Coordinator retention rule:** never store Coordinator `weak`; let SwiftUI's `Context` retain it via `makeCoordinator()`.

**File-header import convention from Phase 1** (e.g. `Trip.swift` line 1–2 — `SwiftData` + `Foundation`): for ScanView use:
```swift
import SwiftUI
import VisionKit
import UIKit
```

**Callback shape (from RESEARCH.md):**
```swift
let onFinish: ([UIImage]) -> Void
let onCancel: () -> Void
let onError: (Error) -> Void
```
Callers (`DocumentListView`) handle PDF assembly + background Task + MainActor insert — the bridge itself does zero persistence.

---

### NEW `Travellify/Features/Documents/Import/PhotosImporter.swift` (importer pipeline)

**No Phase 1 analog.**

**Source:** RESEARCH.md Pattern 3 — native SwiftUI `PhotosPicker` + `PhotosPickerItem.loadTransferable(type: Data.self)` + background `Task` + `FileStorage.write(data:to:)` + `@MainActor` hop to insert `Document`.

**Swift 6 concurrency rule (from RESEARCH.md Summary, risk 2):** do NOT capture `Document` or `ModelContext` across the background Task hop. Capture primitives (UUID, relativePath, filename, tripID) and recreate the `Document` inside the `@MainActor` closure by calling `modelContext.model(for: tripID) as? Trip` (same pattern as `TripDetailView.swift` line 13).

**Imports:**
```swift
import SwiftUI
import PhotosUI
import SwiftData
```

---

### NEW `Travellify/Features/Documents/Import/FilesImporter.swift` (bridge)

**No Phase 1 analog.**

**Source:** RESEARCH.md Pattern 4 — `UIViewControllerRepresentable` wrapping `UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image], asCopy: true)`.

**Defensive rule (from RESEARCH.md):** still call `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()` around the copy — no-op on app-container URLs, costs nothing.

**Callback shape:**
```swift
let onPick: (URL) -> Void
let onCancel: () -> Void
```
Caller does `FileManager.copyItem(at: source, to: destination)` inside a detached Task.

**Imports:**
```swift
import SwiftUI
import UIKit
import UniformTypeIdentifiers
```

---

### NEW `Travellify/Services/FileStorage.swift` (utility)

**Analog (shape only):** `Travellify/Features/Trips/TripPartition.swift` — enum-with-static-methods shape.

**TripPartition shape to copy** (lines 3–17):
```swift
import Foundation

enum TripPartition {
    static func upcoming(from trips: [Trip], now: Date = Date()) -> [Trip] { ... }
    static func past(from trips: [Trip], now: Date = Date()) -> [Trip] { ... }
}
```

**Apply for FileStorage:**
```swift
import Foundation
import OSLog

enum FileStorage {
    static let baseDirectory: URL = { /* Application Support/Documents/ */ }()
    static func tripFolder(tripID: UUID) -> URL { ... }
    static func write(data: Data, to relativePath: String) throws { ... }
    static func remove(relativePath: String) throws { ... }
    static func removeTripFolder(tripID: UUID) throws { ... }
    static func resolveURL(for document: Document) -> URL { ... }
}
```

**Design matches D16 (no protocol, no DI, static methods).**

**OSLog pattern (from RESEARCH.md Supporting stack):** use `Logger` (not `print`) in catch blocks inside `remove`; never log absolute paths in release. Not yet used elsewhere in Travellify — introduce it here.

---

### NEW `Travellify/Shared/DocumentKind.swift` (or inline)

**No analog needed.** Trivial enum. Per RESEARCH.md Pattern 1:
```swift
enum DocumentKind: String, Codable, CaseIterable {
    case pdf
    case image
}
```
Placement: inline inside `Travellify/Models/Document.swift` above the `extension TravellifySchemaV1 { ... }` block is consistent with existing pattern (no other standalone enum files exist in `Shared/`).

---

### NEW `TravellifyTests/FileStorageTests.swift` (test, file-I/O)

**Analog:** `TravellifyTests/PartitionTests.swift` (role-match — utility-style tests).

**Imports + test-struct pattern** (PartitionTests.swift lines 1–7):
```swift
import Testing
import SwiftData
import Foundation
@testable import Travellify

@MainActor
struct PartitionTests {
    let container: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Trip.self, Destination.self, Document.self,
                 PackingItem.self, Activity.self,
            configurations: config
        )
    }
    ...
}
```

**Apply for FileStorageTests:**
- Drop the ModelContainer (pure filesystem, no SwiftData needed). Use a per-test scratch dir:
  ```swift
  let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: scratch) }
  ```
- Tests: `write + resolveURL round-trip`, `remove deletes file`, `remove on missing file throws (or is silent — align with D16)`, `tripFolder returns correct path shape`, `removeTripFolder removes subtree`.

**Assertion style (copy `#expect` usage from PartitionTests.swift lines 33–36):**
```swift
#expect(upcoming.contains { $0.name == "Ends Today" })
```

---

### NEW `TravellifyTests/DocumentTests.swift` (test, CRUD)

**Analog:** `TravellifyTests/TripTests.swift` (exact — SwiftData CRUD tests).

**Full harness to copy** (TripTests.swift lines 1–17):
```swift
import Testing
import SwiftData
import Foundation
@testable import Travellify

@MainActor
struct TripTests {
    let container: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Trip.self, Destination.self, Document.self,
                 PackingItem.self, Activity.self,
            configurations: config
        )
    }
    ...
}
```

**Test-case shape to copy** (TripTests.swift lines 19–31 `createTripPersists`):
```swift
@Test func createTripPersists() throws {
    let context = container.mainContext
    let trip = Trip()
    trip.name = "Tokyo"
    trip.startDate = ...
    trip.endDate = ...
    context.insert(trip)
    try context.save()

    let trips = try context.fetch(FetchDescriptor<Trip>())
    #expect(trips.count == 1)
    #expect(trips.first?.name == "Tokyo")
}
```

**Cascade test shape** (TripTests.swift lines 52–76 `deleteTripCascadesToDestinations`) — reuse for Phase 2's `deleteDocumentRemovesRowButOrphansFileIffNotInvokedViaFileStorage` test and `deleteTripCascadesToDocumentsAndFolder`.

**Tests to write (D10 + D16 coverage):**
- `documentPersistsWithDefaultFields`
- `documentDefaultKindIsPDF`
- `documentKindComputedAccessorRoundtrips`
- `deleteDocumentRemovesRow`
- `deleteTripRemovesAssociatedDocuments` (schema-level; file-folder removal test belongs in `ImportTests` or a dedicated cascade test with FileStorage)

---

### NEW `TravellifyTests/ImportTests.swift` (test, file-I/O + CRUD)

**Analog:** `TripTests.swift` harness (SwiftData container) + `FileStorageTests` scratch-dir pattern (above).

**Happy-path shape (no direct analog — combine TripTests harness with FileStorage round-trip):**
```swift
@Test func importFromFilesURLWritesFileAndInsertsDocument() async throws {
    let context = container.mainContext
    let trip = Trip(); trip.name = "T"; context.insert(trip); try context.save()

    // Stage a source file in a scratch dir
    let source = scratch.appendingPathComponent("sample.pdf")
    try Data(/* tiny PDF */).write(to: source)

    // Invoke the importer's core copy+insert function (factor out of the bridge)
    let doc = try await DocumentImporter.importFile(source, into: trip, context: context)

    #expect(doc.kind == .pdf)
    #expect(FileManager.default.fileExists(atPath: FileStorage.resolveURL(for: doc).path))
}
```

**Rule:** test the importer *function* (background Task + FileStorage + insert), not the UIViewControllerRepresentable bridge itself. Bridges are UI infra.

---

## Shared Patterns

### Pattern S1 — CloudKit-safe SwiftData model (all stored props default, optional inverse)

**Source:** `Travellify/Models/Trip.swift` lines 6–29.
**Apply to:** `Travellify/Models/Document.swift` (Phase 2 extension).

```swift
@Model
final class Trip {
    var id: UUID = UUID()
    var name: String = ""
    var startDate: Date = Date()
    // every stored property has a default
    @Relationship(deleteRule: .cascade, inverse: \Document.trip)
    var documents: [Document]? = []   // optional array, CloudKit rule
    init() {}
}
```
Rule: every new stored property on `Document` gets a default; `trip: Trip?` stays optional; no `@Attribute(.unique)`.

### Pattern S2 — `@Query` + view-local `@State` + `Group`/`if` for empty state

**Source:** `Travellify/Features/Trips/TripListView.swift` lines 5–44.
**Apply to:** `DocumentListView`.

```swift
@Query(sort: \Trip.startDate, order: .forward) private var allTrips: [Trip]
@Environment(\.modelContext) private var modelContext
@State private var tripPendingDelete: Trip?

var body: some View {
    Group {
        if allTrips.isEmpty { TripEmptyState() }
        else { List { ... }.listStyle(.insetGrouped) }
    }
    .navigationTitle("Trips")
    .navigationBarTitleDisplayMode(.large)
    .toolbar { ... }
    .confirmationDialog(...) { ... }
}
```

### Pattern S3 — Destructive action: `.confirmationDialog` with `presenting:`

**Source:** `Travellify/Features/Trips/TripListView.swift` lines 60–79.
**Apply to:** `DocumentListView` delete flow (replace `Trip`/`trip.name` with `Document`/`doc.displayName`, replace message copy per UI-SPEC, and call `FileStorage.remove` before `modelContext.delete`).

### Pattern S4 — SwiftData save error handling: `assertionFailure` (no UI surfacing)

**Source:** `Travellify/Features/Trips/TripEditSheet.swift` lines 141–146.
**Apply to:** all Phase 2 `modelContext.save()` catch blocks not explicitly covered by the UI-SPEC Error States table.

```swift
do { try modelContext.save() } catch {
    assertionFailure("modelContext.save failed: \(error)")
}
```

For the four UI-SPEC Error States entries (import failure, viewer file-missing, rename save failure, delete save failure), surface a `.alert` instead of `assertionFailure`.

### Pattern S5 — `NavigationLink(value:)` with `AppDestination`

**Source:** `Travellify/Features/Trips/TripListView.swift` line 84.
**Apply to:** TripDetail Documents card tap target.

```swift
NavigationLink(value: AppDestination.tripDetail(trip.persistentModelID)) {
    TripRow(trip: trip)
}
```

Phase 2 equivalent:
```swift
NavigationLink(value: AppDestination.documentList(trip.persistentModelID)) {
    SectionCard(title: "Documents", ...)
}
```

### Pattern S6 — ModelContainer includes ALL schema types (not just tested ones)

**Source:** `TravellifyApp.swift` lines 10–14, `TripTests.swift` lines 12–16, `previewContainer` in `PreviewContainer.swift` lines 9–13.
**Apply to:** every new test struct's `init() throws` and every new `#Preview` block.

```swift
try ModelContainer(
    for: Trip.self, Destination.self, Document.self,
         PackingItem.self, Activity.self,
    configurations: config
)
```
Rule: never subset the type list — SwiftData fails opaquely if a relationship target is missing.

### Pattern S7 — `#if DEBUG` + `#Preview` per view file

**Source:** `TripListView.swift` lines 97–115, `TripRow.swift` lines 39–52, `TripEditSheet.swift` lines 178–191.
**Apply to:** every new view file in `Features/Documents/`.

- Two previews where applicable ("With data" + "Empty").
- Always `.modelContainer(previewContainer)` for the populated preview.
- For the empty preview, instantiate a fresh in-memory container inline.

### Pattern S8 — `@MainActor` + in-memory `ModelContainer` for tests & previews

**Source:** `TripTests.swift` line 6, `PreviewContainer.swift` line 5.
**Apply to:** every Phase 2 test struct and the `previewContainer` extension if new seed data is added.

```swift
@MainActor
struct MyTests {
    let container: ModelContainer
    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: /* full type list */, configurations: config)
    }
}
```

---

## No Analog Found

The following files have no useful Phase 1 analog. Planner must reference RESEARCH.md patterns directly.

| File | Role | Data Flow | Reason | RESEARCH.md Pattern |
|------|------|-----------|--------|----|
| `Features/Documents/Import/ScanView.swift` | UIViewControllerRepresentable bridge | event-driven (delegate) | No UIKit bridges exist yet in Travellify | Pattern 2 |
| `Features/Documents/Import/PhotosImporter.swift` | PhotosPicker + Transferable pipeline | file-I/O write | First PhotosPicker use | Pattern 3 |
| `Features/Documents/Import/FilesImporter.swift` | UIViewControllerRepresentable bridge | file-I/O write | First UIDocumentPickerViewController bridge | Pattern 4 |
| `Features/Documents/DocumentViewer.swift` (body only; chrome has analogs) | PDFKit + UIViewRepresentable; ScrollView + MagnificationGesture | file-I/O read | First PDFKit integration; first MagnificationGesture use | Pattern 6 |
| `Services/FileStorage.swift` | Filesystem service | file-I/O | No prior filesystem code in Travellify; only enum-shape matches TripPartition | Pattern 1 / D10 path layout + D16 semantics |

---

## Metadata

**Analog search scope:** `Travellify/` (App, Models, Features/Trips, Shared), `TravellifyTests/`.
**Files scanned:** App (2), Models (6), Features/Trips (9), Shared (1), ContentView (1), Tests (4) = 23.
**Pattern extraction date:** 2026-04-19.
**Key observations:**
- Phase 1 established a uniform idiom: `@Model` types live in `extension TravellifySchemaV1`, exposed via module-level typealiases in `SchemaV1.swift`.
- Phase 1 has zero UIKit bridges, zero third-party deps, zero ViewModels — Phase 2 preserves that.
- Phase 1 destructive pattern = `.confirmationDialog` (not `.alert`). Phase 2 reuses this for delete but diverges on trigger: context menu instead of swipe.
- Phase 1 preview harness (`previewContainer`) is the canonical seed source; extend it in Phase 2 rather than rolling a new one.
