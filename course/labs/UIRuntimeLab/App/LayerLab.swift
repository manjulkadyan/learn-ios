import SwiftUI
import UIKit

final class MovingLayerView: UIView {
    private let marker = CALayer()
    private var previousWidth: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground
        marker.bounds = CGRect(x: 0, y: 0, width: 28, height: 28)
        marker.cornerRadius = 14
        marker.backgroundColor = UIColor.systemBlue.cgColor
        layer.addSublayer(marker)
    }
    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width != previousWidth else { return }
        if previousWidth == 0 {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            marker.position = CGPoint(x: bounds.midX, y: bounds.midY)
            CATransaction.commit()
        } else {
            freeze()
            CATransaction.begin(); CATransaction.setDisableActions(true)
            marker.position = CGPoint(x: min(max(14, marker.position.x), max(14, bounds.width - 14)),
                                      y: bounds.midY)
            CATransaction.commit()
        }
        previousWidth = bounds.width
    }

    func move(to fraction: CGFloat) {
        layoutIfNeeded()
        let start = marker.presentation()?.position ?? marker.position
        let end = CGPoint(x: 14 + max(0, bounds.width - 28) * fraction, y: bounds.midY)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        marker.removeAnimation(forKey: "travel")
        marker.position = end
        if !UIAccessibility.isReduceMotionEnabled {
            let animation = CABasicAnimation(keyPath: "position")
            animation.fromValue = NSValue(cgPoint: start)
            animation.toValue = NSValue(cgPoint: end)
            animation.duration = 1.5
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            marker.add(animation, forKey: "travel")
        }
        CATransaction.commit()
    }

    func freeze() {
        let visible = marker.presentation()?.position ?? marker.position
        CATransaction.begin(); CATransaction.setDisableActions(true)
        marker.position = visible
        marker.removeAnimation(forKey: "travel")
        CATransaction.commit()
    }

    var diagnostic: String {
        let sample = marker.presentation().map { String(format: "%.1f", $0.position.x) } ?? "unavailable"
        return "Model x: \(String(format: "%.1f", marker.position.x)); presentation x: \(sample)"
    }
}

final class LayerController: UIViewController {
    private let canvas = MovingLayerView()
    private let label = UILabel()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground; label.numberOfLines = 0
        let left = button("Move left", #selector(goLeft))
        let right = button("Move right", #selector(goRight))
        let freeze = button("Freeze visible position", #selector(stop))
        let sample = button("Sample model and presentation", #selector(sampleNow))
        canvas.heightAnchor.constraint(equalToConstant: 120).isActive = true
        let stack = UIStackView(arrangedSubviews: [canvas, left, right, freeze, sample, label])
        stack.axis = .vertical; stack.spacing = 12; stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16)
        ])
    }
    private func button(_ title: String, _ action: Selector) -> UIButton {
        let b = UIButton(type: .system); b.setTitle(title, for: .normal)
        b.addTarget(self, action: action, for: .touchUpInside); return b
    }
    @objc private func goLeft() { canvas.move(to: 0); sampleNow() }
    @objc private func goRight() { canvas.move(to: 1); sampleNow() }
    @objc private func stop() { canvas.freeze(); sampleNow() }
    @objc private func sampleNow() { label.text = canvas.diagnostic }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated); canvas.freeze()
    }
}

struct LayerPanel: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> LayerController { LayerController() }
    func updateUIViewController(_ controller: LayerController, context: Context) {}
}
