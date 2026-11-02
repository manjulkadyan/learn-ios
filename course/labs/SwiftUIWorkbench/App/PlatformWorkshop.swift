import SwiftUI
import PhotosUI

struct PlatformWorkshop: View {
    @Environment(AppServices.self) private var services
    @Environment(WorkbenchRouter.self) private var router
    @Environment(\.scenePhase) private var phase
    @State private var photoItem: PhotosPickerItem?
    @State private var webVisible = false
    @State private var document = 0
    @State private var cookieCommand = WebCommand()
    @State private var webStatus = "Web view is not installed"
    @State private var sceneStatus = "Scene active"
    @State private var notificationBusy = false
    var body: some View {
        @Bindable var camera = services.camera
        NavigationStack {
            Form {
                Section("Explicit effects only") {
                    Text("No network requests, account data, automatic permission prompts, or provider invocation. All device actions begin with your tap.")
                    Text(sceneStatus).font(.caption)
                }
                Section("Local notifications and routes") {
                    Button("Request notification permission") {
                        notificationBusy = true
                        Task { await services.notifications.requestPermission(); notificationBusy = false }
                    }.disabled(notificationBusy)
                    Button("Schedule synthetic notification in 5 seconds") {
                        notificationBusy = true
                        Task { await services.notifications.schedule(); notificationBusy = false }
                    }.disabled(notificationBusy)
                    Button("Clear workshop notification") { services.notifications.clear() }.disabled(notificationBusy)
                    Text(services.notifications.status).font(.caption)
                    Button("Open local Alpha route") { router.open(URL(string: "workbench://gallery/item/alpha")!) }
                    Text(router.status).font(.caption)
                }
                Section("Local WebKit boundary") {
                    Toggle("Install web view", isOn: $webVisible)
                    if webVisible {
                        LocalWebView(document: document, command: cookieCommand, status: $webStatus).frame(height: 230)
                        Button("Replace local document") { document += 1 }
                        Button("Install synthetic cookie") { cookieCommand = WebCommand(id: cookieCommand.id + 1, clear: false) }
                        Button("Clear ephemeral cookies") { cookieCommand = WebCommand(id: cookieCommand.id + 1, clear: true) }
                    }
                    Text(webStatus).font(.caption)
                }
                Section("Retained system authentication adapter") {
                    Text(services.authentication.status).font(.caption)
                    Text("No provider start button is configured. Review start(url:callbackScheme:anchor:) and add state/PKCE validation before any provider use.").font(.caption)
                    Button("Cancel / demonstrate cleanup") { services.authentication.cancel() }
                }
                Section("PhotosPicker and transferable loading") {
                    PhotosPicker(selection: $photoItem, matching: .images, preferredItemEncoding: .compatible) {
                        Label("Choose a practice image", systemImage: "photo")
                    }
                    if let image = services.photos.image {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180)
                            .accessibilityLabel("Selected practice image")
                    }
                    Text(services.photos.status).font(.caption)
                    Button("Cancel load / clear image") { services.photos.cancel(); photoItem = nil }
                }
                Section("Location ownership") {
                    Button("Request permission and one location fix") { services.location.requestOneFix() }
                    Button("Cancel location request") { services.location.cancel() }
                    Text(services.location.status).font(.caption)
                }
                Section("System still camera ownership") {
                    Button("Request camera and capture") { Task { await services.camera.requestCapture() } }
                    Button("Cancel camera request") { services.camera.cancel() }
                    Text(services.camera.status).font(.caption)
                    if let image = services.camera.image {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180)
                            .accessibilityLabel("In-memory camera capture")
                        Button("Clear capture") { services.camera.clearImage() }
                    }
                }
                Section("Widget and intent") {
                    Text("The embedded widget uses independent synthetic timeline entries. Its intent returns a synthetic dialog. Neither shares app storage or claims App Group durability.")
                }
            }
            .navigationTitle("Platform adapters")
            .onChange(of: photoItem) { _, item in services.photos.select(item) }
            .onChange(of: phase) { _, phase in
                sceneStatus = "Scene: \(String(describing: phase))"
                if phase == .background {
                    services.location.cancel()
                    services.camera.cancel()
                    services.authentication.cancel()
                    services.photos.cancel()
                }
            }
            .onDisappear {
                services.location.cancel()
                services.camera.cancel()
                services.photos.cancel()
                services.authentication.cancel()
            }
            .sheet(isPresented: $camera.presenting, onDismiss: { camera.presentationEnded() }) {
                CameraCapture(adapter: camera).ignoresSafeArea()
            }
        }
    }
}
