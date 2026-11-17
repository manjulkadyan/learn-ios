import Foundation

@main
struct MarketChecks {
    static func main() throws {
        func rejects(_ work: () throws -> Void) -> Bool {
            do { try work(); return false } catch { return true }
        }
        let rows = try AssetDecoder.decode(syntheticMarketJSON)
        let a = try AssetDecoder.decimal("0.10")
        let b = try AssetDecoder.decimal("0.20")
        precondition(a + b == Decimal(string: "0.30"))
        precondition(rejects { _ = try AssetDecoder.decimal("12.30oops") })
        precondition(rejects { _ = try AssetDecoder.decimal("12.30\n") })
        precondition(rejects { _ = try AssetDecoder.decimal(String(repeating: "9", count: 38)) })
        precondition(rejects { _ = try AssetDecoder.decimal("-1.00") })
        precondition(rejects { _ = try AssetDecoder.decimal("0.123456789") })
        let repeated = Data(String(decoding: syntheticMarketJSON, as: UTF8.self)
            .replacingOccurrences(of: "\"id\":\"pebble\"", with: "\"id\":\"luma\"").utf8)
        precondition(rejects { _ = try AssetDecoder.decode(repeated) })
        let unordered = Data(String(decoding: syntheticMarketJSON, as: UTF8.self)
            .replacingOccurrences(of: "\"second\":120", with: "\"second\":60").utf8)
        precondition(rejects { _ = try AssetDecoder.decode(unordered) })
        print("PASS decimal grammar/arithmetic, duplicate assets, duplicate sample times")

        let exactCases = [
            ("0.00000001", "0.00000001"),
            ("12.345678", "12.345678"),
            ("00012.34000000", "12.34"),
            ("0.00000000", "0")
        ]
        for (input, expectedText) in exactCases {
            let amount = try AssetDecoder.decimal(input)
            let canonical = canonicalDecimalText(amount)
            precondition(canonical == expectedText)
            precondition(exactSampleText(amount) == "USD " + expectedText)
            let roundTrip = try AssetDecoder.decimal(canonical)
            precondition(roundTrip == amount)
        }
        print("PASS tiny/high-precision canonical sample text, value round-trip, zero normalization")

        let url = URL(string: "https://fixture.invalid/assets")!
        let badStatus = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil,
                                        headerFields: ["Content-Type": "application/json"])!
        precondition(rejects { _ = try AssetDecoder.decodeHTTP(data: syntheticMarketJSON, response: badStatus) })
        let badType = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                      headerFields: ["Content-Type": "text/html"])!
        precondition(rejects { _ = try AssetDecoder.decodeHTTP(data: syntheticMarketJSON, response: badType) })
        let ok = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                 headerFields: ["Content-Type": "application/json; charset=utf-8"])!
        let validHTTP = try AssetDecoder.decodeHTTP(data: syntheticMarketJSON, response: ok)
        precondition(validHTTP == rows)
        print("PASS HTTP status and MIME before decode; synthetic response only")

        var state = MarketSnapshot()
        let first = state.begin()
        state.complete(.success(rows), token: first)
        let stale = state.begin()
        let latest = state.begin()
        state.complete(.success([]), token: stale)
        precondition(state.assets == rows)
        state.complete(.failure(MarketError.status(503)), token: latest)
        precondition(state.assets == rows && state.message.hasPrefix("Refresh failed"))
        let cancelled = state.begin()
        state.cancel()
        state.complete(.success([]), token: cancelled)
        state.complete(.failure(MarketError.status(404)), token: stale)
        precondition(state.assets == rows && state.message.hasPrefix("Refresh cancelled"))
        var resource = MarketRequestGate()
        let resourceToken = resource.begin()
        let snapshotToken = state.begin()
        resource.invalidate()
        precondition(!resource.accepts(resourceToken))
        precondition(state.gate.accepts(snapshotToken))
        print("PASS old success/error, cancellation invalidation, last-known rows")

        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("MarketProject-checks-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let storeURL = scratch.appendingPathComponent("favorites.json")
        var store = try FavoritesStore(url: storeURL)
        try store.set("luma", selected: true)
        try store.set("luma", selected: true)
        precondition(rejects { try store.set("pebble\n", selected: true) })
        let reopened = try FavoritesStore(url: storeURL)
        precondition(reopened.ids == ["luma"])
        precondition(rejects {
            try store.set("pebble", selected: true, write: { _, _ in throw MarketError.tooLarge })
        })
        precondition(store.ids == ["luma"])
        let savedBytes = try Data(contentsOf: storeURL)
        precondition(savedBytes.count > 0)
        try Data("broken".utf8).write(to: storeURL)
        precondition(rejects { _ = try FavoritesStore(url: storeURL) })
        let preservedBytes = try Data(contentsOf: storeURL)
        precondition(preservedBytes == Data("broken".utf8))
        try Data(#"{"version":2,"ids":["luma"]}"#.utf8).write(to: storeURL)
        precondition(rejects { _ = try FavoritesStore(url: storeURL) })
        let duplicateIDs = Data(#"{"version":1,"ids":["luma","luma"]}"#.utf8)
        try duplicateIDs.write(to: storeURL)
        precondition(rejects { _ = try FavoritesStore(url: storeURL) })
        let preservedDuplicates = try Data(contentsOf: storeURL)
        precondition(preservedDuplicates == duplicateIDs)
        print("PASS favorite idempotence/reopen, failed-write rollback, corruption preserved, version refusal")
        print("MarketProject: 5 behavior groups passed; no HTTP or image requests")
    }
}

