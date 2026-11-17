import Foundation

enum MarketError: Error, Equatable {
    case status(Int), contentType, tooLarge, duplicateID, invalidPrice
    case invalidID, invalidSeries, unsupportedStore, invalidFavorites
}

struct PricePoint: Equatable, Sendable {
    let second: Int64
    let amount: Decimal
}

struct Asset: Identifiable, Equatable, Sendable {
    let id: String
    let symbol: String
    let name: String
    let priceUSD: Decimal
    let points: [PricePoint]
    let iconURL: URL?
}

// Canonical numeric value, independent of locale and currency display rounding.
// Decimal does not preserve the input's redundant zeroes or original scale.
func canonicalDecimalText(_ amount: Decimal) -> String {
    var value = amount
    return NSDecimalString(&value, Locale(identifier: "en_US_POSIX"))
}

func exactSampleText(_ amount: Decimal) -> String {
    "USD \(canonicalDecimalText(amount))"
}

enum AssetDecoder {
    private struct PointDTO: Decodable { let second: Int64; let amount: String }
    private struct AssetDTO: Decodable {
        let id: String
        let symbol: String
        let name: String
        let priceUSD: String
        let points: [PointDTO]
        let iconURL: URL?
    }

    static func decimal(_ text: String) throws -> Decimal {
        // JSON amounts are decimal strings. Restrict the grammar before Decimal,
        // which may otherwise accept a valid numeric prefix of malformed text.
        guard text.count <= 37,
              text.range(of: #"^[0-9]+(\.[0-9]{1,8})?\z"#, options: .regularExpression) != nil,
              let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")),
              !value.isNaN else { throw MarketError.invalidPrice }
        return value
    }

    static func decode(_ data: Data) throws -> [Asset] {
        guard data.count <= 1_048_576 else { throw MarketError.tooLarge }
        let decoded = try JSONDecoder().decode([AssetDTO].self, from: data)
        var ids = Set<String>()
        return try decoded.map { dto in
            guard dto.id.range(of: #"^[a-z][a-z0-9-]{0,39}\z"#, options: .regularExpression) != nil,
                  !dto.symbol.isEmpty, !dto.name.isEmpty else { throw MarketError.invalidID }
            guard ids.insert(dto.id).inserted else { throw MarketError.duplicateID }
            let points = try dto.points.map { PricePoint(second: $0.second, amount: try decimal($0.amount)) }
            guard points.count <= 1000,
                  zip(points, points.dropFirst()).allSatisfy({ $0.second < $1.second }) else {
                throw MarketError.invalidSeries
            }
            if let url = dto.iconURL {
                guard url.scheme == "https", url.host != nil else { throw MarketError.invalidID }
            }
            return Asset(id: dto.id, symbol: dto.symbol, name: dto.name,
                         priceUSD: try decimal(dto.priceUSD), points: points, iconURL: dto.iconURL)
        }
    }

    static func decodeHTTP(data: Data, response: HTTPURLResponse) throws -> [Asset] {
        guard (200...299).contains(response.statusCode) else { throw MarketError.status(response.statusCode) }
        guard response.mimeType == "application/json" else { throw MarketError.contentType }
        return try decode(data)
    }
}

struct MarketRequestGate: Sendable {
    private(set) var generation: UInt64 = 0
    mutating func begin() -> UInt64 { generation += 1; return generation }
    mutating func invalidate() { generation += 1 }
    func accepts(_ token: UInt64) -> Bool { generation == token }
}

// Known rows survive a failed refresh. The message communicates freshness.
struct MarketSnapshot: Sendable {
    private(set) var assets: [Asset] = []
    private(set) var message = "Not loaded."
    private(set) var gate = MarketRequestGate()

    mutating func begin() -> UInt64 {
        message = assets.isEmpty ? "Loading." : "Refreshing; previous synthetic rows remain."
        return gate.begin()
    }
    mutating func cancel() {
        gate.invalidate()
        message = assets.isEmpty ? "Cancelled; retry is available." : "Refresh cancelled; previous rows remain."
    }
    mutating func complete(_ result: Result<[Asset], Error>, token: UInt64) {
        guard gate.accepts(token) else { return }
        switch result {
        case .success(let next): assets = next; message = "Synthetic snapshot loaded."
        case .failure: message = "Refresh failed; previous rows remain."
        }
    }
}

struct FavoritesStore {
    private struct Document: Codable { let version: Int; let ids: [String] }
    private(set) var ids: Set<String>
    let url: URL

    init(url: URL) throws {
        self.url = url
        guard FileManager.default.fileExists(atPath: url.path) else { ids = []; return }
        let document = try JSONDecoder().decode(Document.self, from: Data(contentsOf: url))
        guard document.version == 1 else { throw MarketError.unsupportedStore }
        guard document.ids.count <= 10_000,
              Set(document.ids).count == document.ids.count,
              document.ids.allSatisfy({
                  $0.range(of: #"^[a-z][a-z0-9-]{0,39}\z"#, options: .regularExpression) != nil
              }) else { throw MarketError.invalidFavorites }
        ids = Set(document.ids)
    }

    // Publish the new in-memory selection only AFTER the write succeeds.
    mutating func set(_ id: String, selected: Bool,
                      write: (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }) throws {
        guard id.range(of: #"^[a-z][a-z0-9-]{0,39}\z"#, options: .regularExpression) != nil else {
            throw MarketError.invalidFavorites
        }
        var next = ids
        if selected { next.insert(id) } else { next.remove(id) }
        guard next.count <= 10_000 else { throw MarketError.invalidFavorites }
        let data = try JSONEncoder().encode(Document(version: 1, ids: next.sorted()))
        try write(data, url)
        ids = next
    }
}

let syntheticMarketJSON = Data(#"""
[
  {"id":"luma","symbol":"LUM","name":"Luma sample","priceUSD":"12.30",
   "points":[{"second":0,"amount":"12.10"},{"second":60,"amount":"12.30"},{"second":120,"amount":"12.20"}]},
  {"id":"pebble","symbol":"PEB","name":"Pebble sample","priceUSD":"0.10",
   "points":[{"second":0,"amount":"0.08"},{"second":60,"amount":"0.10"},{"second":120,"amount":"0.09"}]}
]
"""#.utf8)

