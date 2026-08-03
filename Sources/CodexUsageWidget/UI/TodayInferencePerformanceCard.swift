import SwiftUI

struct TodayInferencePerformanceCard: View {
    let performance: ModelInferencePerformance?
    let language: WidgetLanguage

    private var groups: [ModelInferencePerformanceGroup] {
        performance?.displayGroups(limit: 6) ?? []
    }

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 6) {
                DashboardCardHeader(
                    title: language.text("今日实测推理表现", "Today's observed inference"),
                    systemName: "gauge.with.dots.needle.50percent",
                    helpText: chartAlgorithmHelp
                ) {
                    EmptyView()
                }

                if groups.isEmpty {
                    compactEmptyState
                } else {
                    InferencePerformanceScatterPlot(groups: groups, language: language)
                }
            }
        }
    }

    private var chartAlgorithmHelp: String {
        language.text(
            "数据：按模型 × 推理强度汇总今天本机完成的模型调用。\n横轴：完整调用耗时 P50；横线延伸至 P90。\n纵轴：全部输出 tokens（含 Reasoning）÷ 完整调用耗时。\n气泡：面积代表跨 Session 汇总的模型调用数；不是 Session、线程或工具调用数。\n说明：Reasoning 占比是 token 占比，不是耗时占比；指标不是 TTFT 或可见文本解码 TPS。",
            "Data: today's completed on-device model calls grouped by model × reasoning effort.\nX: P50 full-call duration; whiskers extend to P90.\nY: all output tokens, including reasoning, divided by full-call duration.\nBubble: area represents model calls aggregated across sessions—not session, thread, or tool-call counts.\nNote: reasoning share is a token share, not a duration share; this is not TTFT or visible-text decode TPS."
        )
    }

    private var compactEmptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.dots.scatter")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.tertiary)
            VStack(alignment: .leading, spacing: 3) {
                Text(language.text("今天还没有足够记录", "Not enough records today"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(language.text(
                    "完成一次带推理强度的 Codex 调用后显示",
                    "Shown after a Codex call with reasoning effort completes"
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
}

private struct InferencePerformanceScatterPlot: View {
    let groups: [ModelInferencePerformanceGroup]
    let language: WidgetLanguage

    @Environment(\.visualTokens) private var visualTokens
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredGroupID: String?
    @State private var hoverAnchor: CGPoint = .zero

    private let plotLeft: CGFloat = 34
    private let plotRight: CGFloat = 12
    private let plotTop: CGFloat = 8
    private let plotBottom: CGFloat = 20
    private let tooltipWidth: CGFloat = 188

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let width = max(size.width - plotLeft - plotRight, 1)
            let height = max(size.height - plotTop - plotBottom, 1)
            let maximumDuration = max((groups.map(\.p90DurationSeconds).max() ?? 1) * 1.08, 1)
            let maximumThroughput = max((groups.map(\.effectiveOutputTokensPerSecond).max() ?? 1) * 1.16, 1)
            let maximumCalls = max(groups.map(\.callCount).max() ?? 1, 1)

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
                    let diameter = bubbleDiameter(callCount: group.callCount, maximumCalls: maximumCalls)
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
                        medianX: medianX,
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
        .accessibilityLabel(language.text("今日模型推理表现散点图", "Today's model inference scatter plot"))
    }

    private func chartGrid(size: CGSize, width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0...2, id: \.self) { index in
                let fraction = CGFloat(index) / 2
                Path { path in
                    let x = plotLeft + width * fraction
                    path.move(to: CGPoint(x: x, y: plotTop))
                    path.addLine(to: CGPoint(x: x, y: plotTop + height))
                }
                .stroke(FixedVisualPalette.surfaceTrack.opacity(0.70), style: StrokeStyle(lineWidth: 0.8, dash: [2, 3]))
            }

            ForEach(0...2, id: \.self) { index in
                let fraction = CGFloat(index) / 2
                Path { path in
                    let y = plotTop + height * fraction
                    path.move(to: CGPoint(x: plotLeft, y: y))
                    path.addLine(to: CGPoint(x: plotLeft + width, y: y))
                }
                .stroke(FixedVisualPalette.surfaceTrack.opacity(0.70), style: StrokeStyle(lineWidth: 0.8, dash: [2, 3]))
            }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }

    private func pointLabel(
        _ group: ModelInferencePerformanceGroup,
        color: Color,
        medianX: CGFloat,
        y: CGFloat,
        plotWidth: CGFloat,
        isHovered: Bool
    ) -> some View {
        let placeBefore = medianX > plotLeft + plotWidth * 0.72
        return HStack(spacing: 4) {
            if placeBefore {
                labelText(group)
                Circle().fill(color).frame(width: 5, height: 5)
            } else {
                Circle().fill(color).frame(width: 5, height: 5)
                labelText(group)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(isHovered ? color.opacity(0.18) : FixedVisualPalette.surfaceTrack.opacity(0.58))
        )
        .fixedSize()
        .position(
            x: medianX + (placeBefore ? -54 : 54),
            y: y
        )
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
            Text(formatAxisValue(maximumThroughput))
                .position(x: plotLeft - 16, y: plotTop + 4)
            Text(formatAxisValue(maximumThroughput / 2))
                .position(x: plotLeft - 16, y: plotTop + height / 2)
            Text("0")
                .position(x: plotLeft - 16, y: plotTop + height)

            Text("0")
                .position(x: plotLeft, y: plotTop + height + 12)
            Text("\(formatAxisValue(maximumDuration / 2))s")
                .position(x: plotLeft + width / 2, y: plotTop + height + 12)
            Text("\(formatAxisValue(maximumDuration))s")
                .position(x: plotLeft + width, y: plotTop + height + 12)

            Text("tok/s")
                .position(x: plotLeft + 18, y: plotTop + 4)
            Text(language.text("P50 完整调用耗时", "P50 full-call duration"))
                .position(x: plotLeft + width - 60, y: plotTop + height + 12)
        }
        .font(.system(size: 8, weight: .medium, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.tertiary)
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }

    private func xPosition(_ value: Double, width: CGFloat, maximum: Double) -> CGFloat {
        plotLeft + width * CGFloat(min(max(value / maximum, 0), 1))
    }

    private func yPosition(_ value: Double, height: CGFloat, maximum: Double) -> CGFloat {
        plotTop + height * CGFloat(1 - min(max(value / maximum, 0), 1))
    }

    private func bubbleDiameter(callCount: Int, maximumCalls: Int) -> CGFloat {
        let normalized = sqrt(Double(callCount) / Double(maximumCalls))
        return 9 + CGFloat(normalized) * 11
    }

    private func updateHover(
        location: CGPoint,
        width: CGFloat,
        height: CGFloat,
        maximumDuration: Double,
        maximumThroughput: Double,
        maximumCalls: Int
    ) {
        var nearest: (group: ModelInferencePerformanceGroup, point: CGPoint, distance: CGFloat)?

        for group in groups {
            let point = CGPoint(
                x: xPosition(group.p50DurationSeconds, width: width, maximum: maximumDuration),
                y: yPosition(group.effectiveOutputTokensPerSecond, height: height, maximum: maximumThroughput)
            )
            let distance = hypot(location.x - point.x, location.y - point.y)
            let diameter = bubbleDiameter(callCount: group.callCount, maximumCalls: maximumCalls)
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
        ChartTooltipPayload(
            title: "\(group.model) · \(displayEffort(group.effort))",
            rows: [
                ChartTooltipRow(
                    id: "model-calls",
                    label: language.text("模型调用", "Model calls"),
                    value: language.text("\(group.callCount) 次 · 跨 Session", "\(group.callCount) · across sessions")
                ),
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
            ]
        )
    }

    private func pointAccessibilityLabel(_ group: ModelInferencePerformanceGroup) -> String {
        language.text(
            "\(group.model)，推理强度 \(displayEffort(group.effort))，跨 Session 汇总 \(group.callCount) 次模型调用，平均耗时 \(formatDuration(group.averageDurationSeconds))，P50 \(formatDuration(group.p50DurationSeconds))，P90 \(formatDuration(group.p90DurationSeconds))，有效吞吐 \(formatThroughput(group.effectiveOutputTokensPerSecond)) tokens 每秒，口径为全部输出 tokens 除以完整耗时，Reasoning tokens 占 \(formatPercentage(reasoningTokenShare(group)))",
            "\(group.model), reasoning effort \(displayEffort(group.effort)), \(group.callCount) model calls aggregated across sessions, average \(formatDuration(group.averageDurationSeconds)), P50 \(formatDuration(group.p50DurationSeconds)), P90 \(formatDuration(group.p90DurationSeconds)), effective throughput \(formatThroughput(group.effectiveOutputTokensPerSecond)) tokens per second using all output tokens divided by full duration, reasoning tokens are \(formatPercentage(reasoningTokenShare(group)))"
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

    private func formatAxisValue(_ value: Double) -> String {
        value < 10 ? String(format: "%.1f", value) : String(format: "%.0f", value)
    }
}
