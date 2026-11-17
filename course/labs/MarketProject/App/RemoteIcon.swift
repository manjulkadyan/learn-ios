import SwiftUI
import UIKit
import Combine

@MainActor
final class IconLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var failed = false
    private var request: AnyCancellable?
    private var gate = MarketRequestGate()

    func load(_ url: URL?) {
        stop()
        image = nil
        failed = false
        guard let url else { return } // synthetic rows have no remote icon
        guard url.scheme == "https" else { failed = true; return }
        let token = gate.begin()
        var input = URLRequest(url: url)
        input.timeoutInterval = 10
        request = URLSession.shared.dataTaskPublisher(for: input)
            .tryMap { output -> Data in
                guard let response = output.response as? HTTPURLResponse,
                      (200...299).contains(response.statusCode),
                      response.mimeType?.hasPrefix("image/") == true,
                      output.data.count <= 262_144 else { throw MarketError.tooLarge }
                return output.data
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard case .failure = completion else { return }
                Task { @MainActor [weak self] in
                    guard let self, self.gate.accepts(token) else { return }
                    self.failed = true
                }
            }, receiveValue: { [weak self] data in
                Task { @MainActor [weak self] in
                    guard let self, self.gate.accepts(token) else { return }
                    self.image = UIImage(data: data)
                    self.failed = self.image == nil
                }
            })
    }

    func stop() {
        gate.invalidate()
        request?.cancel()
        request = nil
    }
}

struct RemoteIcon: View {
    let url: URL?
    @StateObject private var loader = IconLoader()
    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: loader.failed ? "photo.badge.exclamationmark" : "circle.hexagongrid.fill")
            }
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true) // asset text carries identity
        .onAppear { loader.load(url) }
        .onChange(of: url) { _, next in loader.load(next) }
        .onDisappear { loader.stop() }
    }
}

