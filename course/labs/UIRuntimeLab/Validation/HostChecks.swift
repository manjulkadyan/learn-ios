import Foundation
import CoreGraphics

@main
enum HostChecks {
    static func main() {
        let a = FlowMetric(size: CGSize(width: 40, height: 20), baseline: 15, breakBefore: false)
        let b = FlowMetric(size: CGSize(width: 50, height: 30), baseline: 20, breakBefore: false)
        let c = FlowMetric(size: CGSize(width: 30, height: 10), baseline: 8, breakBefore: true)
        let wide = FlowMath.arrange([a,b,c], width: 120, gap: 8, rowGap: 12)
        precondition(wide.origins == [CGPoint(x: 0,y: 5), CGPoint(x: 48,y: 0), CGPoint(x: 0,y: 42)])
        precondition(wide.size == CGSize(width: 120, height: 52))
        let narrow = FlowMath.arrange([a,b], width: 70, gap: 8, rowGap: 12)
        precondition(narrow.origins[1] == CGPoint(x: 0, y: 32) && narrow.size.height == 62)
        let forced = FlowMetric(size: b.size, baseline: b.baseline, breakBefore: true)
        let forcedPlan = FlowMath.arrange([a,forced], width: 120, gap: 8, rowGap: 12)
        precondition(forcedPlan.origins == [CGPoint(x: 0,y: 0), CGPoint(x: 0,y: 32)])
        precondition(forcedPlan.size.height == 62)
        let empty = FlowMath.arrange([], width: 120, gap: 8, rowGap: 12)
        precondition(empty.size == .zero && empty.origins.isEmpty)
        let oversize = FlowMetric(size: CGSize(width: 150,height: 20), baseline: 15, breakBefore: false)
        let over = FlowMath.arrange([oversize], width: 100, gap: 8, rowGap: 12)
        precondition(over.origins[0].x == 0 && over.size.width == 100)
        let zero = FlowMath.arrange([a,b], width: 0, gap: -1, rowGap: -2)
        precondition(zero.size.height == 50 && zero.origins[1].y == 20)
        let changed = FlowMetric(size: CGSize(width: 50,height: 48), baseline: 35, breakBefore: false)
        precondition(FlowMath.arrange([a,changed], width: 120,gap: 8,rowGap: 12).size.height == 48)
        let alpha = URL(string: "uiruntime://item/alpha")!, beta = URL(string: "uiruntime://item/beta")!
        precondition(LabRoute.parse(alpha) == .alpha && LabRoute.parse(beta) == .beta)
        precondition(RouteState(restored: "alpha", incoming: beta).selected == .beta)
        precondition(RouteState(restored: "beta", incoming: nil).selected == .beta)
        precondition(RouteState(restored: "removed", incoming: nil).selected == nil)
        var state = RouteState(restored: "alpha", incoming: nil)
        precondition(state.receive(beta) && state.selected == .beta)
        let rejected = [
            "uiruntime://item/gamma", "uiruntime://item/alpha/extra",
            "uiruntime://item/%61lpha", "uiruntime://item/alpha?x=1",
            "uiruntime://item/alpha#x", "uiruntime://user@item/alpha",
            "uiruntime://item:80/alpha", "https://item/alpha", "uiruntime://other/alpha"
        ]
        for value in rejected {
            let u = URL(string: value)!
            precondition(LabRoute.parse(u) == nil)
            precondition(!state.receive(u) && state.selected == .beta)
            precondition(RouteState(restored: "alpha", incoming: u).selected == nil)
        }
        print("PASS: 7 logical geometry scenarios; restoration/cold/warm policy and 9 rejected URL fixtures; native RTL unobserved")
    }
}
