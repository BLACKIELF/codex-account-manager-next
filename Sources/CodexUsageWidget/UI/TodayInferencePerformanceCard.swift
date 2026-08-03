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
                    systemName: "gauge.with.dots.needle.50percent"
                ) {
                    HStack(spacing: 6) {
                        Text(language.text("本机实测", "On-device"))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                        InfoChip(
                            title: language.text("调用", "Calls"),
                            value: "\(performance?.totalCallCount ?? 0)"
                        )
                    }
                }

                if groups.isEmpty {
                    compactEmptyState
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left.and.line.vertical.and.arrow.right")
                            .font(.system(size: 8, weight: .semibold))
                        Text(language.text("越左响应越快 · 越上吞吐越高", "Left is faster · higher is more throughput"))
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)

                    InferencePerformanceScatterPlot(groups: groups, language: language)
                }
            }
        }
        .help(language.text(
            "按模型与推理强度汇总今天本机记录。横轴为完整模型调用耗时 P50，竖轴为输出 tokens ÷ 完整调用耗时；横线延伸至 P90，气泡大小代表调用数。不是 TTFT，也不是可见文本解码 TPS。",
            "Grouped by model and reasoning effort from today's on-device records. X is P50 full-call duration; Y is output tokens divided by full-call duration. Whiskers extend to P90 and bubble area reflects call count. This is not TTFT or visible decode TPS."
        ))
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

    private let plotLeft: CGFloat = 34
    private let plotRight: CGFloat = 12
    private let plotTop: CGFloat = 8
    private let plotBottom: CGFloat = 20

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

                    Path { path in
                        path.move(to: CGPoint(x: medianX, y: y))
                        path.addLine(to: CGPoint(x: p90X, y: y))
                        path.move(to: CGPoint(x: p90X, y: y - 4))
                        path.addLine(to: CGPoint(x: p90X, y: y + 4))
                    }
                    .stroke(color.opacity(0.60), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))

                    Circle()
                        .fill(color.opacity(0.82))
                        .overlay(Circle().stroke(Color.white.opacity(0.72), lineWidth: 1))
                        .frame(width: diameter, height: diameter)
                        .position(x: medianX, y: y)

                    pointLabel(group, color: color, medianX: medianX, y: y, plotWidth: width)
                }

                axisLabels(
                    size: size,
                    width: width,
                    height: height,
                    maximumDuration: maximumDuration,
                    maximumThroughput: maximumThroughput
                )
            }
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
        plotWidth: CGFloat
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
                .fill(FixedVisualPalette.surfaceTrack.opacity(0.58))
        )
        .fixedSize()
        .position(
            x: medianX + (placeBefore ? -54 : 54),
            y: y
        )
        .help(pointHelp(group))
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

    private func pointHelp(_ group: ModelInferencePerformanceGroup) -> String {
        language.text(
            "\(group.model) · \(displayEffort(group.effort))\n调用 \(group.callCount) 次\n平均 \(formatDuration(group.averageDurationSeconds)) · P50 \(formatDuration(group.p50DurationSeconds)) · P90 \(formatDuration(group.p90DurationSeconds))\n有效吞吐 \(formatThroughput(group.effectiveOutputTokensPerSecond)) tok/s\n本机完整调用口径，不等同 TTFT 或可见文本解码 TPS。",
            "\(group.model) · \(displayEffort(group.effort))\n\(group.callCount) calls\nAverage \(formatDuration(group.averageDurationSeconds)) · P50 \(formatDuration(group.p50DurationSeconds)) · P90 \(formatDuration(group.p90DurationSeconds))\nEffective throughput \(formatThroughput(group.effectiveOutputTokensPerSecond)) tok/s\nOn-device full-call metric; not TTFT or visible decode TPS."
        )
    }

    private func pointAccessibilityLabel(_ group: ModelInferencePerformanceGroup) -> String {
        language.text(
            "\(group.model)，推理强度 \(displayEffort(group.effort))，\(group.callCount) 次调用，P50 \(formatDuration(group.p50DurationSeconds))，P90 \(formatDuration(group.p90DurationSeconds))，有效吞吐 \(formatThroughput(group.effectiveOutputTokensPerSecond)) tokens 每秒",
            "\(group.model), reasoning effort \(displayEffort(group.effort)), \(group.callCount) calls, P50 \(formatDuration(group.p50DurationSeconds)), P90 \(formatDuration(group.p90DurationSeconds)), effective throughput \(formatThroughput(group.effectiveOutputTokensPerSecond)) tokens per second"
        )
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
