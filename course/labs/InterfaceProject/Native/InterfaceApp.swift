import SwiftUI
import InterfaceCore

@main
struct InterfaceApp: App {
    var body: some Scene { WindowGroup { DashboardView() } }
}

enum DesignTokens {
    static let gap: CGFloat = 16
    static let corner: CGFloat = 18
    static let minimumControl: CGFloat = 44
    static let accent = Color.accentColor
}

struct NotebookButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, DesignTokens.gap)
            .padding(.vertical, 10)
            .frame(minHeight: DesignTokens.minimumControl)
            .background(DesignTokens.accent.opacity(enabled ? 0.16 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.corner))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct NotebookTile: View {
    let card: BoardCard
    let togglePin: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: card.id) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(card.title).font(.headline)
                    Text("\(card.minutes) minutes").font(.subheadline)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .accessibilityIdentifier("open-\(card.id)")
            Button(action: togglePin) {
                Label(card.pinned ? "Unpin" : "Pin", systemImage: card.pinned ? "pin.fill" : "pin")
            }
            .buttonStyle(NotebookButtonStyle())
            .accessibilityValue(card.pinned ? "Pinned" : "Not pinned")
            .accessibilityIdentifier("pin-\(card.id)")
        }
        .padding(DesignTokens.gap)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: DesignTokens.corner))
        .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded { value in
            guard InteractionPolicy.shouldTogglePin(dx: value.translation.width, dy: value.translation.height) else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { togglePin() }
        })
        .accessibilityAction(named: card.pinned ? "Unpin notebook" : "Pin notebook", togglePin)
    }
}

struct DashboardView: View {
    @State private var board = Board.sample
    @State private var pinMessage: String?
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        NavigationStack {
            GeometryReader { region in
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.gap) {
                        ViewThatFits(in: .horizontal) {
                            HStack { Text("Notebook board").font(.title); Spacer(); total }
                            VStack(alignment: .leading) { Text("Notebook board").font(.title); total }
                        }
                        if let pinMessage {
                            Text(pinMessage).foregroundStyle(.red)
                                .accessibilityIdentifier("pin-error")
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .top), count:
                            InteractionPolicy.columns(width: max(0, region.size.width - 32), accessibilityText: textSize.isAccessibilitySize)), spacing: DesignTokens.gap) {
                            ForEach(board.cards) { card in
                                NotebookTile(card: card) { togglePin(id: card.id) }
                            }
                        }
                        Text("Notebook feed").font(.title2).accessibilityAddTraits(.isHeader)
                        // This is a fixture feed of current cards, not an audit log.
                        ForEach(Array(board.cards.reversed())) { card in
                            NavigationLink(value: card.id) {
                                Label("\(card.title): \(card.minutes) minutes", systemImage: "book")
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }
                        }
                    }
                    .padding(DesignTokens.gap)
                }
            }
            .navigationTitle("Notebooks")
            .navigationDestination(for: String.self) { id in NotebookDetail(board: $board, id: id) }
        }
    }

    private var total: some View {
        Text("\(board.totalMinutes) minutes planned").font(.body)
            .accessibilityIdentifier("board-total")
    }

    private func togglePin(id: String) {
        switch board.togglePin(id: id) {
        case .toggled:
            pinMessage = nil
        case .missing:
            pinMessage = "This notebook was removed. No pin change was saved."
        case .revisionExhausted:
            pinMessage = "This notebook's revision limit was reached. No pin change was saved."
        }
    }
}

struct NotebookDetail: View {
    @Binding var board: Board
    let id: String
    @State private var editor: BoardCard?
    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let card = board.card(id: id) {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.gap) {
                        Text(card.title).font(.largeTitle)
                        Text("Plan: \(card.minutes) minutes")
                        Button("Edit notebook") { editor = card }
                            .accessibilityIdentifier("edit-notebook")
                        Button(expanded ? "Hide plan" : "Show plan") {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { expanded.toggle() }
                        }
                        if expanded {
                            Text("Read for \(card.minutes) minutes, then write one useful note.")
                                .transition(reduceMotion ? .identity : .opacity)
                        }
                        Button("Delete notebook", role: .destructive) { board.remove(id: id) }
                    }
                    .buttonStyle(NotebookButtonStyle())
                    .padding(DesignTokens.gap)
                }
            } else {
                ContentUnavailableView("Notebook removed", systemImage: "book.closed", description: Text("Return to the board to choose another notebook."))
            }
        }
        .navigationTitle("Notebook detail")
        .sheet(item: $editor) { card in NotebookEditor(board: $board, card: card) }
    }
}

struct NotebookEditor: View {
    @Binding var board: Board
    @State private var draft: CardDraft
    @State private var message: String?
    @FocusState private var focused: Field?
    @Environment(\.dismiss) private var dismiss

    init(board: Binding<Board>, card: BoardCard) {
        _board = board; _draft = State(initialValue: CardDraft(card: card))
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $draft.title)
                    .focused($focused, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focused = .minutes }
                    .accessibilityIdentifier("draft-title")
                TextField("Minutes (1–240)", text: $draft.minutesText)
                    .keyboardType(.numberPad)
                    .focused($focused, equals: .minutes)
                    .accessibilityIdentifier("draft-minutes")
                if let message {
                    Text(message).foregroundStyle(.red)
                        .accessibilityIdentifier("draft-error")
                }
            }
            .navigationTitle("Edit notebook")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).accessibilityIdentifier("save-draft")
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = nil } }
            }
        }
    }

    private func save() {
        switch board.save(draft) {
        case .saved: focused = nil; dismiss()
        case .invalid(let field):
            focused = field
            message = field == .title ? "Enter a title." : "Enter whole minutes from 1 through 240."
        case .conflict:
            message = "This notebook changed. Your draft is retained. Cancel and reopen to review the current version."
        case .missing:
            message = "This notebook was removed. Your draft is retained so you can copy its text."
        case .revisionExhausted:
            focused = nil
            message = "This notebook's revision limit was reached. Your draft is retained so you can copy its text. No changes were saved."
        }
    }
}

#Preview("Default board") { DashboardView() }
#Preview("Large text") { DashboardView().environment(\.dynamicTypeSize, .accessibility3) }
#Preview("System motion preference") { DashboardView() }
