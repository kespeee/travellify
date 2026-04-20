import SwiftUI
import SwiftData

struct PackingListView: View {
    let tripID: PersistentIdentifier

    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [PackingCategory]

    // Category CRUD presentation state
    @State private var isAddingCategory = false
    @State private var newCategoryName: String = ""
    @State private var pendingRenameCategory: PackingCategory?
    @State private var renameCategoryDraft: String = ""
    @State private var pendingDeleteCategory: PackingCategory?

    // Shared error surface
    @State private var errorMessage: String?

    init(tripID: PersistentIdentifier) {
        self.tripID = tripID
        _categories = Query(
            filter: #Predicate<PackingCategory> { cat in
                cat.trip?.persistentModelID == tripID
            },
            sort: \PackingCategory.sortOrder,
            order: .forward
        )
    }

    // MARK: - Computed progress helpers

    private var tripCheckedCount: Int {
        categories.flatMap { $0.items ?? [] }.filter(\.isChecked).count
    }

    private var tripTotalCount: Int {
        categories.flatMap { $0.items ?? [] }.count
    }

    private func sortedItems(_ category: PackingCategory) -> [PackingItem] {
        (category.items ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - List content sections

    @ViewBuilder
    private var listContent: some View {
        if categories.isEmpty {
            Section {
                EmptyPackingListView()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        } else {
            Section {
                PackingProgressRow(checkedCount: tripCheckedCount, totalCount: tripTotalCount)
            }
            ForEach(categories) { category in
                Section {
                    ForEach(sortedItems(category)) { item in
                        // PLAIN ROW — swipes / inline edit / checked styling land in plan 03
                        Text(item.name).font(.body)
                    }
                } header: {
                    CategoryHeader(
                        category: category,
                        onRename: {
                            pendingRenameCategory = category
                            renameCategoryDraft = category.name
                        },
                        onDelete: { pendingDeleteCategory = category }
                    )
                }
            }
        }
    }

    // MARK: - Body

    var body: some View {
        List {
            listContent

            // "Add category" row is ALWAYS visible (per D38 — even in empty state)
            Section {
                Button {
                    newCategoryName = ""
                    isAddingCategory = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle").foregroundStyle(.tint)
                        Text("Add category").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add category")
            }
        }
        .navigationTitle("Packing")
        .navigationBarTitleDisplayMode(.large)
        .addCategoryAlert(
            isPresented: $isAddingCategory,
            name: $newCategoryName,
            onAdd: addCategory
        )
        .renameCategoryAlert(
            pending: $pendingRenameCategory,
            draft: $renameCategoryDraft,
            onSave: renameCategory
        )
        .deleteCategoryDialog(
            pending: $pendingDeleteCategory,
            onDelete: deleteCategory
        )
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            presenting: errorMessage
        ) { _ in
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { msg in
            Text(msg)
        }
    }

    // MARK: - CRUD actions

    private func addCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { newCategoryName = ""; return }
        let nextSort = (categories.map(\.sortOrder).max() ?? -1) + 1
        let cat = PackingCategory()
        cat.name = trimmed
        cat.sortOrder = nextSort
        cat.trip = modelContext.model(for: tripID) as? Trip
        modelContext.insert(cat)
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Couldn't add category. Please try again."
        }
        newCategoryName = ""
    }

    private func renameCategory() {
        let trimmed = renameCategoryDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let cat = pendingRenameCategory else {
            pendingRenameCategory = nil
            renameCategoryDraft = ""
            return
        }
        cat.name = trimmed
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Couldn't rename category. Please try again."
        }
        pendingRenameCategory = nil
        renameCategoryDraft = ""
    }

    private func deleteCategory(_ cat: PackingCategory) {
        modelContext.delete(cat)
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Couldn't delete category. Please try again."
        }
        pendingDeleteCategory = nil
    }
}

// MARK: - Alert/Dialog ViewModifiers

private extension View {
    func addCategoryAlert(
        isPresented: Binding<Bool>,
        name: Binding<String>,
        onAdd: @escaping () -> Void
    ) -> some View {
        self.alert("New Category", isPresented: isPresented) {
            TextField("Category name", text: name)
            Button("Add", action: onAdd)
                .disabled(name.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) { name.wrappedValue = "" }
        }
    }

    func renameCategoryAlert(
        pending: Binding<PackingCategory?>,
        draft: Binding<String>,
        onSave: @escaping () -> Void
    ) -> some View {
        self.alert(
            "Rename Category",
            isPresented: Binding(
                get: { pending.wrappedValue != nil },
                set: { if !$0 { pending.wrappedValue = nil; draft.wrappedValue = "" } }
            ),
            presenting: pending.wrappedValue
        ) { _ in
            TextField("Category name", text: draft)
            Button("Save", action: onSave)
                .disabled(draft.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) {
                pending.wrappedValue = nil
                draft.wrappedValue = ""
            }
        }
    }

    func deleteCategoryDialog(
        pending: Binding<PackingCategory?>,
        onDelete: @escaping (PackingCategory) -> Void
    ) -> some View {
        self.confirmationDialog(
            pending.wrappedValue.map { "Delete \"\($0.name)\"?" } ?? "Delete category?",
            isPresented: Binding(
                get: { pending.wrappedValue != nil },
                set: { if !$0 { pending.wrappedValue = nil } }
            ),
            titleVisibility: .visible,
            presenting: pending.wrappedValue
        ) { cat in
            Button("Delete", role: .destructive) { onDelete(cat) }
            Button("Cancel", role: .cancel) { pending.wrappedValue = nil }
        } message: { cat in
            let itemCount = (cat.items ?? []).count
            if itemCount == 0 {
                Text("This category is empty. Delete it?")
            } else {
                Text("This will also delete its \(itemCount) item\(itemCount == 1 ? "" : "s") and cannot be undone.")
            }
        }
    }
}

#if DEBUG
#Preview("With categories") {
    NavigationStack {
        PackingListView(tripID: {
            let container = previewContainer
            let trips = (try? container.mainContext.fetch(FetchDescriptor<Trip>())) ?? []
            return (trips.first ?? Trip()).persistentModelID
        }())
    }
    .modelContainer(previewContainer)
}

#Preview("Empty") {
    let container = try! ModelContainer(
        for: Trip.self, Destination.self, Document.self,
             PackingItem.self, PackingCategory.self, Activity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let trip = Trip()
    trip.name = "Empty trip"
    container.mainContext.insert(trip)
    return NavigationStack {
        PackingListView(tripID: trip.persistentModelID)
    }
    .modelContainer(container)
}
#endif
