import Foundation
import MapKit
import Combine

extension Coordinate {
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

@MainActor
final class MapModel: ObservableObject {
    @Published private(set) var searchSnapshot = PlaceSearchSnapshot()
    var places: [Place] { searchSnapshot.places }
    var searchMessage: String { searchSnapshot.message }
    var isSearching: Bool { searchSnapshot.isSearching }
    @Published private(set) var routeMessage = "Select a destination, then request directions."
    @Published private(set) var route: MKRoute?
    @Published private(set) var isRouting = false
    @Published var selection: String?

    private var routeGate = RequestGate()
    private var searchTask: Task<Void, Never>?
    private var routeTask: Task<Void, Never>?
    private var searchRequest: MKLocalSearch?
    private var routeRequest: MKDirections?
    private var cache = TimedCache<RouteKey, MKRoute>(lifetime: 60)

    func cancelSearch(reason: SearchCancellationReason = .cancelled) {
        searchSnapshot.cancel(reason: reason)
        searchTask?.cancel()
        searchRequest?.cancel()
        searchTask = nil
        searchRequest = nil
    }

    func invalidateRoute() {
        routeGate.invalidate()
        routeTask?.cancel()
        routeRequest?.cancel()
        routeTask = nil
        routeRequest = nil
        route = nil
        isRouting = false
        routeMessage = "Select a destination, then request directions."
    }

    func stop() {
        cancelSearch()
        invalidateRoute()
    }

    func restoreFixtures() {
        stop()
        selection = nil
        searchSnapshot.restoreFixtures()
    }

    // The call occurs ONLY from the explicit Apple search button.
    func search(query: String, region: MKCoordinateRegion) {
        cancelSearch()
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchSnapshot.showEmptyQueryPrompt()
            return
        }
        let token = searchSnapshot.begin()
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region // search hint, not a geographic exclusion rule
        let operation = MKLocalSearch(request: request)
        searchRequest = operation
        searchTask = Task { @MainActor [weak self] in
            do {
                let response = try await operation.start()
                try Task.checkCancellation()
                guard let self, self.searchSnapshot.gate.accepts(token) else { return }
                // Search results have no promised stable cross-query ID here.
                // A response-scoped identity prevents false matching across responses.
                let result = try response.mapItems.enumerated().map { index, item in
                    Place(id: "search:\(token):\(index)",
                          name: item.name ?? "Unnamed Apple result",
                          coordinate: try Coordinate(latitude: item.placemark.coordinate.latitude,
                                                     longitude: item.placemark.coordinate.longitude))
                }
                guard try self.searchSnapshot.accept(result, token: token) else { return }
                self.invalidateRoute()
                self.selection = nil
                self.searchTask = nil
                self.searchRequest = nil
            } catch {
                guard let self, self.searchSnapshot.fail(token: token) else { return }
                self.searchTask = nil
                self.searchRequest = nil
            }
        }
    }

    // Origin is supplied, not implicitly read from the person's current location.
    func directions(origin: Coordinate, mode: TravelMode) {
        invalidateRoute()
        guard let destination = places.first(where: { $0.id == selection }) else {
            routeMessage = "Choose a destination first."
            return
        }
        let token = routeGate.begin()
        let key = RouteKey(origin: origin, destination: destination.coordinate, mode: mode)
        let now = ProcessInfo.processInfo.systemUptime
        if let cached = cache.entry(for: key, now: now) {
            route = cached.value
            routeMessage = routeEstimateText(
                RouteSummary(metres: cached.value.distance, seconds: cached.value.expectedTravelTime),
                freshness: .cached(age: now - cached.insertedAt, lifetime: cache.lifetime)
            )
            return
        }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin.clCoordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate.clCoordinate))
        request.transportType = mode == .walking ? .walking : .automobile
        request.requestsAlternateRoutes = false
        let operation = MKDirections(request: request)
        routeRequest = operation
        isRouting = true
        routeMessage = "Requesting Apple directions…"
        routeTask = Task { @MainActor [weak self] in
            do {
                let response = try await operation.calculate()
                try Task.checkCancellation()
                guard let self, self.routeGate.accepts(token) else { return }
                guard let route = response.routes.first else {
                    self.routeMessage = "No route available. Keep the destination and try another mode."
                    self.isRouting = false
                    self.routeTask = nil
                    self.routeRequest = nil
                    return
                }
                self.cache.insert(route, for: key, now: ProcessInfo.processInfo.systemUptime)
                // Keep this teaching cache bounded; it is not a disk or offline maps cache.
                if self.cache.entries.count > 8 { self.cache.entries = [key: self.cache.entries[key]!] }
                self.route = route
                self.routeMessage = routeEstimateText(
                    RouteSummary(metres: route.distance, seconds: route.expectedTravelTime),
                    freshness: .fresh
                )
                self.isRouting = false
                self.routeTask = nil
                self.routeRequest = nil
            } catch {
                guard let self, self.routeGate.accepts(token) else { return }
                self.isRouting = false
                self.routeTask = nil
                self.routeRequest = nil
                self.routeMessage = "Directions failed. The selected place remains available."
            }
        }
    }
}

