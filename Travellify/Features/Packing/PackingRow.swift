import SwiftUI
import SwiftData

struct PackingRow: View {
    let item: PackingItem
    @Binding var renameDraft: String          // binding into the parent's per-item draft dictionary
    var isRenaming: Bool                      // true iff renameItemFocus == item.persistentModelID
    var onTapToRename: () -> Void             // parent sets focus + seeds draft
    var onCommitRename: () -> Void            // parent trims/saves/clears focus

    @FocusState.Binding var renameItemFocus: PersistentIdentifier?

    var body: some View {
        Group {
            if isRenaming {
                TextField("Item name", text: $renameDraft)
                    .font(.body)
                    .focused($renameItemFocus, equals: item.persistentModelID)
                    .submitLabel(.done)
                    .onSubmit { onCommitRename() }
            } else {
                Text(item.name)
                    .font(.body)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                    .strikethrough(item.isChecked, color: .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { onTapToRename() }
            }
        }
        .accessibilityLabel(item.isChecked
            ? "\(item.name), packed"
            : item.name)
        .draggable(item.id.uuidString)        // Transferable payload: String (RESEARCH Pitfall 2)
    }
}

#if DEBUG
// All setup (ModelContainer creation + item insertion) lives in a plain function
// so the #Preview @ViewBuilder body only contains view expressions (no Void calls).
// @FocusState.Binding has no .constant — the wrapper view owns it.
@MainActor
private func makePackingRowPreview() -> some View {
    let container = try! ModelContainer(
        for: Trip.self, Destination.self, Document.self,
             PackingItem.self, PackingCategory.self, Activity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let item0 = PackingItem()
    item0.name = "Passport"
    item0.isChecked = false
    let item1 = PackingItem()
    item1.name = "Toothbrush"
    item1.isChecked = true
    container.mainContext.insert(item0)
    container.mainContext.insert(item1)
    return PackingRowPreviewWrapper(item0: item0, item1: item1)
        .modelContainer(container)
}

@MainActor
private struct PackingRowPreviewWrapper: View {
    @FocusState private var focus: PersistentIdentifier?
    @State private var draft0 = "Passport"
    @State private var draft1 = "Toothbrush"
    let item0: PackingItem
    let item1: PackingItem

    var body: some View {
        List {
            PackingRow(
                item: item0,
                renameDraft: $draft0,
                isRenaming: false,
                onTapToRename: {},
                onCommitRename: {},
                renameItemFocus: $focus
            )
            PackingRow(
                item: item1,
                renameDraft: $draft1,
                isRenaming: false,
                onTapToRename: {},
                onCommitRename: {},
                renameItemFocus: $focus
            )
        }
    }
}

#Preview("PackingRow states") {
    makePackingRowPreview()
}
#endif
