import SwiftUI
import SwiftData

struct TripDetailView: View {
    let tripID: PersistentIdentifier

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showEditSheet = false

    private var trip: Trip? {
        modelContext.model(for: tripID) as? Trip
    }

    var body: some View {
        Group {
            if let trip {
                content(for: trip)
            } else {
                Color.clear
                    .onAppear { dismiss() }
            }
        }
    }

    @ViewBuilder
    private func content(for trip: Trip) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                TripDetailHeader(trip: trip)

                HStack(spacing: 12) {
                    documentsCard(for: trip)
                    SectionCard(
                        title: "Packing",
                        systemImage: "checklist",
                        message: "Your packing list will appear here."
                    )
                }

                SectionCard(
                    title: "Activities",
                    systemImage: "calendar",
                    message: "Your itinerary will appear here.",
                    minHeight: 220
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            TripEditSheet(mode: .edit(trip))
        }
    }

    @ViewBuilder
    private func documentsCard(for trip: Trip) -> some View {
        let docs = trip.documents ?? []
        let count = docs.count
        let primary: String = count == 0 ? "No documents yet" : (count == 1 ? "1 document" : "\(count) documents")
        let latest: String? = count == 0
            ? nil
            : docs.max(by: { $0.importedAt < $1.importedAt })?.displayName
        NavigationLink(value: AppDestination.documentList(trip.persistentModelID)) {
            SectionCard(
                title: "Documents",
                systemImage: "doc.text",
                message: primary,
                secondaryMessage: latest
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SectionCard: View {
    let title: String
    let systemImage: String
    let message: String
    var minHeight: CGFloat = 140
    var secondaryMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.headline)
            }
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let secondaryMessage {
                Text(secondaryMessage)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: minHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

#if DEBUG
#Preview {
    let container = previewContainer
    let trips = (try? container.mainContext.fetch(FetchDescriptor<Trip>())) ?? []
    let first = trips.first ?? Trip()
    return NavigationStack {
        TripDetailView(tripID: first.persistentModelID)
    }
    .modelContainer(container)
}
#endif
