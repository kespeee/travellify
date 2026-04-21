import SwiftUI
import SwiftData

private enum PackingEntry: Identifiable {
    case progress
    case header(PackingCategory)
    case item(PackingItem)
    case addItem(PackingCategory)

    var id: String {
        switch self {
        case .progress: return "progress"
        case .header(let c): return "h-\(c.id.uuidString)"
        case .item(let i): return "i-\(i.id.uuidString)"
        case .addItem(let c): return "a-\(c.id.uuidString)"
        }
    }

    var canMove: Bool {
        if case .item = self { return true }
        return false
    }
}

struct PackingListView: View {
    let tripID: PersistentIdentifier

    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [PackingCategory]

    @State private var isAddingCategory = false
    @State private var newCategoryName: String = ""
    @State private var pendingRenameCategory: PackingCategory?
    @State private var renameCategoryDraft: String = ""
    @State private var pendingDeleteCategory: PackingCategory?

    @FocusState private var addItemFocus: PersistentIdentifier?
    @State private var newItemNames: [PersistentIdentifier: String] = [:]

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

    private var sortedCategories: [PackingCategory] {
        categories.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func sortedItems(_ category: PackingCategory) -> [PackingItem] {
        (category.items ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var allItems: [PackingItem] {
        categories.flatMap { $0.items ?? [] }
    }

    private var tripCheckedCount: Int { allItems.filter(\.isChecked).count }
    private var tripTotalCount: Int { allItems.count }

    private var entries: [PackingEntry] {
        var result: [PackingEntry] = []
        if !categories.isEmpty {
            result.append(.progress)
            for cat in sortedCategories {
                result.append(.header(cat))
                for item in sortedItems(cat) {
                    result.append(.item(item))
                }
                result.append(.addItem(cat))
            }
        }
        return result
    }

    private func newItemNameBinding(for category: PackingCategory) -> Binding<String> {
        Binding(
            get: { newItemNames[category.persistentModelID] ?? "" },
            set: { newItemNames[category.persistentModelID] = $0 }
        )
    }

    // MARK: - Mutations

    private func toggleChecked(_ item: PackingItem) {
        item.isChecked.toggle()
        save("Couldn't update item. Please try again.")
    }

    private func deleteItem(_ item: PackingItem) {
        modelContext.delete(item)
        save("Couldn't delete item. Please try again.")
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
        save("Couldn't add item. Please try again.")
    }

    private func renameItem(_ item: PackingItem, to newName: String) {
        item.name = newName
        save("Couldn't rename. Please try again.")
    }

    private func save(_ failureMessage: String) {
        do { try modelContext.save() }
        catch { errorMessage = failureMessage }
    }

    // MARK: - Reorder via .onMove

    private func handleMove(source: IndexSet, destination: Int) {
        var working = entries
        working.move(fromOffsets: source, toOffset: destination)

        // Reject moves that would place an item before the first header or as the first entry
        guard let firstHeaderIdx = working.firstIndex(where: { if case .header = $0 { return true } else { return false } }) else { return }
        if working[..<firstHeaderIdx].contains(where: { if case .item = $0 { return true } else { return false } }) {
            return
        }

        var currentCategory: PackingCategory?
        var order = 0
        for entry in working {
            switch entry {
            case .header(let cat):
                currentCategory = cat
                order = 0
            case .item(let item):
                if let cat = currentCategory {
                    item.category = cat
                    item.sortOrder = order
                    order += 1
                }
            case .progress, .addItem:
                break
            }
        }
        save("Couldn't reorder. Please try again.")
    }

    // MARK: - Body

    var body: some View {
        List {
            if categories.isEmpty {
                Section {
                    EmptyPackingListView()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            } else {
                ForEach(entries) { entry in
                    row(for: entry)
                }
                .onMove(perform: handleMove)
            }
        }
        .listStyle(.insetGrouped)
        .listRowSpacing(8)
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle("Packing")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    newCategoryName = ""
                    isAddingCategory = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New Category")
            }
        }
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

    @ViewBuilder
    private func row(for entry: PackingEntry) -> some View {
        switch entry {
        case .progress:
            PackingProgressRow(checkedCount: tripCheckedCount, totalCount: tripTotalCount)
                .moveDisabled(true)

        case .header(let category):
            CategoryHeader(
                category: category,
                onRename: {
                    pendingRenameCategory = category
                    renameCategoryDraft = category.name
                },
                onDelete: { pendingDeleteCategory = category }
            )
            .moveDisabled(true)

        case .item(let item):
            PackingRow(
                item: item,
                onToggleCheck: { toggleChecked(item) },
                onCommitRename: { newName in renameItem(item, to: newName) }
            )
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button { toggleChecked(item) } label: {
                    Label(item.isChecked ? "Unpack" : "Pack", systemImage: "checkmark")
                }
                .tint(.green)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) { deleteItem(item) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .sensoryFeedback(.success, trigger: item.isChecked)

        case .addItem(let category):
            HStack {
                Image(systemName: "plus.circle").foregroundStyle(.tint)
                TextField("Add item", text: newItemNameBinding(for: category))
                    .font(.body)
                    .focused($addItemFocus, equals: category.persistentModelID)
                    .submitLabel(.done)
                    .onSubmit {
                        let trimmed = (newItemNames[category.persistentModelID] ?? "")
                            .trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            insertItem(name: trimmed, in: category)
                            newItemNames[category.persistentModelID] = ""
                        }
                        addItemFocus = nil
                    }
            }
            .accessibilityLabel("Add item to \(category.name)")
            .moveDisabled(true)
        }
    }

    // MARK: - Category CRUD

    private func addCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { newCategoryName = ""; return }
        let nextSort = (categories.map(\.sortOrder).max() ?? -1) + 1
        let cat = PackingCategory()
        cat.name = trimmed
        cat.sortOrder = nextSort
        cat.trip = modelContext.model(for: tripID) as? Trip
        modelContext.insert(cat)
        save("Couldn't add category. Please try again.")
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
        save("Couldn't rename category. Please try again.")
        pendingRenameCategory = nil
        renameCategoryDraft = ""
    }

    private func deleteCategory(_ cat: PackingCategory) {
        modelContext.delete(cat)
        save("Couldn't delete category. Please try again.")
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
