import Foundation
import CoreGraphics

struct FlowMetric: Equatable {
    let size: CGSize
    let baseline: CGFloat
    let breakBefore: Bool
}

struct FlowPlan: Equatable {
    let size: CGSize
    let origins: [CGPoint]
}

/// Logical geometry only; SwiftUI Layout performs RTL reflection at placement.
enum FlowMath {
    static func arrange(_ items: [FlowMetric], width: CGFloat,
                        gap: CGFloat, rowGap: CGFloat) -> FlowPlan {
        precondition(width.isFinite && width >= 0)
        precondition(items.allSatisfy {
            $0.size.width.isFinite && $0.size.height.isFinite &&
            $0.size.width >= 0 && $0.size.height >= 0 && $0.baseline.isFinite
        })
        guard !items.isEmpty else { return FlowPlan(size: .zero, origins: []) }
        let gap = max(0, gap), rowGap = max(0, rowGap)
        var rows: [[Int]] = [], row: [Int] = [], used: CGFloat = 0
        for i in items.indices {
            let next = row.isEmpty ? items[i].size.width : used + gap + items[i].size.width
            if !row.isEmpty && (items[i].breakBefore || next > width) {
                rows.append(row); row = []; used = 0
            }
            used += (row.isEmpty ? 0 : gap) + items[i].size.width
            row.append(i)
        }
        rows.append(row)
        var origins = Array(repeating: CGPoint.zero, count: items.count)
        var y: CGFloat = 0
        for (rowIndex, indices) in rows.enumerated() {
            let ascent = indices.map { max(0, items[$0].baseline) }.max() ?? 0
            let descent = indices.map { max(0, items[$0].size.height - items[$0].baseline) }.max() ?? 0
            var x: CGFloat = 0
            for i in indices {
                origins[i] = CGPoint(x: x, y: y + ascent - items[i].baseline)
                x += items[i].size.width + gap
            }
            y += ascent + descent + (rowIndex == rows.count - 1 ? 0 : rowGap)
        }
        // Oversize children keep their logical origin and overflow the width budget.
        return FlowPlan(size: CGSize(width: width, height: y), origins: origins)
    }
}
