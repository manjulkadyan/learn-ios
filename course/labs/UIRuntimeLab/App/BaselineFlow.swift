import SwiftUI

struct RowBreakKey: LayoutValueKey {
    static let defaultValue = false
}

struct BaselineFlow: Layout {
    var gap: CGFloat = 8
    var rowGap: CGFloat = 12

    struct Signature: Equatable {
        let width: CGFloat
        let items: [FlowMetric]
        let gap: CGFloat
        let rowGap: CGFloat
    }
    struct Cache {
        var signature: Signature?
        var plan: FlowPlan?
    }
    func makeCache(subviews: Subviews) -> Cache { Cache() }
    func updateCache(_ cache: inout Cache, subviews: Subviews) { cache = Cache() }

    private func plan(width proposed: CGFloat?, subviews: Subviews, cache: inout Cache)
        -> (FlowPlan, [FlowMetric]) {
        let ideals = subviews.map { $0.sizeThatFits(.unspecified) }
        let idealWidth = ideals.reduce(0) { $0 + $1.width } + max(0, gap) * CGFloat(max(0, ideals.count - 1))
        let width = proposed.flatMap { $0.isFinite ? max(0, $0) : nil } ?? idealWidth
        let items = subviews.indices.map { i -> FlowMetric in
            let p = ProposedViewSize(width: min(width, ideals[i].width), height: nil)
            let d = subviews[i].dimensions(in: p)
            return FlowMetric(size: CGSize(width: d.width, height: d.height),
                              baseline: d[.firstTextBaseline],
                              breakBefore: subviews[i][RowBreakKey.self])
        }
        let signature = Signature(width: width, items: items, gap: max(0, gap),
                                  rowGap: max(0, rowGap))
        if cache.signature != signature {
            cache.signature = signature
            cache.plan = FlowMath.arrange(items, width: width, gap: gap, rowGap: rowGap)
        }
        return (cache.plan!, items)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews,
                     cache: inout Cache) -> CGSize {
        plan(width: proposal.width, subviews: subviews, cache: &cache).0.size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout Cache) {
        let result = plan(width: bounds.width, subviews: subviews, cache: &cache).0
        for i in subviews.indices {
            // These are logical coordinates. SwiftUI flips placement in RTL;
            // a numeric UnitPoint anchor does not opt out of that behavior.
            subviews[i].place(at: CGPoint(x: bounds.minX + result.origins[i].x,
                                         y: bounds.minY + result.origins[i].y),
                             anchor: UnitPoint(x: 0, y: 0),
                             proposal: ProposedViewSize(width: min(bounds.width, subviews[i].sizeThatFits(.unspecified).width), height: nil))
        }
    }
}
