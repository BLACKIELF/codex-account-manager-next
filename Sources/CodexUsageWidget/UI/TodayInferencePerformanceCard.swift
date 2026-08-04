import SwiftUI

struct TodayInferencePerformanceCard: View {
    let history: ModelInferencePerformanceHistory?
    let language: WidgetLanguage

    @State private var period: ModelInferencePeriod = .today

    private var performance: ModelInferencePerformance? {
        history?.performance(for: period)
    }

    private var groups: [ModelInferencePerformanceGroup] {
        performance?.displayGroups() ?? []
    }

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 6) {
                DashboardCardHeader(
                    title: language.text("实测推理表现", "Observed inference"),
                    systemName: "gauge.with.dots.needle.50percent",
                    helpTitle: language.text("统计规则与观看方法", "Statistics and chart guide"),
                    helpText: chartAlgorithmHelp
                ) {
                    InferencePeriodControl(selection: $period, language: language)
                }

                if groups.isEmpty {
                    compactEmptyState
                } else if let performance {
                    InferencePerformanceScatterPlot(performance: performance, language: language)
                }
            }
        }
    }

    private var chartAlgorithmHelp: String {
        return language.text(
            "数据：按模型 × 推理强度汇总所选周期内本机完成的模型调用；历史样本只保存在本机。\n横轴：窗口内完整调用耗时 P50；横线延伸至 P90，上限为所有组合最大 P90 的 1.4 倍。\n纵轴：窗口内全部输出 tokens（含 Reasoning）÷ 完整调用耗时。\n气泡：今日代表调用数，7 日与 28 日代表记录覆盖期内的日均调用数；不是 Session、线程或工具调用数。\n说明：Reasoning 占比是 token 占比，不是耗时占比；指标不是 TTFT 或可见文本解码 TPS。",
            "Data: completed on-device calls in the selected window, grouped by model × reasoning effort; history stays on this Mac.\nX: full-call duration P50 within the window; whiskers extend to P90, with the axis capped at 1.4× the largest P90.\nY: all output tokens, including reasoning, divided by full-call duration within the window.\nBubble: call count for Today, and daily-average calls over recorded coverage for 7 and 28 days—not session, thread, or tool-call counts.\nNote: reasoning share is a token share, not a duration share; this is not TTFT or visible-text decode TPS."
        )
    }

    private var compactEmptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.dots.scatter")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.tertiary)
            VStack(alignment: .leading, spacing: 3) {
                Text(emptyStateTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(language.text(
                    "完成带推理强度的 Codex 调用后，本机会持续记录",
                    "This Mac keeps recording completed Codex calls with reasoning effort"
                ))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .accessibilityElement(children: .combine)
    }

    private var emptyStateTitle: String {
        switch period {
        case .today:
            language.text("今天还没有足够记录", "Not enough records today")
        case .sevenDays:
            language.text("最近 7 日还没有足够记录", "Not enough records in the last 7 days")
        case .twentyEightDays:
            language.text("最近 28 日还没有足够记录", "Not enough records in the last 28 days")
        }
    }
}

