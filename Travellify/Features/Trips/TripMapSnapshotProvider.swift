import MapKit
import UIKit
import CoreLocation

/// Generates and caches MKMapSnapshotter PNGs for trip hero cards.
///
/// Pipeline per trip:
/// 1. Geocode each `Destination.name` via `CLGeocoder` (one query per name).
/// 2. Compute a bounding `MKCoordinateRegion` from the resolved coordinates,
///    with a small lat/lng padding so points aren't on the snapshot edge.
/// 3. Render via `MKMapSnapshotter` at the requested pixel size.
/// 4. Cache in-memory keyed by `trip.id`. Cache lifetime = process lifetime
///    (provider is `@MainActor`-affined, no disk persistence — D7-10).
///
/// Returns nil when no destinations resolve to coordinates — caller should
/// fall back to a gradient background.
@MainActor
final class TripMapSnapshotProvider: ObservableObject {
    static let shared = TripMapSnapshotProvider()

    private var cache: [UUID: UIImage] = [:]
    private var inflight: [UUID: Task<UIImage?, Never>] = [:]
    private let geocoder = CLGeocoder()

    private init() {}

    func snapshot(for trip: Trip, size: CGSize, traitCollection: UITraitCollection? = nil) async -> UIImage? {
        if let cached = cache[trip.id] { return cached }

        // Coalesce concurrent requests for the same trip.
        if let pending = inflight[trip.id] { return await pending.value }

        let tripID = trip.id
        let names = (trip.destinations ?? [])
            .map(\.name)
            .filter { !$0.isEmpty }

        let task = Task<UIImage?, Never> { [weak self] in
            guard let self else { return nil }
            guard !names.isEmpty else { return nil }

            // Geocode in series (CLGeocoder rate-limits ~1 req/sec).
            var coords: [CLLocationCoordinate2D] = []
            for name in names {
                if let placemarks = try? await self.geocoder.geocodeAddressString(name),
                   let loc = placemarks.first?.location {
                    coords.append(loc.coordinate)
                }
            }
            guard !coords.isEmpty else { return nil }

            let region = Self.region(enclosing: coords)
            let options = MKMapSnapshotter.Options()
            options.region = region
            options.size = size
            options.scale = UIScreen.main.scale
            options.mapType = .standard
            if let traitCollection {
                options.traitCollection = traitCollection
            }

            let snapshotter = MKMapSnapshotter(options: options)
            guard let snapshot = try? await snapshotter.start() else { return nil }
            return snapshot.image
        }

        inflight[tripID] = task
        let result = await task.value
        inflight[tripID] = nil
        if let result { cache[tripID] = result }
        return result
    }

    // Bounding region with 50% padding around the bounding box of coords.
    private static func region(enclosing coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLng = lngs.min() ?? 0
        let maxLng = lngs.max() ?? 0
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let latDelta = max(0.05, (maxLat - minLat) * 1.5)
        let lngDelta = max(0.05, (maxLng - minLng) * 1.5)
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta)
        )
    }
}
