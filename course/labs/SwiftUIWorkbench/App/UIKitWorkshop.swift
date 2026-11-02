import SwiftUI
import UIKit

struct UIKitWorkshop: View {
    @State private var items = FixtureItem.samples
    @State private var selection = "No selection"
    @State private var text = "Edit this growing UIKit text view. The binding updates SwiftUI."
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button("Rename Alpha") {
                        if let index = items.firstIndex(where: { $0.id == "alpha" }) {
                            items[index].title = items[index].title == "Alpha card" ? "Renamed Alpha" : "Alpha card"
                        }
                    }
                    Button("Reverse") { items.reverse() }
                }
                Text(selection).accessibilityIdentifier("uikit.selection")
                DiffableList(items: items) { selection = "Selected \($0)" }.frame(minHeight: 180)
                Text("Dynamic UIKit representable").font(.headline)
                GrowingTextView(text: $text).accessibilityLabel("UIKit text editor")
                Text("Characters: \(text.count)").font(.caption)
                Spacer(minLength: 0)
            }.padding().navigationTitle("UIKit bridge")
        }
    }
}

struct DiffableList: UIViewControllerRepresentable {
    var items: [FixtureItem]
    var onSelect: (String) -> Void
    func makeUIViewController(context: Context) -> FixtureListController {
        let controller = FixtureListController(style: .plain)
        controller.onSelect = onSelect
        controller.update(items)
        return controller
    }
    func updateUIViewController(_ controller: FixtureListController, context: Context) {
        controller.onSelect = onSelect
        controller.update(items)
    }
    static func dismantleUIViewController(_ controller: FixtureListController, coordinator: ()) {
        controller.onSelect = nil
    }
}

final class FixtureListController: UITableViewController {
    var onSelect: ((String) -> Void)?
    private var records: [String: FixtureItem] = [:]
    private var dataSource: UITableViewDiffableDataSource<Int, String>!
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "fixture")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        dataSource = UITableViewDiffableDataSource(tableView: tableView) { [weak self] table, indexPath, id in
            let cell = table.dequeueReusableCell(withIdentifier: "fixture", for: indexPath)
            var content = cell.defaultContentConfiguration()
            content.text = self?.records[id]?.title
            content.secondaryText = self?.records[id]?.detail
            content.textProperties.numberOfLines = 0
            content.secondaryTextProperties.numberOfLines = 0
            cell.contentConfiguration = content
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }
    func update(_ items: [FixtureItem]) {
        loadViewIfNeeded()
        records = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let old = Set(dataSource.snapshot().itemIdentifiers)
        var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
        snapshot.appendSections([0])
        snapshot.appendItems(items.map(\.id))
        snapshot.reconfigureItems(items.map(\.id).filter { old.contains($0) })
        dataSource.apply(snapshot, animatingDifferences: view.window != nil)
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let id = dataSource.itemIdentifier(for: indexPath) else { return }
        tableView.deselectRow(at: indexPath, animated: true)
        onSelect?(id)
    }
}

struct GrowingTextView: UIViewRepresentable {
    @Binding var text: String
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.isScrollEnabled = false
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 8
        return view
    }
    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        // Do not overwrite marked text while an input method is composing.
        if view.text != text, view.markedTextRange == nil {
            let previous = view.selectedRange
            view.text = text
            let count = (text as NSString).length
            let start = min(previous.location, count)
            view.selectedRange = NSRange(location: start, length: min(previous.length, count - start))
        }
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 300
        return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    }
    static func dismantleUIView(_ view: UITextView, coordinator: Coordinator) { view.delegate = nil }
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: GrowingTextView
        init(_ parent: GrowingTextView) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
    }
}

#Preview("UIKit updates") { UIKitWorkshop() }
