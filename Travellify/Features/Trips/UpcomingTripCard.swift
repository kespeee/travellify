import SwiftUI

/// Hero card for the soonest upcoming trip on TripListView (Figma node 122:2783).
struct UpcomingTripCard: View {
    let trip: Trip

    @State private var mapImage: UIImage?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            leftPanel
            rightPanel
        }
        .padding(16)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .frame(height: 271)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(trip.name), upcoming trip, starts \(formattedFullDate(trip.startDate))"))
    }

    // MARK: - Left panel: map + gradient + badge + name/destinations

    private var leftPanel: some View {
        ZStack(alignment: .topLeading) {
            // Map snapshot or gradient fallback
            Group {
                if let mapImage {
                    Image(uiImage: mapImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.15, blue: 0.25),
                            Color(red: 0.05, green: 0.05, blue: 0.10)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            // Bottom darkening gradient (Figma: 50% transparent → 70% black)
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.7)],
                startPoint: UnitPoint(x: 0.5, y: 0.5),
                endPoint: .bottom
            )

            VStack(alignment: .leading) {
                Badge(text: "Upcoming")
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.name)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(destinationsLabel)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 239)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .task(id: trip.id) {
            let pointSize = CGSize(width: 200, height: 239)
            mapImage = await TripMapSnapshotProvider.shared.snapshot(
                for: trip,
                size: pointSize
            )
        }
    }

    // MARK: - Right panel: date block on top, packing block on bottom

    private var rightPanel: some View {
        VStack(spacing: 8) {
            DateBlock(start: trip.startDate, end: trip.endDate)
                .frame(width: 104, height: 116)
            PackingBlock(items: trip.packingItems ?? [])
                .frame(width: 104)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 104, height: 239)
    }

    private var destinationsLabel: String {
        let count = trip.destinations?.count ?? 0
        return "\(count) destination\(count == 1 ? "" : "s")"
    }

    private func formattedFullDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    // MARK: - Nested views

    private struct Badge: View {
        let text: String
        var body: some View {
            Text(text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .glassEffect(.clear, in: Capsule())
        }
    }

    private struct DateBlock: View {
        let start: Date
        let end: Date

        var body: some View {
            let cal = Calendar.current
            let crossYear = cal.component(.year, from: start) != cal.component(.year, from: end)
            let days = cal.dateComponents([.day], from: start, to: end).day ?? 0

            Grid(horizontalSpacing: -4, verticalSpacing: 0) {
                GridRow {
                    monthCell(monthLabel(for: start, crossYear: crossYear))
                    Text("\(days)d")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    monthCell(monthLabel(for: end, crossYear: crossYear))
                }
                GridRow {
                    dayCell(cal.component(.day, from: start))
                    Text("→")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    dayCell(cal.component(.day, from: end))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }

        private func monthCell(_ text: String) -> some View {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.259, blue: 0.271))
                .frame(maxWidth: .infinity)
        }

        private func dayCell(_ day: Int) -> some View {
            Text("\(day)")
                .font(.title.weight(.bold))
                .foregroundStyle(.white)
                .tracking(0.38)
                .frame(maxWidth: .infinity)
        }

        private func monthLabel(for date: Date, crossYear: Bool) -> String {
            let f = DateFormatter()
            f.setLocalizedDateFormatFromTemplate("MMM")
            let m = f.string(from: date)
            guard crossYear else { return m }
            let yy = Calendar.current.component(.year, from: date) % 100
            return "\(m) ’\(String(format: "%02d", yy))"
        }
    }

    private struct PackingBlock: View {
        let items: [PackingItem]

        private var stats: (checked: Int, total: Int) {
            (items.filter(\.isChecked).count, items.count)
        }

        var body: some View {
            let s = stats
            Group {
                if s.total == 0 {
                    Text("No items in the packing list")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                } else {
                    VStack(spacing: 12) {
                        ProgressRing(progress: Double(s.checked) / Double(s.total))
                            .frame(width: 32, height: 32)
                        VStack(spacing: 2) {
                            Text("\(s.checked)/\(s.total)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("Packing")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private struct ProgressRing: View {
        let progress: Double  // 0.0 ... 1.0
        var body: some View {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: max(0, min(1, progress)))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

#if DEBUG
#Preview {
    UpcomingTripCard(trip: Trip())
        .padding()
        .background(Color.black)
}
#endif
