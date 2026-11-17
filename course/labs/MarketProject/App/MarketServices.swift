import Foundation
import Combine

protocol MarketService {
    func assets() -> AnyPublisher<[Asset], Error>
}

struct FixtureMarketService: MarketService {
    let fail: Bool
    func assets() -> AnyPublisher<[Asset], Error> {
        if fail {
            return Fail(error: MarketError.status(503)).eraseToAnyPublisher()
        }
        return Just(syntheticMarketJSON)
            .tryMap(AssetDecoder.decode)
            .eraseToAnyPublisher()
    }
}

// Real URLSession integration, deliberately not the app's default service.
// A learner must explicitly supply an approved HTTPS endpoint with the documented schema.
struct HTTPMarketService: MarketService {
    let endpoint: URL
    let session: URLSession

    func assets() -> AnyPublisher<[Asset], Error> {
        guard endpoint.scheme == "https", endpoint.host != nil else {
            return Fail(error: MarketError.invalidID).eraseToAnyPublisher()
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        return session.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse else {
                    throw MarketError.contentType
                }
                return try AssetDecoder.decodeHTTP(data: output.data, response: response)
            }
            .eraseToAnyPublisher()
    }
}

// Alternative one-shot boundary. async suspends its caller; this has no UI mutation.
// Do not wrap this in Future and assume subscription cancellation cancels a Task.
enum AsyncHTTPMarketService {
    static func assets(endpoint: URL, session: URLSession) async throws -> [Asset] {
        guard endpoint.scheme == "https", endpoint.host != nil else { throw MarketError.invalidID }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw MarketError.contentType }
        return try AssetDecoder.decodeHTTP(data: data, response: http)
    }
}

@MainActor
final class MarketModel: ObservableObject {
    @Published private(set) var snapshot = MarketSnapshot()
    @Published private(set) var favorites = Set<String>()
    @Published private(set) var persistenceMessage = ""
    @Published var query = ""
    private var subscription: AnyCancellable?
    private var store: FavoritesStore?

    init() {
        do {
            let folder = try FileManager.default.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("SyntheticMarketLab", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let store = try FavoritesStore(url: folder.appendingPathComponent("favorites.json"))
            self.store = store
            favorites = store.ids
        } catch {
            persistenceMessage = "Favorites unavailable. Existing file is preserved; inspect it before resetting."
            // Keep store nil: do not overwrite a corrupt or future-version file.
        }
    }

    var visible: [Asset] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return snapshot.assets }
        return snapshot.assets.filter {
            $0.name.localizedCaseInsensitiveContains(needle) ||
            $0.symbol.localizedCaseInsensitiveContains(needle)
        }
    }

    func refresh(fail: Bool = false) { load(service: FixtureMarketService(fail: fail)) }

    func load(service: any MarketService) {
        subscription?.cancel()
        let token = snapshot.begin()
        // receive(on:) schedules downstream delivery, not upstream decoding.
        // Task explicitly crosses into actor-isolated state. The token still
        // rejects an obsolete value after that hop has already been enqueued.
        subscription = service.assets()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard case .failure(let error) = completion else { return }
                Task { @MainActor [weak self] in
                    self?.snapshot.complete(.failure(error), token: token)
                }
            }, receiveValue: { [weak self] assets in
                Task { @MainActor [weak self] in
                    self?.snapshot.complete(.success(assets), token: token)
                }
            })
    }

    func cancel() {
        snapshot.cancel()
        subscription?.cancel()
        subscription = nil
    }

    func toggleFavorite(_ id: String) {
        guard var store else {
            persistenceMessage = "Favorites are unavailable until the preserved store is repaired."
            return
        }
        do {
            try store.set(id, selected: !favorites.contains(id))
            self.store = store
            favorites = store.ids
            persistenceMessage = "Favorite selection saved locally."
        } catch {
            persistenceMessage = "Save failed. The previous favorite selection remains."
        }
    }
}

