import SwiftUI
import SwiftData
import PhotosUI

struct DocumentListView: View {
    let tripID: PersistentIdentifier

    @Environment(\.modelContext) private var modelContext
    @Query private var documents: [Document]

    // Presentation state
    @State private var showScanSheet = false
    @State private var showFilesSheet = false
    @State private var photosItem: PhotosPickerItem?

    // Viewer
    @State private var openedDocument: Document?

    // Rename + delete
    @State private var docPendingRename: Document?
    @State private var renameDraft: String = ""
    @State private var docPendingDelete: Document?

    // Import status (Plan 02-03 flips these)
    @State private var isImporting: Bool = false
    @State private var importErrorMessage: String?

    init(tripID: PersistentIdentifier) {
        self.tripID = tripID
        _documents = Query(
            filter: #Predicate<Document> { doc in
                doc.trip?.persistentModelID == tripID
            },
            sort: \Document.importedAt,
            order: .reverse
        )
    }

    private var trip: Trip? {
        modelContext.model(for: tripID) as? Trip
    }

    private func runImport(_ work: @escaping () async throws -> Void) {
        isImporting = true
        Task {
            defer { isImporting = false }
            do {
                try await work()
            } catch {
                importErrorMessage = "Couldn't add document. Please try again."
            }
        }
    }

    var body: some View {
        Group {
            if documents.isEmpty {
                EmptyDocumentsView()
            } else {
                List {
                    ForEach(documents) { doc in
                        DocumentRow(document: doc)
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
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showScanSheet = true
                    } label: { Label("Scan Document", systemImage: "camera") }

                    // PhotosPicker as a Menu item — iOS 16+ API
                    PhotosPicker(selection: $photosItem, matching: .any(of: [.images])) {
                        Label("Choose from Photos", systemImage: "photo.on.rectangle")
                    }

                    Button {
                        showFilesSheet = true
                    } label: { Label("Import from Files", systemImage: "folder") }
                } label: {
                    if isImporting {
                        ProgressView().controlSize(.small)
                            .accessibilityLabel("Importing document")
                    } else {
                        Image(systemName: "plus")
                    }
                }
                .accessibilityLabel("Add Document")
            }
        }
        // Scan sheet
        .sheet(isPresented: $showScanSheet) {
            ScanView(
                onFinish: { pages in
                    showScanSheet = false
                    guard let trip else { return }
                    runImport { try await DocumentImporter.importScanResult(pages: pages, trip: trip, modelContext: modelContext) }
                },
                onCancel: { showScanSheet = false },
                onError: { _ in
                    showScanSheet = false
                    importErrorMessage = "Couldn't add document. Please try again."
                }
            )
            .ignoresSafeArea()
        }
        // Files sheet
        .sheet(isPresented: $showFilesSheet) {
            FilesImporter(
                onPicked: { url in
                    showFilesSheet = false
                    guard let trip else { return }
                    runImport { try await DocumentImporter.importFileURL(url, trip: trip, modelContext: modelContext) }
                },
                onCancel: { showFilesSheet = false }
            )
            .ignoresSafeArea()
        }
        // PhotosPicker binding
        .onChange(of: photosItem) { _, newValue in
            guard let item = newValue, let trip else { return }
            photosItem = nil
            runImport { try await DocumentImporter.importPhotosItem(item, trip: trip, modelContext: modelContext) }
        }
        // Viewer — Plan 02-04 replaces the body
        .fullScreenCover(item: $openedDocument) { doc in
            // TODO(02-04): replace with DocumentViewer(document: doc)
            VStack(spacing: 16) {
                Text("Viewer coming soon")
                    .font(.title2.weight(.semibold))
                Text(doc.displayName)
                    .foregroundStyle(.secondary)
                Button("Close") { openedDocument = nil }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
        // Rename alert — Plan 02-05 wires Save action
        .alert(
            "Rename Document",
            isPresented: Binding(
                get: { docPendingRename != nil },
                set: { if !$0 { docPendingRename = nil; renameDraft = "" } }
            ),
            presenting: docPendingRename
        ) { _ in
            TextField("Name", text: $renameDraft)
            Button("Save") {
                // TODO(02-05): trim + assign displayName + save
                docPendingRename = nil
                renameDraft = ""
            }
            .disabled(renameDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) {
                docPendingRename = nil
                renameDraft = ""
            }
        }
        // Delete confirm — Plan 02-05 wires Delete action (FileStorage.remove + context.delete)
        .confirmationDialog(
            docPendingDelete.map { "Delete \"\($0.displayName)\"?" } ?? "",
            isPresented: Binding(
                get: { docPendingDelete != nil },
                set: { if !$0 { docPendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: docPendingDelete
        ) { _ in
            Button("Delete", role: .destructive) {
                // TODO(02-05): FileStorage.remove + modelContext.delete + save
                docPendingDelete = nil
            }
            Button("Cancel", role: .cancel) { docPendingDelete = nil }
        } message: { _ in
            Text("This removes the file from your device and cannot be undone.")
        }
        // Import error alert — Plan 02-03 sets importErrorMessage; shared shell lives here
        .alert(
            "Import Failed",
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            ),
            presenting: importErrorMessage
        ) { _ in
            Button("OK", role: .cancel) { importErrorMessage = nil }
        } message: { msg in
            Text(msg)
        }
    }
}

#if DEBUG
#Preview("Empty") {
    let container = try! ModelContainer(
        for: Trip.self, Destination.self, Document.self, PackingItem.self, Activity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let trip = Trip()
    trip.name = "Empty trip"
    container.mainContext.insert(trip)
    return NavigationStack {
        DocumentListView(tripID: trip.persistentModelID)
    }
    .modelContainer(container)
}

#Preview("With documents") {
    let container = try! ModelContainer(
        for: Trip.self, Destination.self, Document.self, PackingItem.self, Activity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let trip = Trip()
    trip.name = "Tokyo"
    container.mainContext.insert(trip)
    let doc1 = Document()
    doc1.displayName = "Passport Scan"
    doc1.kind = .pdf
    doc1.importedAt = Date()
    doc1.trip = trip
    container.mainContext.insert(doc1)
    return NavigationStack {
        DocumentListView(tripID: trip.persistentModelID)
    }
    .modelContainer(container)
}
#endif
