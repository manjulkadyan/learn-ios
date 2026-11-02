import SwiftUI
import UIKit

final class ProcessDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        print("UIRuntimeLab: process launch")
        return true
    }
}

/// Main-thread UIKit expiration callbacks retire only this scene's synthetic attempt.
@MainActor
final class CheckpointRunner: ObservableObject {
    @Published private(set) var status = "No checkpoint"
    private var identifier: UIBackgroundTaskIdentifier = .invalid
    private var work: Task<Void, Never>?
    private var generation: UUID?

    func start() {
        finish("Replaced")
        let ticket = UUID()
        generation = ticket
        identifier = UIApplication.shared.beginBackgroundTask(withName: "Synthetic checkpoint") { [weak self] in
            guard self?.generation == ticket else { return }
            self?.finish("Expired")
        }
        guard identifier != .invalid else {
            generation = nil; status = "Execution extension unavailable"; return
        }
        status = "Synthetic checkpoint pending"
        work = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(2)) }
            catch { return }
            guard !Task.isCancelled, self?.generation == ticket else { return }
            self?.finish("Synthetic checkpoint completed; no durable write")
        }
    }
    func finish(_ outcome: String) {
        generation = nil
        work?.cancel(); work = nil
        let old = identifier; identifier = .invalid
        if old != .invalid { UIApplication.shared.endBackgroundTask(old) }
        status = outcome
    }
}

@main
struct UIRuntimeApp: App {
    @UIApplicationDelegateAdaptor(ProcessDelegate.self) private var delegate
    var body: some Scene { WindowGroup { RuntimeSceneRoot() } }
}

struct RuntimeSceneRoot: View {
    @Environment(\.scenePhase) private var phase
    @SceneStorage("uiruntime.route.v1") private var storedRoute = ""
    @State private var routeError = ""
    @StateObject private var checkpoint = CheckpointRunner()

    private var path: Binding<[LabRoute]> {
        Binding(get: { RouteState(restored: storedRoute, incoming: nil).selected.map { [$0] } ?? [] },
                set: { storedRoute = $0.last?.rawValue ?? "" })
    }
    var body: some View {
        NavigationStack(path: path) {
            TabView {
                DispatchPanel().tabItem { Label("Routing", systemImage: "hand.tap") }
                LayerPanel().tabItem { Label("Layers", systemImage: "circle") }
                LayoutPanel().tabItem { Label("Layout", systemImage: "rectangle.3.group") }
                VStack(spacing: 16) {
                    Text("Scene phase: \(String(describing: phase))")
                    Text(checkpoint.status)
                    Button("Run bounded synthetic checkpoint") { checkpoint.start() }
                    Button("Cancel checkpoint") { checkpoint.finish("Cancelled by user") }
                    Button("Open Alpha in this scene") { storedRoute = LabRoute.alpha.rawValue }
                    Text(routeError)
                }.padding().tabItem { Label("Lifecycle", systemImage: "square.stack") }
            }
            .navigationDestination(for: LabRoute.self) { route in
                Text("Synthetic detail: \(route.rawValue)").navigationTitle(route.rawValue.capitalized)
            }
        }
        .onOpenURL { url in
            var state = RouteState(restored: storedRoute, incoming: nil)
            if state.receive(url) {
                storedRoute = state.selected?.rawValue ?? ""; routeError = ""
            } else { routeError = "Unsupported synthetic route" }
        }
        .onChange(of: phase, initial: true) { _, newPhase in
            print("UIRuntimeLab: scene phase \(newPhase)")
        }
        .onDisappear { checkpoint.finish("Scene root removed") }
    }
}
