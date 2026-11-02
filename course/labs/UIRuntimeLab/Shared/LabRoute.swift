import Foundation

enum LabRoute: String, Hashable {
    case alpha, beta

    static func parse(_ url: URL) -> LabRoute? {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              c.scheme == "uiruntime", c.host == "item",
              c.user == nil, c.password == nil, c.port == nil,
              c.percentEncodedQuery == nil, c.percentEncodedFragment == nil else { return nil }
        switch c.percentEncodedPath {
        case "/alpha": return .alpha
        case "/beta": return .beta
        default: return nil
        }
    }
}

/// Synthetic state policy; installed URL delivery is a separate runtime check.
struct RouteState: Equatable {
    private(set) var selected: LabRoute?

    init(restored: String?, incoming: URL?) {
        if let incoming { selected = LabRoute.parse(incoming) }
        else { selected = restored.flatMap(LabRoute.init(rawValue:)) }
    }

    @discardableResult
    mutating func receive(_ url: URL) -> Bool {
        guard let route = LabRoute.parse(url) else { return false }
        selected = route
        return true
    }
}
