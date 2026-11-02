import UIKit
import os

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let state = Workload.poster.beginInterval("ShellConstruction", id: Workload.poster.makeSignpostID())
        defer { Workload.poster.endInterval("ShellConstruction", state) }
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(rootViewController: LabController())
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
final class LabController: UIViewController, UITableViewDataSource {
    private let projection = UISegmentedControl(items: ["Linear", "Indexed"])
    private let decoding = UISegmentedControl(items: ["Full", "Thumb"])
    private let rendering = UISegmentedControl(items: ["Repeat caption", "Cached caption"])
    private let workers = UISegmentedControl(items: ["1 worker", "4 workers"])
    private let status = UILabel(), table = UITableView()
    private let queue = OperationQueue()
    private let root = FileManager.default.temporaryDirectory.appendingPathComponent("ProfilingLab", isDirectory: true)
    private var rows: [String] = [], captions: [String] = [], images: [UIImage] = []
    private var records: [RawRecord] = [], pending = 0, ordinal = 0
    private var probe: RetentionProbe?
    private weak var witness: RetentionProbe?
    private var pressureToken: NSObjectProtocol?
    private var prepared = false
    private var active: [ProfileOperation] = []
    override func viewDidLoad() {
        super.viewDidLoad(); title = "Profiling Lab"; view.backgroundColor = .systemBackground
        queue.name = "org.example.ProfilingLab.blocking"; queue.qualityOfService = .userInitiated
        [projection, decoding, rendering, workers].forEach { $0.selectedSegmentIndex = 0 }
        let prepare = button("Prepare local fixture", #selector(prepareFixture))
        let run = button("Run four attempts", #selector(runBatch))
        let cancel = button("Cancel batch", #selector(cancelBatch))
        let clear = button("Clear displayed payload", #selector(clearPayload))
        let cycle = button("Create callback cycle", #selector(createCycle))
        let release = button("Release owner", #selector(releaseOwner))
        let repair = button("Break callback cycle", #selector(breakCycle))
        let export = button("Export raw JSON", #selector(exportRecords))
        status.numberOfLines = 0; status.font = .preferredFont(forTextStyle: .caption1)
        status.text = "Prepare before recording. No device measurements supplied."
        table.dataSource = self; table.rowHeight = 92
        rendering.addTarget(self, action: #selector(refreshRows), for: .valueChanged)
        let stack = UIStackView(arrangedSubviews: [prepare, projection, decoding, rendering, workers,
            run, cancel, clear, cycle, release, repair, export, status, table])
        stack.axis = .vertical; stack.spacing = 4; stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        pressureToken = NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil, queue: .main) { [weak self] _ in
                // In-flight required work completes; reduce future concurrency, no retry burst.
                self?.queue.maxConcurrentOperationCount = self?.admittedWorkers() ?? 1
        }
    }
    deinit { if let pressureToken { NotificationCenter.default.removeObserver(pressureToken) }; active.forEach { $0.requestCancellation() } }
    override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); cancelBatch() }
    private func button(_ title: String, _ action: Selector) -> UIButton {
        let b = UIButton(type: .system); b.setTitle(title, for: .normal)
        b.addTarget(self, action: action, for: .touchUpInside); return b
    }
    private static func pressure() -> Pressure {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .critical
        }
    }
    private func admittedWorkers() -> Int {
        Admission.limit(requested: workers.selectedSegmentIndex == 0 ? 1 : 4,
            pressure: Self.pressure(), lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled, speculative: false)
    }
    @objc private func prepareFixture() {
        guard pending == 0 else { return }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try Workload.prepareImage(at: root.appendingPathComponent("square.png"))
            prepared = true; status.text = "Prepared synthetic 2048-square PNG. Creation is outside Work."
        } catch { prepared = false; status.text = "Preparation failed: \(error)" }
    }
    @objc private func runBatch() {
        guard pending == 0 else { return }
        guard prepared else { status.text = "Preparation required; no workload was accepted."; return }
        clearPayload()
        let indexed = projection.selectedSegmentIndex == 1, thumb = decoding.selectedSegmentIndex == 1
        let limit = admittedWorkers(); queue.maxConcurrentOperationCount = limit
        pending = 4; active = []
        for _ in 0..<4 {
            ordinal += 1
            let index = ordinal, id = UUID().uuidString, base = root
            let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            let operation = ProfileOperation { [weak self] operation in
                let startPressure = Self.pressure().rawValue
                let state = Workload.poster.beginInterval("Work", id: Workload.poster.makeSignpostID())
                let start = DispatchTime.now().uptimeNanoseconds
                var outcome = "error", correct: Bool?, result: [String] = [], image: UIImage?
                do {
                    result = try Workload.unique(Workload.inputs(), indexed: indexed, cancelled: { operation.cancellationRequested })
                    if operation.cancellationRequested { throw LabError.cancelled }
                    let bitmap = try Workload.decode(at: base.appendingPathComponent("square.png"), thumbnail: thumb)
                    if operation.cancellationRequested { throw LabError.cancelled }
                    try Workload.roundTrip(result, at: base.appendingPathComponent("\(id).json"), cancelled: { operation.cancellationRequested })
                    image = UIImage(cgImage: bitmap, scale: 3, orientation: .up)
                    outcome = "success"
                } catch LabError.cancelled { outcome = "cancelled" }
                  catch { outcome = "error" }
                let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
                Workload.poster.endInterval("Work", state)
                // Equality checking is outside the timed Work boundary.
                if outcome == "success" { correct = result == Workload.expected(); if correct == false { outcome = "incorrect" } }
                let record = RawRecord(id: id, ordinal: index,
                    variant: "\(indexed ? "indexed" : "linear")-\(thumb ? "thumb" : "full")",
                    fixture: Workload.fixtureID, boundary: "worker-entry-to-model-ready",
                    source: "native-unannotated", configuration: "record-effective-configuration",
                    outcome: outcome, elapsedMS: elapsed, correct: correct,
                    pressureStart: startPressure, pressureEnd: Self.pressure().rawValue,
                    device: "", osBuild: "", revision: "", cachePolicy: "prepared-local-file-os-cache-uncontrolled",
                    workers: limit, lowPower: lowPower)
                let completedRows = result, completedImage = image
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.records.append(record); self.pending -= 1
                    if record.outcome == "success", !operation.cancellationRequested {
                        self.rows = completedRows
                        self.captions = completedRows.map { String($0.reversed().reversed()) }
                        if let completedImage { self.images.append(completedImage) }
                        Workload.poster.emitEvent("ModelApplied")
                        self.table.reloadData()
                    }
                    self.status.text = "\(self.pending) pending; \(self.records.count) raw records. Work excludes queue and presentation."
                    if self.pending == 0 { self.active = [] }
                }
            }
            active.append(operation); queue.addOperation(operation)
        }
    }
    @objc private func cancelBatch() {
        // Do not call Operation.cancel(): it skips main for queued work and loses attempt records.
        active.forEach { $0.requestCancellation() }
    }
    @objc private func clearPayload() { guard pending == 0 else { return }; rows = []; captions = []; images = []; table.reloadData() }
    @objc private func refreshRows() { table.reloadData() }
    @objc private func createCycle() { guard witness == nil else { return }; let p = RetentionProbe(); p.hold(); probe = p; witness = p }
    @objc private func releaseOwner() { probe = nil; status.text = witness == nil ? "Probe released" : "Probe survives: inspect callback retaining path" }
    @objc private func breakCycle() { witness?.stop(); probe = nil; status.text = witness == nil ? "Probe released after stop" : "Another owner remains" }
    @objc private func exportRecords() {
        guard pending == 0 else { status.text = "Wait for batch before export."; return }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let url = root.appendingPathComponent("raw-records.json")
            try encoder.encode(RawEnvelope(schema: 1, records: records)).write(to: url, options: .atomic)
            let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            share.popoverPresentationController?.sourceView = view
            share.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            present(share, animated: true)
        } catch { status.text = "Export failed: \(error)" }
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = table.dequeueReusableCell(withIdentifier: "row") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "row")
        var content = cell.defaultContentConfiguration()
        content.text = rows[indexPath.row]
        if rendering.selectedSegmentIndex == 0 {
            let interval = Workload.poster.beginInterval("Caption", id: Workload.poster.makeSignpostID())
            var text = rows[indexPath.row]
            for _ in 0..<128 { text = String(text.reversed().reversed()) }
            content.secondaryText = text
            Workload.poster.endInterval("Caption", interval)
        } else { content.secondaryText = captions[indexPath.row] }
        content.image = images.first; content.imageProperties.maximumSize = CGSize(width: 80, height: 80)
        cell.contentConfiguration = content; return cell
    }
}