private struct InferencePeriodControl: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.visualTokens) private var visualTokens
    @Binding var selection: ModelInferencePeriod
    let language: WidgetLanguage

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ModelInferencePeriod.allCases) { period in
                Button {
                    selection = period
                } label: {
                    Text(label(for: period))
                        .font(.system(size: 9, weight: selection == period ? .semibold : .medium))
                        .foregroundStyle(selection == period ? Color.white : Color.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(selection == period ? visualTokens.accent.primary.color : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == period ? .isSelected : [])
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(FixedVisualPalette.controlFill(colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(FixedVisualPalette.controlStroke(colorScheme), lineWidth: 0.8)
                )
        )
    }

    private func label(for period: ModelInferencePeriod) -> String {
        switch period {
        case .today: language.text("今日", "Today")
        case .sevenDays: language.text("7 日均", "7d avg")
        case .twentyEightDays: language.text("28 日均", "28d avg")
        }
    }
}

private struct InferencePerformanceScatterPlot: View {
    let performance: ModelInferencePerformance
    let language: WidgetLanguage

    private var groups: [ModelInferencePerformanceGroup] {
        performance.displayGroups()
    }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.visualTokens) private var visualTokens
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredGroupID: String?
    @State private var hoverAnchor: CGPoint = .zero

    private let plotLeft: CGFloat = 34
    private let plotRight: CGFloat = 12
    private let plotTop: CGFloat = 8
    private let plotBottom: CGFloat = 20
    private let tooltipWidth: CGFloat = 188
    private let axisDivisionCount = 4

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let width = max(size.width - plotLeft - plotRight, 1)
            let height = max(size.height - plotTop - plotBottom, 1)
            let maximumDuration = max((groups.map(\.p90DurationSeconds).max() ?? 1) * 1.4, 1)
            let maximumThroughput = max((groups.map(\.effectiveOutputTokensPerSecond).max() ?? 1) * 1.16, 1)
            let maximumCalls = max(groups.map(\.averageDailyCallCount).max() ?? 1, 1)

            ZStack(alignment: .topLeading) {
                chartGrid(size: size, width: width, height: height)

                ForEach(groups) { group in
                    let y = yPosition(
                        group.effectiveOutputTokensPerSecond,
                        height: height,
                        maximum: maximumThroughput
                    )
                    let medianX = xPosition(group.p50DurationSeconds, width: width, maximum: maximumDuration)
                    let p90X = xPosition(group.p90DurationSeconds, width: width, maximum: maximumDuration)
                    let color = modelColor(group.model)
                    let diameter = bubbleDiameter(
                        averageDailyCallCount: group.averageDailyCallCount,
                        maximumCalls: maximumCalls
                    )
                    let isHovered = hoveredGroupID == group.id

                    Path { path in
                        path.move(to: CGPoint(x: medianX, y: y))
                        path.addLine(to: CGPoint(x: p90X, y: y))
                        path.move(to: CGPoint(x: p90X, y: y - 4))
                        path.addLine(to: CGPoint(x: p90X, y: y + 4))
                    }
                    .stroke(color.opacity(0.60), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))

                    Circle()
                        .fill(color.opacity(0.82))
                        .overlay(
                            Circle().stroke(
                                Color.white.opacity(isHovered ? 0.95 : 0.72),
                                lineWidth: isHovered ? 2 : 1
                            )
                        )
                        .shadow(color: color.opacity(isHovered ? 0.42 : 0), radius: 5)
                        .frame(
                            width: diameter + (isHovered ? 3 : 0),
                            height: diameter + (isHovered ? 3 : 0)
                        )
                        .position(x: medianX, y: y)
                        .allowsHitTesting(false)

                    pointLabel(
                        group,
                        color: color,
                        p90X: p90X,
                        y: y,
                        plotWidth: width,
                        isHovered: isHovered
                    )
                }

                axisLabels(
                    size: size,
                    width: width,
                    height: height,
                    maximumDuration: maximumDuration,
                    maximumThroughput: maximumThroughput
                )

                if let hoveredGroup = groups.first(where: { $0.id == hoveredGroupID }) {
                    let payload = tooltipPayload(hoveredGroup)
                    ChartTooltipView(payload: payload, prefersOpaqueSurface: true, compact: true)
                        .frame(width: tooltipWidth)
                        .fixedSize(horizontal: false, vertical: true)
                        .position(
                            ChartTooltipLayout.position(
                                anchor: hoverAnchor,
                                containerSize: size,
                                rowCount: payload.rows.count,
                                compact: true
                            )
                        )
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        .zIndex(10)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    updateHover(
                        location: location,
                        width: width,
                        height: height,
                        maximumDuration: maximumDuration,
                        maximumThroughput: maximumThroughput,
                        maximumCalls: maximumCalls
                    )
                case .ended:
                    hoveredGroupID = nil
                }
            }
            .gesture(
                SpatialTapGesture()
                    .onEnded { event in
                        updateHover(
                            location: event.location,
                            width: width,
                            height: height,
                            maximumDuration: maximumDuration,
                            maximumThroughput: maximumThroughput,
                            maximumCalls: maximumCalls
                        )
                    }
            )
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: hoveredGroupID)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(chartAccessibilityLabel)
    }

    private func chartGrid(size: CGSize, width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0...axisDivisionCount, id: \.self) { index in
                let fraction = CGFloat(index) / CGFloat(axisDivisionCount)
                Path { path in
                    let x = plotLeft + width * fraction
                    path.move(to: CGPoint(x: x, y: plotTop))
                    path.addLine(to: CGPoint(x: x, y: plotTop + height))
                }
                .stroke(
                    FixedVisualPalette.cardStroke(
                        colorScheme,
                        elevated: true,
                        increasedContrast: true
                    ),
                    style: StrokeStyle(lineWidth: 0.9, dash: [3, 3])
                )
            }

            ForEach(0...axisDivisionCount, id: \.self) { index in
                let fraction = CGFloat(index) / CGFloat(axisDivisionCount)
                Path { path in
                    let y = plotTop + height * fraction
                    path.move(to: CGPoint(x: plotLeft, y: y))
                    path.addLine(to: CGPoint(x: plotLeft + width, y: y))
                }
                .stroke(
                    FixedVisualPalette.cardStroke(
                        colorScheme,
                        elevated: true,
                        increasedContrast: true
                    ),
                    style: StrokeStyle(lineWidth: 0.9, dash: [3, 3])
                )
            }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }

    private func pointLabel(
        _ group: ModelInferencePerformanceGroup,
        color: Color,
        p90X: CGFloat,
        y: CGFloat,
        plotWidth: CGFloat,
        isHovered: Bool
    ) -> some View {
        let plotRight = plotLeft + plotWidth
        let labelLeadingX = min(max(p90X + 6, plotLeft), plotRight)
        let availableWidth = max(plotRight - labelLeadingX, 1)
        let labelFrameHeight: CGFloat = 18
        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            labelText(group)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(isHovered ? color.opacity(0.18) : FixedVisualPalette.surfaceTrack.opacity(0.58))
        )
        .fixedSize()
        .frame(width: availableWidth, height: labelFrameHeight, alignment: .leading)
        .offset(x: labelLeadingX, y: y - labelFrameHeight / 2)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pointAccessibilityLabel(group))
    }

    private func labelText(_ group: ModelInferencePerformanceGroup) -> some View {
        Text("\(shortModelName(group.model)) · \(displayEffort(group.effort))")
            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private func axisLabels(
        size: CGSize,
        width: CGFloat,
        height: CGFloat,
        maximumDuration: Double,
        maximumThroughput: Double
    ) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0...axisDivisionCount, id: \.self) { index in
                let fraction = CGFloat(index) / CGFloat(axisDivisionCount)
                let value = maximumThroughput * (1 - Double(fraction))
                Text(formatAxisValue(value))
                    .position(x: plotLeft - 16, y: plotTop + height * fraction)
            }

            ForEach(0...axisDivisionCount, id: \.self) { index in
                let fraction = CGFloat(index) / CGFloat(axisDivisionCount)
                let value = maximumDuration * Double(fraction)
                Text(index == 0 ? "0" : "\(formatAxisValue(value))s")
                    .position(x: plotLeft + width * fraction, y: plotTop + height + 12)
            }

            Text("tok/s")
                .position(x: plotLeft + 18, y: plotTop + 4)
            Text(language.text("P50 完整调用耗时", "P50 full-call duration"))
                .position(x: plotLeft + width - 60, y: plotTop + height + 12)
        }
        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }

    private func xPosition(_ value: Double, width: CGFloat, maximum: Double) -> CGFloat {
        plotLeft + width * CGFloat(min(max(value / maximum, 0), 1))
    }

    private func yPosition(_ value: Double, height: CGFloat, maximum: Double) -> CGFloat {
        plotTop + height * CGFloat(1 - min(max(value / maximum, 0), 1))
    }

    private func bubbleDiameter(averageDailyCallCount: Double, maximumCalls: Double) -> CGFloat {
        let normalized = sqrt(max(averageDailyCallCount, 0) / max(maximumCalls, 1))
        return 7 + CGFloat(normalized) * 9
    }

    private func updateHover(
        location: CGPoint,
        width: CGFloat,
        height: CGFloat,
        maximumDuration: Double,
        maximumThroughput: Double,
        maximumCalls: Double
    ) {
        var nearest: (group: ModelInferencePerformanceGroup, point: CGPoint, distance: CGFloat)?

        for group in groups {
            let point = CGPoint(
                x: xPosition(group.p50DurationSeconds, width: width, maximum: maximumDuration),
                y: yPosition(group.effectiveOutputTokensPerSecond, height: height, maximum: maximumThroughput)
            )
            let distance = hypot(location.x - point.x, location.y - point.y)
            let diameter = bubbleDiameter(
                averageDailyCallCount: group.averageDailyCallCount,
                maximumCalls: maximumCalls
            )
            let hitRadius = max(18, diameter / 2 + 8)
            guard distance <= hitRadius else { continue }
            if nearest == nil || distance < (nearest?.distance ?? .greatestFiniteMagnitude) {
                nearest = (group, point, distance)
            }
        }

        hoveredGroupID = nearest?.group.id
        if let point = nearest?.point {
            hoverAnchor = point
        }
    }

    private func modelColor(_ model: String) -> Color {
        let colors = visualTokens.data.modelSeries ?? visualTokens.data.series
        guard !colors.isEmpty else { return visualTokens.accent.primary.color }
        return colors[stableColorSlot(model, count: colors.count)].color
    }

    private func stableColorSlot(_ value: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(count))
    }

    private func shortModelName(_ model: String) -> String {
        model.replacingOccurrences(of: "gpt-", with: "")
    }

    private func displayEffort(_ effort: String) -> String {
        effort.prefix(1).uppercased() + effort.dropFirst()
    }

    private func tooltipPayload(_ group: ModelInferencePerformanceGroup) -> ChartTooltipPayload {
        var rows = [
            ChartTooltipRow(
                id: "model-calls",
                label: language.text("模型调用", "Model calls"),
                value: language.text("\(group.callCount) 次 · 跨 Session", "\(group.callCount) · across sessions")
            )
        ]
        if performance.period != .today {
            rows.append(
                ChartTooltipRow(
                    id: "daily-average-calls",
                    label: language.text("日均调用", "Daily avg calls"),
                    value: language.text(
                        "\(formatCallAverage(group.averageDailyCallCount)) 次 · \(performance.coverageDayCount) 日记录",
                        "\(formatCallAverage(group.averageDailyCallCount)) · \(performance.coverageDayCount)d recorded"
                    )
                )
            )
        }
        rows.append(contentsOf: [
            ChartTooltipRow(
                id: "average",
                label: language.text("平均耗时", "Average"),
                value: formatDuration(group.averageDurationSeconds)
            ),
            ChartTooltipRow(id: "p50", label: "P50", value: formatDuration(group.p50DurationSeconds)),
            ChartTooltipRow(id: "p90", label: "P90", value: formatDuration(group.p90DurationSeconds)),
            ChartTooltipRow(
                id: "throughput",
                label: language.text("有效吞吐", "Throughput"),
                value: "\(formatThroughput(group.effectiveOutputTokensPerSecond)) tok/s"
            ),
            ChartTooltipRow(
                id: "throughput-basis",
                label: language.text("吞吐口径", "Throughput basis"),
                value: language.text("全部输出 ÷ 完整耗时", "All output ÷ full duration")
            ),
            ChartTooltipRow(
                id: "reasoning-share",
                label: "Reasoning tokens",
                value: reasoningTokenDisclosure(group)
            )
        ])
        return ChartTooltipPayload(
            title: "\(group.model) · \(displayEffort(group.effort))",
            rows: rows
        )
    }

    private func pointAccessibilityLabel(_ group: ModelInferencePerformanceGroup) -> String {
        let callSummary: String
        if performance.period == .today {
            callSummary = language.text(
                "跨 Session 汇总 \(group.callCount) 次模型调用",
                "\(group.callCount) model calls aggregated across sessions"
            )
        } else {
            callSummary = language.text(
                "跨 Session 汇总 \(group.callCount) 次模型调用，记录覆盖期日均 \(formatCallAverage(group.averageDailyCallCount)) 次",
                "\(group.callCount) model calls aggregated across sessions, \(formatCallAverage(group.averageDailyCallCount)) daily average over recorded coverage"
            )
        }
        return language.text(
            "\(group.model)，推理强度 \(displayEffort(group.effort))，\(callSummary)，平均耗时 \(formatDuration(group.averageDurationSeconds))，P50 \(formatDuration(group.p50DurationSeconds))，P90 \(formatDuration(group.p90DurationSeconds))，有效吞吐 \(formatThroughput(group.effectiveOutputTokensPerSecond)) tokens 每秒，口径为全部输出 tokens 除以完整耗时，Reasoning tokens 占 \(formatPercentage(reasoningTokenShare(group)))",
            "\(group.model), reasoning effort \(displayEffort(group.effort)), \(callSummary), average \(formatDuration(group.averageDurationSeconds)), P50 \(formatDuration(group.p50DurationSeconds)), P90 \(formatDuration(group.p90DurationSeconds)), effective throughput \(formatThroughput(group.effectiveOutputTokensPerSecond)) tokens per second using all output tokens divided by full duration, reasoning tokens are \(formatPercentage(reasoningTokenShare(group)))"
        )
    }

    private func reasoningTokenDisclosure(_ group: ModelInferencePerformanceGroup) -> String {
        "\(TokenFormatter.format(group.reasoningOutputTokens)) / \(TokenFormatter.format(group.outputTokens)) · \(formatPercentage(reasoningTokenShare(group)))"
    }

    private func reasoningTokenShare(_ group: ModelInferencePerformanceGroup) -> Double {
        guard group.outputTokens > 0 else { return 0 }
        return Double(group.reasoningOutputTokens) / Double(group.outputTokens)
    }

    private func formatPercentage(_ ratio: Double) -> String {
        "\(Int((min(max(ratio, 0), 1) * 100).rounded()))%"
    }

    private func formatDuration(_ seconds: Double) -> String {
        seconds < 10 ? String(format: "%.1fs", seconds) : String(format: "%.0fs", seconds)
    }

    private func formatThroughput(_ value: Double) -> String {
        value < 10 ? String(format: "%.1f", value) : String(format: "%.0f", value)
    }

    private func formatCallAverage(_ value: Double) -> String {
        value < 10 ? String(format: "%.1f", value) : String(format: "%.0f", value)
    }

    private var chartAccessibilityLabel: String {
        switch performance.period {
        case .today:
            language.text("今日模型推理表现散点图", "Today's model inference scatter plot")
        case .sevenDays:
            language.text("最近 7 日平均模型推理表现散点图", "7-day average model inference scatter plot")
        case .twentyEightDays:
            language.text("最近 28 日平均模型推理表现散点图", "28-day average model inference scatter plot")
        }
    }

    private func formatAxisValue(_ value: Double) -> String {
        value < 10 ? String(format: "%.1f", value) : String(format: "%.0f", value)
    }
}
