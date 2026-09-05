import Cocoa

private let chartTooltipWidth: CGFloat = 188

enum ChartTooltipLayout {
    static func isCompact(rowCount: Int) -> Bool {
        rowCount > 8
    }

    static func estimatedHeight(rowCount: Int, compact: Bool) -> CGFloat {
        let safeRowCount = max(rowCount, 0)
        return compact
            ? CGFloat(30 + safeRowCount * 12)
            : CGFloat(38 + safeRowCount * 17)
    }

    static func position(
        anchor: CGPoint,
        containerSize: CGSize,
        rowCount: Int,
        compact: Bool = false
    ) -> CGPoint {
        let tooltipHeight = estimatedHeight(rowCount: rowCount, compact: compact)
        let margin: CGFloat = 8
        let x = min(
            max(anchor.x, chartTooltipWidth / 2 + margin),
            max(chartTooltipWidth / 2 + margin, containerSize.width - chartTooltipWidth / 2 - margin)
        )
        let showBelow = anchor.y < tooltipHeight + margin * 2
        let rawY =
            showBelow
            ? anchor.y + tooltipHeight / 2 + margin
            : anchor.y - tooltipHeight / 2 - margin
        let y = min(
            max(rawY, tooltipHeight / 2 + margin),
            max(tooltipHeight / 2 + margin, containerSize.height - tooltipHeight / 2 - margin)
        )
        return CGPoint(x: x, y: y)
    }
}
