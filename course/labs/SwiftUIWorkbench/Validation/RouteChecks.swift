import Foundation

@main struct RouteChecks {
    static func main() {
        let accepted = ["alpha", "beta", "gamma"]
        for id in accepted {
            precondition(WorkbenchLink.itemID(from: URL(string: "workbench://gallery/item/\(id)")!) == id)
        }
        let rejected = [
            "https://gallery/item/alpha", "workbench://evil/item/alpha",
            "workbench://gallery.evil/item/alpha", "workbench://user@gallery/item/alpha",
            "workbench://gallery:80/item/alpha", "workbench://gallery/item/alpha?next=beta",
            "workbench://gallery/item/alpha#detail", "workbench://gallery/item/unknown",
            "workbench://gallery/item/alpha/extra", "workbench://gallery//item/alpha",
            "workbench://gallery/item/%61lpha", "workbench://gallery/item/alpha%2Fextra",
            "workbench://gallery/item/", "workbench://gallery/item/" + String(repeating: "a", count: 600)
        ]
        for raw in rejected {
            precondition(WorkbenchLink.itemID(from: URL(string: raw)!) == nil, "Unexpected route: \(raw)")
        }
        print("Route checks passed: \(accepted.count) accepted, \(rejected.count) rejected")
    }
}
