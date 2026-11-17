import SwiftUI
import AppShell
import BrowseFeature
import SavedFeature
import NoteDomain

@main
struct ArchitectureApp: App {
    var body: some Scene { WindowGroup { ArchitectureRoot() } }
}

@MainActor
struct ArchitectureRoot: View {
    @State private var shell = Shell()
    var body: some View {
        @Bindable var shell = shell
        NavigationStack(path: $shell.path) {
            TabView(selection: $shell.tab) {
                BrowseScreen(model: shell.browse, refresh: shell.refresh, open: shell.open)
                    .tabItem { Label("Browse", systemImage: "list.bullet") }.tag(NoteTab.browse)
                SavedScreen(model: shell.saved, open: shell.open)
                    .tabItem { Label("Saved", systemImage: "bookmark") }.tag(NoteTab.saved)
            }
            .navigationTitle("Field Notes: \(shell.account)")
            .navigationDestination(for: Route.self) { route in
                DetailScreen(shell: shell, route: route).id(shell.sessionID)
            }
            .toolbar {
                Button("Switch demo account") {
                    Task { await shell.switchAccount(to: shell.account == "demo-a" ? "demo-b" : "demo-a"); shell.refresh() }
                }.disabled(shell.switching)
            }
        }
        .task { shell.refresh() }
        .onDisappear { shell.stop() }
    }
}

@MainActor
private struct BrowseScreen: View {
    let model: BrowseModel
    let refresh: () -> Void
    let open: (String) -> Void
    var body: some View {
        VStack {
            switch model.state {
            case .idle: Text("Choose Reload to begin")
            case .loading: ProgressView("Loading notes")
            case .failed: Text("Notes unavailable. Try Reload.")
            case .ready(let notes):
                List(notes) { note in Button(note.title) { open(note.id) } }
            }
            Button("Reload", action: refresh)
        }
    }
}

@MainActor
private struct SavedScreen: View {
    let model: SavedModel
    let open: (String) -> Void
    var body: some View {
        VStack {
            if model.failed { Text("Saved notes unavailable. Retry.") }
            if model.notes.isEmpty { Text("No saved notes in this demo account") }
            List(model.notes) { note in Button(note.title) { open(note.id) } }
            Button("Update saved list") { Task { await model.reload() } }
        }.task { await model.reload() }
    }
}

@MainActor
private struct DetailScreen: View {
    let shell: Shell
    let route: Route
    @State private var note: Note?
    @State private var unavailable = false
    var body: some View {
        VStack(spacing: 16) {
            if let note {
                Text(note.title)
                Button("Toggle saved") { Task { await shell.toggleSaved(route) } }
            } else if unavailable {
                Text("This note is unavailable in the current account")
            } else { ProgressView("Opening note") }
            Button("Return to root") { shell.path.removeAll() }
        }
        .padding()
        .task(id: route) {
            note = nil; unavailable = false
            do {
                let result = try await shell.resolve(route)
                try Task.checkCancellation()
                note = result
            } catch { if !Task.isCancelled { unavailable = true } }
        }
    }
}
