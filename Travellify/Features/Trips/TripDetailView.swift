import SwiftUI
import SwiftData

struct TripDetailView: View {
    let tripID: PersistentIdentifier

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: TripDetailTab = .documents
    @State private var showEditSheet = false

    private var trip: Trip? {
        modelContext.model(for: tripID) as? Trip
    }

    var body: some View {
        Group {
            if let trip {
                content(for: trip)
            } else {
                // Trip was deleted while detail was visible — pop
                Color.clear
                    .onAppear { dismiss() }
            }
        }
    }

    @ViewBuilder
    private func content(for trip: Trip) -> some View {
        VStack(spacing: 0) {
            TripDetailHeader(trip: trip)

            Picker("Section", selection: $selectedTab) {
                ForEach(TripDetailTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            Divider()

            placeholderContent(for: selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    private func placeholderContent(for tab: TripDetailTab) -> some View {
        VStack(spacing: 8) {
            Text(tab.placeholderHeading)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
            Text(tab.placeholderBody)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
