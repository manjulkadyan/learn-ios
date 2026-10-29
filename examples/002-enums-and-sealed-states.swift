// Isolated teaching example. Strings are synthetic; no UI or network actions run.
enum LocationAction: Equatable {
    case getDirections(locationURI: String)
    case contactDoctor(phoneNumber: String)
}

func describe(_ action: LocationAction) -> String {
    switch action {
    case let .getDirections(locationURI):
        return "Directions: \(locationURI)"
    case let .contactDoctor(phoneNumber):
        return "Contact: \(phoneNumber)"
    }
}

let actions: [LocationAction] = [
    .getDirections(locationURI: "geo:0,0"),
    .contactDoctor(phoneNumber: "555-0100"),
]

for action in actions {
    print(describe(action))
}

let original = LocationAction.getDirections(locationURI: "geo:0,0")
var edited = original
edited = .contactDoctor(phoneNumber: "555-0100")
print("original unchanged: \(original == .getDirections(locationURI: "geo:0,0"))")

enum SearchState: Equatable {
    case idle
    case loading
    case loaded(providers: [String])
    case failed(message: String)
}

func title(for state: SearchState) -> String {
    switch state {
    case .idle:
        return "Start a search"
    case .loading:
        return "Loading"
    case let .loaded(providers):
        return "\(providers.count) providers"
    case let .failed(message):
        return "Error: \(message)"
    }
}

let states: [SearchState] = [
    .idle,
    .loading,
    .loaded(providers: ["Dr. A", "Dr. B"]),
    .failed(message: "Try again"),
]

for state in states {
    print(title(for: state))
}

if case let .loaded(providers) = states[2] {
    print("loaded payload: \(providers.joined(separator: ", "))")
}

enum CancellationReason: String {
    case scheduleConflict = "Patient_ScheduleConflict"
    case other = "Patient_OtherReason"
}

print("raw value: \(CancellationReason.scheduleConflict.rawValue)")
print("unknown raw value is nil: \(CancellationReason(rawValue: "new_reason") == nil)")
