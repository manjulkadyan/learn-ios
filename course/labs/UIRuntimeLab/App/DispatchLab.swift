import SwiftUI
import UIKit

final class PassThroughOverlay: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}

final class DispatchController: UIViewController {
    private let record = CounterRecord()
    private var observation: NSKeyValueObservation?
    private let label = UILabel()
    private let pad = UIView()
    private var lastAction = "No gesture"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        label.numberOfLines = 0
        let increment = UIButton(type: .system)
        increment.setTitle("Increment observed value", for: .normal)
        increment.addTarget(self, action: #selector(incrementCount), for: .touchUpInside)
        let reset = UIButton(type: .system)
        reset.setTitle("Reset via responder chain", for: .normal)
        reset.addTarget(nil, action: #selector(resetCount(_:)), for: .touchUpInside)
        pad.backgroundColor = .secondarySystemBackground
        pad.accessibilityLabel = "Single or double tap demonstration"
        pad.heightAnchor.constraint(equalToConstant: 100).isActive = true
        let single = UITapGestureRecognizer(target: self, action: #selector(singleTap))
        let double = UITapGestureRecognizer(target: self, action: #selector(doubleTap))
        double.numberOfTapsRequired = 2
        single.require(toFail: double)
        pad.addGestureRecognizer(single); pad.addGestureRecognizer(double)
        let stack = UIStackView(arrangedSubviews: [label, increment, reset, pad])
        stack.axis = .vertical; stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16)
        ])
        // The decorative overlay occupies the same region but empty pixels pass through.
        let overlay = PassThroughOverlay()
        overlay.backgroundColor = .clear
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: stack.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: stack.bottomAnchor)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        observation?.invalidate()
        observation = record.observe(\.count, options: [.initial, .new]) { [weak self] _, change in
            // This lab confines every writer to UIKit's main thread.
            precondition(Thread.isMainThread)
            guard let self, let count = change.newValue else { return }
            self.label.text = "Observed count: \(count)\n\(self.lastAction)"
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        observation?.invalidate(); observation = nil
    }

    @objc private func incrementCount() { record.count += 1 }
    @objc private func resetCount(_ sender: Any?) { record.count = 0 }
    @objc private func singleTap() { lastAction = "Single recognized"; record.count += 1 }
    @objc private func doubleTap() { lastAction = "Double recognized"; record.count += 10 }
}

struct DispatchPanel: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> DispatchController { DispatchController() }
    func updateUIViewController(_ controller: DispatchController, context: Context) {}
}
