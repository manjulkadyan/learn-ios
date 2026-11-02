import SwiftUI

struct WorkshopCard: ViewModifier {
    func body(content: Content) -> some View {
        content.padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }
}
extension View {
    func workshopCard() -> some View { modifier(WorkshopCard()) }
}
struct WorkshopButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).padding(.horizontal, 16).padding(.vertical, 12)
            .foregroundStyle(enabled ? Color.white : Color.secondary)
            .background(enabled ? Color.indigo : Color.gray.opacity(0.15), in: Capsule())
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

struct DraftEditor: View {
    @Bindable var draft: PracticeDraft
    @FocusState private var nameFocused: Bool
    var body: some View {
        TextField("Synthetic name", text: $draft.name)
            .textInputAutocapitalization(.words).submitLabel(.done).focused($nameFocused)
            .onSubmit { nameFocused = false }
            .accessibilityIdentifier("draft.name")
        Toggle("Enable demo reminder", isOn: $draft.reminders)
        Stepper("Cards: \(draft.count)", value: $draft.count, in: 1...10)
        Slider(value: $draft.intensity, in: 0...1) { Text("Intensity") }
            .accessibilityValue(draft.intensity.formatted(.percent.precision(.fractionLength(0))))
        Picker("Category", selection: $draft.category) {
            Text("Personal").tag("Personal")
            Text("Practice").tag("Practice")
        }
        DatePicker("Practice time", selection: $draft.date, displayedComponents: [.date, .hourAndMinute])
        TextEditor(text: $draft.notes).frame(minHeight: 90).accessibilityLabel("Synthetic notes")
        Button("End editing") { nameFocused = false }
    }
}

private struct DraftSummary: View {
    let draft: PracticeDraft
    var body: some View {
        Label(draft.valid ? "Ready: \(draft.name)" : "Enter a name to continue", systemImage: draft.valid ? "checkmark.circle" : "pencil")
            .accessibilityElement(children: .combine)
    }
}

private enum SheetChoice: String, Identifiable {
    case help, editor
    var id: String { rawValue }
}

