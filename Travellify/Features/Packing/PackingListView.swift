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

    // Dual FocusState — RESEARCH Pattern 2 / Pitfall 1
    @FocusState private var addItemFocus: PersistentIdentifier?     // keyed by category.persistentModelID
    @FocusState private var renameItemFocus: PersistentIdentifier?  // keyed by item.persistentModelID

    // Per-category add-item drafts and per-item rename drafts
    @State private var newItemNames: [PersistentIdentifier: String] = [:]
    @State private var renameDrafts: [PersistentIdentifier: String] = [:]

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

    // MARK: - Binding helpers

    private func newItemNameBinding(for category: PackingCategory) -> Binding<String> {
        Binding(
            get: { newItemNames[category.persistentModelID] ?? "" },
            set: { newItemNames[category.persistentModelID] = $0 }
        )
    }

    private func renameDraftBinding(for item: PackingItem) -> Binding<String> {
        Binding(
            get: { renameDrafts[item.persistentModelID] ?? item.name },
            set: { renameDrafts[item.persistentModelID] = $0 }
        )
    }

    // MARK: - Item CRUD mutations

    private func toggleChecked(_ item: PackingItem) {
        item.isChecked.toggle()
        do { try modelContext.save() }
        catch { errorMessage = "Couldn't update item. Please try again." }
    }

    private func deleteItem(_ item: PackingItem) {
        modelContext.delete(item)
        do { try modelContext.save() }
        catch { errorMessage = "Couldn't delete item. Please try again." }
    }

    private func insertItem(name: String, in category: PackingCategory) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let nextSort = ((category.items ?? []).map(\.sortOrder).max() ?? -1) + 1
        let item = PackingItem()
        item.name = trimmed
        item.sortOrder = nextSort
        item.category = category
        modelContext.insert(item)
        do { try modelContext.save() }
        catch { errorMessage = "Couldn't add item. Please try again." }
    }

    private func commitRename(_ item: PackingItem) {
        let draft = (renameDrafts[item.persistentModelID] ?? "").trimmingCharacters(in: .whitespaces)
        if !draft.isEmpty, draft != item.name {
            item.name = draft
            do { try modelContext.save() }
            catch { errorMessage = "Couldn't rename. Please try again." }
        }
        renameDrafts[item.persistentModelID] = nil
        renameItemFocus = nil
    }

    private func fetchItem(byID uuid: UUID) -> PackingItem? {
        let desc = FetchDescriptor<PackingItem>(predicate: #Predicate { $0.id == uuid })
        return try? modelContext.fetch(desc).first
    }

    private func moveItem(_ item: PackingItem, to destination: PackingCategory) {
        let nextSort = ((destination.items ?? []).map(\.sortOrder).max() ?? -1) + 1
        item.category = destination
        item.sortOrder = nextSort
        do { try modelContext.save() }
        catch { errorMessage = "Couldn't move item. Please try again." }
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
                        PackingRow(
                            item: item,
                            renameDraft: renameDraftBinding(for: item),
                            isRenaming: renameItemFocus == item.persistentModelID,
                            onTapToRename: {
                                renameDrafts[item.persistentModelID] = item.name
                                renameItemFocus = item.persistentModelID
                            },
                            onCommitRename: { commitRename(item) },
                            renameItemFocus: $renameItemFocus
                        )
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                toggleChecked(item)
                            } label: {
                                Label(item.isChecked ? "Unpack" : "Pack", systemImage: "checkmark")
                            }
                            .tint(.green)
                            .accessibilityLabel(item.isChecked ? "Mark as unpacked" : "Mark as packed")
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteItem(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .accessibilityLabel("Delete \(item.name)")
                        }
                        .sensoryFeedback(.success, trigger: item.isChecked)
                    }
                    // Inline "Add item" row — always at bottom of each section (D30 / UI-SPEC)
                    HStack {
                        Image(systemName: "plus.circle").foregroundStyle(.tint)
                        if addItemFocus == category.persistentModelID {
                            TextField("Item name", text: newItemNameBinding(for: category))
                                .font(.body)
                                .focused($addItemFocus, equals: category.persistentModelID)
                                .submitLabel(.done)
                                .onSubmit {
                                    let trimmed = (newItemNames[category.persistentModelID] ?? "")
                                        .trimmingCharacters(in: .whitespaces)
                                    if !trimmed.isEmpty {
                                        insertItem(name: trimmed, in: category)
                                        newItemNames[category.persistentModelID] = ""
                                        // Re-focus for rapid multi-add (D30)
                                        addItemFocus = category.persistentModelID
                                    } else {
                                        // Empty submit dismisses (Pitfall 6: nil, not same id)
                                        addItemFocus = nil
                                    }
                                }
                        } else {
                            Text("+ Add item")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    addItemFocus = category.persistentModelID
                                }
                        }
                    }
                    .accessibilityLabel("Add item to \(category.name)")
                } header: {
                    CategoryHeader(
                        category: category,
                        onRename: {
                            pendingRenameCategory = category
                            renameCategoryDraft = category.name
                        },
                        onDelete: { pendingDeleteCategory = category },
                        onDropItem: { uuid in
                            guard let item = fetchItem(byID: uuid) else { return }
                            guard item.category?.persistentModelID != category.persistentModelID else { return }
                            moveItem(item, to: category)
                        }
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
