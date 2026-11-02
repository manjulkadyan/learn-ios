import Foundation

enum WorkbenchLink {
    static let allowedIDs: Set<String> = ["alpha", "beta", "gamma"]
    static func itemID(from url: URL) -> String? {
        guard url.absoluteString.utf8.count <= 512,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "workbench", parts.host == "gallery",
              parts.user == nil, parts.password == nil, parts.port == nil,
              parts.query == nil, parts.fragment == nil else { return nil }
        // Work with the encoded path so encoded separators/aliases are rejected.
        let components = parts.percentEncodedPath.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count == 3, components[0].isEmpty, components[1] == "item",
              allowedIDs.contains(String(components[2])) else { return nil }
        return String(components[2])
    }
}
