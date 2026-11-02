import SwiftUI
import SwiftData
import Observation

enum WorkbenchTab: Hashable { case gallery, uikit, stores, platform }
enum GalleryRoute: Hashable { case item(String), split }

struct FixtureItem: Identifiable, Hashable {
    let id: String
    var title: String
    var detail: String
    static let samples = [
        FixtureItem(id: "alpha", title: "Alpha card", detail: "A synthetic morning task"),
        FixtureItem(id: "beta", title: "Beta card", detail: "A synthetic afternoon task"),
        FixtureItem(id: "gamma", title: "Gamma card", detail: "A synthetic evening task")
    ]
}

@MainActor @Observable
final class WorkbenchRouter {
    var tab = WorkbenchTab.gallery
    var path: [GalleryRoute] = []
    var status = "No incoming link"

    // Closed vocabulary: no arbitrary destinations, accounts, or web URLs.
    static func itemID(from url: URL) -> String? {
        WorkbenchLink.itemID(from: url)
    }

    func open(_ url: URL) {
        guard let id = Self.itemID(from: url) else {
            status = "Rejected unsupported link"
            return
        }
        tab = .gallery
        path = [.item(id)]
        status = "Accepted synthetic card: \(id)"
    }
}

@MainActor @Observable
final class PracticeDraft {
    var name = ""
    var reminders = false
    var count = 1
    var intensity = 0.5
    var category = "Personal"
    var date = Date()
    var notes = "Synthetic notes only"
    var valid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

struct WorkbenchPolicy {
    var label = "Local synthetic workspace"
    var tint: Color = .indigo
}
private struct PolicyKey: EnvironmentKey {
    static let defaultValue = WorkbenchPolicy()
}
extension EnvironmentValues {
    var workbenchPolicy: WorkbenchPolicy {
        get { self[PolicyKey.self] }
        set { self[PolicyKey.self] = newValue }
    }
}

@MainActor @Observable
final class AppServices {
    let router = WorkbenchRouter()
    let draft = PracticeDraft()
    let coreData: CoreDataStore
    let notifications: NotificationAdapter
    let location = LocationAdapter()
    let camera = CameraAdapter()
    let authentication = SystemAuthAdapter()
    let photos = PhotoSelection()
    @ObservationIgnored let modelContainer: ModelContainer?
    let storageError: String?

    init(preview: Bool = false) {
        coreData = CoreDataStore(inMemory: preview)
        notifications = NotificationAdapter(router: router, installDelegate: !preview)
        do {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: preview)
            modelContainer = try ModelContainer(for: PracticeNote.self, configurations: configuration)
            storageError = nil
        } catch {
            modelContainer = nil
            storageError = "SwiftData failed to open: \(error.localizedDescription)"
        }
    }
}

@main
struct WorkbenchApp: App {
    @State private var services = AppServices()
    var body: some Scene {
        WindowGroup {
            if let container = services.modelContainer {
                WorkbenchRoot()
                    .environment(services)
                    .environment(services.router)
                    .environment(services.draft)
                    .environment(\.workbenchPolicy, WorkbenchPolicy())
                    .modelContainer(container)
            } else {
                ContentUnavailableView("Local store unavailable", systemImage: "externaldrive.badge.exclamationmark",
                    description: Text(services.storageError ?? "Unknown store error"))
            }
        }
    }
}

struct WorkbenchRoot: View {
    @Environment(WorkbenchRouter.self) private var router
    @Environment(\.workbenchPolicy) private var policy
    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            SwiftUIGallery().tabItem { Label("Gallery", systemImage: "square.grid.2x2") }.tag(WorkbenchTab.gallery)
            UIKitWorkshop().tabItem { Label("UIKit", systemImage: "rectangle.3.group") }.tag(WorkbenchTab.uikit)
            PersistenceWorkshop().tabItem { Label("Stores", systemImage: "externaldrive") }.tag(WorkbenchTab.stores)
            PlatformWorkshop().tabItem { Label("Platform", systemImage: "gearshape") }.tag(WorkbenchTab.platform)
        }
        .tint(policy.tint)
        .onOpenURL { router.open($0) }
    }
}

#Preview("App with isolated fixtures") {
    let services = AppServices(preview: true)
    if let container = services.modelContainer {
        WorkbenchRoot().environment(services).environment(services.router).environment(services.draft)
            .modelContainer(container)
            .environment(\.workbenchPolicy, WorkbenchPolicy(label: "Preview fixtures", tint: .teal))
    }
}
