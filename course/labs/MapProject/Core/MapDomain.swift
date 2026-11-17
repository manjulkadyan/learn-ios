import Foundation

enum MapInputError: Error { case coordinate, emptyID, duplicateID }

struct Coordinate: Hashable, Codable, Sendable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) throws {
        guard latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            throw MapInputError.coordinate
        }
        self.latitude = latitude
        self.longitude = longitude
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(latitude: values.decode(Double.self, forKey: .latitude),
                      longitude: values.decode(Double.self, forKey: .longitude))
    }
}

struct Place: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let coordinate: Coordinate
}

func checkedPlaces(_ places: [Place]) throws -> [Place] {
    var ids = Set<String>()
    for place in places {
        guard !place.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MapInputError.emptyID
        }
        guard ids.insert(place.id).inserted else { throw MapInputError.duplicateID }
    }
    return places
}

// This token orders requests owned by ONE lane. It is not a server revision.
struct RequestGate: Sendable {
    private(set) var generation: UInt64 = 0

    mutating func invalidate() { generation += 1 }
    mutating func begin() -> UInt64 {
        invalidate()
        return generation
    }
    func accepts(_ token: UInt64) -> Bool { token == generation }
}

enum SearchCancellationReason: Sendable {
    case cancelled, inputChanged

    var message: String {
        switch self {
        case .cancelled: "Search cancelled; previous places remain."
        case .inputChanged: "Query changed; press Search to search again. Previous places remain."
        }
    }
}

// Pure presentation state shared by the host checks and the native request owner.
// Cancellation changes status/authority, while accepted destinations remain usable.
struct PlaceSearchSnapshot: Sendable {
    private(set) var places = demoPlaces
    private(set) var isSearching = false
    private(set) var message = "Fictional saved places. Apple search is optional."
    private(set) var gate = RequestGate()

    mutating func begin() -> UInt64 {
        isSearching = true
        message = "Searching Apple map data…"
        return gate.begin()
    }

    mutating func cancel(reason: SearchCancellationReason = .cancelled) {
        gate.invalidate()
        isSearching = false
        message = reason.message
    }

    mutating func showEmptyQueryPrompt() {
        gate.invalidate()
        isSearching = false
        message = "Enter a query; saved results remain available."
    }

    mutating func accept(_ candidate: [Place], token: UInt64) throws -> Bool {
        guard gate.accepts(token) else { return false }
        let checked = try checkedPlaces(candidate)
        places = checked
        isSearching = false
        message = checked.isEmpty ? "No results. Try another query or restore saved places."
            : "\(checked.count) Apple results; not the fictional fixture."
        return true
    }

    mutating func fail(token: UInt64) -> Bool {
        guard gate.accepts(token) else { return false }
        isSearching = false
        message = "Search failed; previous places remain. Retry or restore saved places."
        return true
    }

    mutating func restoreFixtures() {
        gate.invalidate()
        places = demoPlaces
        isSearching = false
        message = "Fictional saved places restored."
    }
}

enum TravelMode: String, Hashable, Sendable { case walking, automobile }

struct RouteKey: Hashable, Sendable {
    let origin: Coordinate
    let destination: Coordinate
    let mode: TravelMode
}

// Framework-independent units. Host inputs are synthetic; the app extracts
// these values from an actual MKRoute only after an explicit provider request.
struct RouteSummary: Equatable, Sendable {
    let metres: Double
    let seconds: Double
}

enum RouteFreshness: Sendable {
    case fresh
    case cached(age: TimeInterval, lifetime: TimeInterval)
}

func routeEstimateText(_ summary: RouteSummary, freshness: RouteFreshness) -> String {
    guard summary.metres.isFinite, summary.seconds.isFinite,
          summary.metres >= 0, summary.seconds >= 0,
          summary.metres < Double(Int.max),
          summary.seconds / 60 < Double(Int.max) else {
        return "Route estimate unavailable; request directions again."
    }
    let estimate = "Apple estimate: about \(Int(summary.metres)) metres; \(Int(summary.seconds / 60)) minutes."
    switch freshness {
    case .fresh:
        return estimate + " Fresh response."
    case .cached(let age, let lifetime):
        guard age.isFinite, lifetime.isFinite, age >= 0, lifetime > 0,
              age < lifetime, lifetime < Double(Int.max) else {
            return "Cached route expired or invalid; request directions again."
        }
        return estimate + " Cached response, \(Int(age)) seconds old (expiry at \(Int(lifetime)) seconds)."
    }
}

struct TimedCache<Key: Hashable, Value> {
    struct Entry {
        let value: Value
        let insertedAt: TimeInterval
    }
    var entries: [Key: Entry] = [:]
    let lifetime: TimeInterval

    mutating func insert(_ value: Value, for key: Key, now: TimeInterval) {
        entries[key] = Entry(value: value, insertedAt: now)
    }

    mutating func entry(for key: Key, now: TimeInterval) -> Entry? {
        guard let entry = entries[key] else { return nil }
        let age = now - entry.insertedAt
        guard age >= 0, age < lifetime else {
            entries[key] = nil
            return nil
        }
        return entry
    }

    mutating func value(for key: Key, now: TimeInterval) -> Value? {
        entry(for: key, now: now)?.value
    }
}

let demoPlaces: [Place] = [
    Place(id: "demo:lantern", name: "Lantern Library (fictional)",
          coordinate: try! Coordinate(latitude: 37.3317, longitude: -122.0301)),
    Place(id: "demo:paper", name: "Paper Garden (fictional)",
          coordinate: try! Coordinate(latitude: 37.3340, longitude: -122.0260))
]

