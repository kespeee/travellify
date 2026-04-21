import SwiftUI
import SwiftData

struct CategoryHeader: View {
    let category: PackingCategory
    let onRename: () -> Void
    let onDelete: () -> Void

    private var checkedCount: Int { (category.items ?? []).filter(\.isChecked).count }
    private var totalCount: Int { (category.items ?? []).count }

    var body: some View {
        HStack {
            Text(category.name)
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            Text("\(checkedCount)/\(totalCount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button { onRename() } label: { Label("Rename", systemImage: "pencil") }
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.name), \(checkedCount) of \(totalCount) packed")
        .accessibilityHint("Long press for rename and delete options")
    }
}

#if DEBUG
#Preview {
    let container = try! ModelContainer(
        for: Trip.self, Destination.self, Document.self,
             PackingItem.self, PackingCategory.self, Activity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let cat = PackingCategory()
    cat.name = "Clothes"
    cat.sortOrder = 0
    let item1 = PackingItem()
    item1.name = "T-shirts"
    item1.isChecked = true
    item1.category = cat
    let item2 = PackingItem()
    item2.name = "Jeans"
    item2.category = cat
    container.mainContext.insert(cat)
    container.mainContext.insert(item1)
    container.mainContext.insert(item2)
    return List {
        Section {
            Text("Row 1")
            Text("Row 2")
        } header: {
            CategoryHeader(
                category: cat,
                onRename: {},
                onDelete: {}
            )
        }
    }
    .modelContainer(container)
}
#endif
