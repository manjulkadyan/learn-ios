// Isolated teaching example with synthetic data.
protocol ProviderServing {
    func providers() throws -> [String]
}

extension ProviderServing {
    func displayNames() throws -> [String] {
        try providers().map { name in name.uppercased() }
    }
}

enum ProviderError: Error {
    case offline
}

struct FakeProviderService: ProviderServing {
    let isOffline: Bool

    func providers() throws -> [String] {
        if isOffline {
            throw ProviderError.offline
        }
        return ["Dr. Ada", "Dr. Lin"]
    }
}

func showProviders(
    service: any ProviderServing,
    onNames: ([String]) -> Void
) {
    do {
        let names = try service.displayNames()
        onNames(names)
    } catch ProviderError.offline {
        print("Offline: retry when connected")
    } catch {
        print("Unexpected error: \(error)")
    }
}

showProviders(service: FakeProviderService(isOffline: false)) { names in
    print("Success: \(names.joined(separator: ", "))")
}

showProviders(service: FakeProviderService(isOffline: true)) { names in
    print("Unexpected success: \(names)")
}

struct EmptyProviderService: ProviderServing {
    func providers() throws -> [String] {
        []
    }
}

showProviders(service: EmptyProviderService()) { names in
    print("Empty success: \(names.count) providers")
}

let offlineService: any ProviderServing = FakeProviderService(isOffline: true)
let namesOrNil = try? offlineService.providers()
print("try? failure is nil: \(namesOrNil == nil)")

final class SelectionHandler {
    let onSelect: (String) -> Void

    init(onSelect: @escaping (String) -> Void) {
        self.onSelect = onSelect
    }
}

let prefix = "Selected"
let handler = SelectionHandler { name in
    print("\(prefix): \(name)")
}
handler.onSelect("Dr. Ada")