struct SwiftUIGallery: View {
    @Environment(PracticeDraft.self) private var draft
    @Environment(WorkbenchRouter.self) private var router
    @Environment(\.workbenchPolicy) private var policy
    @State private var search = ""
    @State private var items = FixtureItem.samples
    @State private var sheet: SheetChoice?
    @State private var fullScreen = false
    @State private var popover = false
    @State private var showAlert = false
    @State private var confirmReset = false
    @State private var selectedTask = "alpha"
    @State private var taskStatus = "Pending local task"
    @State private var editEvents = 0
    private var filtered: [FixtureItem] {
        items.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            Form {
                Section("Controls and shared Observation model") {
                    Text(policy.label).font(.caption)
                    DraftEditor(draft: draft)
                    DraftSummary(draft: draft)
                    Text("Name change events: \(editEvents)").font(.caption)
                    Button("Show validation result") { showAlert = true }
                        .buttonStyle(WorkshopButtonStyle()).disabled(!draft.valid)
                }
                Section("Stable list identity; pull to refresh") {
                    ForEach(filtered) { item in
                        NavigationLink(value: GalleryRoute.item(item.id)) {
                            Label(item.title, systemImage: "doc.text").accessibilityHint("Opens a synthetic card")
                        }
                    }
                    if filtered.isEmpty { Text("No matching fixtures") }
                    NavigationLink("Adaptive split gallery", value: GalleryRoute.split)
                }
                Section("Presentations") {
                    Button("Help sheet") { sheet = .help }
                    Button("Edit shared draft in sheet") { sheet = .editor }
                    Button("Full screen cover") { fullScreen = true }
                    Button("Popover") { popover = true }.popover(isPresented: $popover) {
                        Text("A popover can adapt to a sheet on a compact screen.").padding()
                    }
                    Button("Reset name", role: .destructive) { confirmReset = true }
                }
                Section("View tasks and change observation") {
                    Picker("Local task input", selection: $selectedTask) {
                        ForEach(FixtureItem.samples) { Text($0.title).tag($0.id) }
                    }
                    Text(taskStatus).accessibilityIdentifier("gallery.taskStatus")
                    Text("Switch quickly. The old delayed task must not replace the newest result.").font(.caption)
                }
                Section("Flexible layout and accessibility") {
                    AdaptiveCard(title: draft.valid ? draft.name : "Synthetic card with a long descriptive title")
                    Text(router.status).font(.caption)
                }
            }
            .navigationTitle("SwiftUI workbench")
            .searchable(text: $search, prompt: "Search synthetic cards")
            .refreshable {
                do {
                    try await Task.sleep(for: .milliseconds(250))
                    try Task.checkCancellation()
                    items = FixtureItem.samples
                } catch { /* Cancellation leaves existing fixtures intact. */ }
            }
            .navigationDestination(for: GalleryRoute.self) { route in
                switch route {
                case .item(let id): CardDetail(id: id)
                case .split: SplitGallery()
                }
            }
            .sheet(item: $sheet) { choice in
                NavigationStack {
                    Group {
                        if choice == .editor { Form { DraftEditor(draft: draft) } }
                        else { Text("The app owns the model; this sheet edits the same draft.").padding() }
                    }
                    .navigationTitle(choice == .editor ? "Shared draft" : "Help")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { sheet = nil } } }
                }.presentationDetents([.medium, .large])
            }
            .fullScreenCover(isPresented: $fullScreen) { CoverDemo() }
            .alert("Synthetic draft ready", isPresented: $showAlert) { Button("OK", role: .cancel) {} }
                message: { Text("No reminder is scheduled by this toggle. Use the Platform button explicitly.") }
            .confirmationDialog("Clear the in-memory name?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Clear name", role: .destructive) { draft.name = "" }
            }
            .onChange(of: draft.name) { _, _ in editEvents += 1 }
            .task(id: selectedTask) {
                let input = selectedTask
                taskStatus = "Working locally for \(input)…"
                do {
                    try await Task.sleep(for: .milliseconds(700))
                    try Task.checkCancellation()
                    guard input == selectedTask else { return }
                    taskStatus = "Completed current task: \(input)"
                } catch { /* An obsolete task never overwrites the current status. */ }
            }
        }
    }
}

private struct CoverDemo: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 20) {
            Text("Independent presentation").font(.title)
            Button("Dismiss cover") { dismiss() }.buttonStyle(WorkshopButtonStyle())
        }.padding()
    }
}

struct AdaptiveCard: View {
    let title: String
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        ViewThatFits(in: .horizontal) {
            if !typeSize.isAccessibilitySize {
                HStack { Text(title).fixedSize(); badge }
            }
            VStack(alignment: .leading, spacing: 8) { Text(title); badge }
        }
        .font(.body).workshopCard()
        .accessibilityElement(children: .combine)
    }
    private var badge: some View { Label("Local fixture", systemImage: "checkmark.seal") }
}

struct CardDetail: View {
    let id: String
    var body: some View {
        let item = FixtureItem.samples.first { $0.id == id }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AdaptiveCard(title: item?.title ?? "Missing fixture")
                Text(item?.detail ?? "This route does not resolve to a fixture.")
                Text("Route identity: \(id)").font(.caption)
            }.padding()
        }.navigationTitle("Synthetic detail")
    }
}

struct SplitGallery: View {
    @State private var selected: String? = "alpha"
    var body: some View {
        NavigationSplitView {
            List(FixtureItem.samples, selection: $selected) { item in
                NavigationLink(item.title, value: item.id)
            }.navigationTitle("Cards")
        } detail: {
            if let selected { CardDetail(id: selected) }
            else { ContentUnavailableView("Choose a card", systemImage: "doc.text") }
        }
    }
}

#Preview("Controls and environment") {
    SwiftUIGallery().environment(PracticeDraft()).environment(WorkbenchRouter())
        .environment(\.workbenchPolicy, WorkbenchPolicy(label: "Preview only", tint: .orange))
}
#Preview("Accessibility text") {
    AdaptiveCard(title: "Long synthetic title that must remain readable at large text sizes")
        .environment(\.dynamicTypeSize, .accessibility3).padding()
}
