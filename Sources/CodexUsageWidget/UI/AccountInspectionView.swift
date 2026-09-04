import SwiftUI

struct AccountInspectionView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var taskStatusModel: HubAccountTaskStatusModel
    @StateObject private var model = AccountInspectionModel()
    @State private var didRefreshOnAppear = false

    private let columns = [
        GridItem(.adaptive(minimum: 250, maximum: 360), spacing: 12, alignment: .top)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let configurationError = model.configurationError {
                Label(configurationError, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.orange)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sectionBackground()
            }

            if model.accounts.isEmpty, model.configurationError == nil {
                ProgressView("正在读取账号巡检数据…")
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .sectionBackground()
            } else if !model.accounts.isEmpty {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(model.accounts) { account in
                        AccountInspectionCard(
                            account: account,
                            taskStatus: taskStatusModel.status(forAccountAlias: account.alias)
                        )
                    }
                }
            }

            issueSummary
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            guard !didRefreshOnAppear else { return }
            didRefreshOnAppear = true
            model.refresh(profiles: store.profiles)
        }
        .onChange(of: store.profiles) { profiles in
            model.updateProfiles(profiles)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("多账号巡检")
                    .font(.system(size: 27, weight: .semibold))
                Text("配置、额度与最近派单状态")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            Label(
                "\(AccountInspectionModel.baselineModel) · \(AccountInspectionModel.baselineReasoningEffort)",
                systemImage: "scope"
            )
            .font(.caption.weight(.semibold).monospaced())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(FixedVisualPalette.surfaceTrack))
            .help("模型配置基线")

            hubBadge

            if let refreshedAt = model.refreshedAt {
                Text("更新于 \(refreshedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text("等待首次巡检")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                model.refresh(profiles: store.profiles)
                taskStatusModel.restartPolling()
            } label: {
                Label(taskStatusModel.isRefreshing ? "巡检中…" : "立即刷新", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(taskStatusModel.isRefreshing)
        }
    }

    @ViewBuilder
    private var hubBadge: some View {
        switch taskStatusModel.connectionState {
        case .loading:
            Label("hub 连接中", systemImage: "ellipsis")
                .inspectionBadge(color: .secondary)
        case .online:
            Label("hub 在线", systemImage: "checkmark.circle.fill")
                .inspectionBadge(color: .green)
        case .offline:
            Label("hub 离线", systemImage: "bolt.slash.fill")
                .inspectionBadge(color: .orange)
        }
    }

    private var issueSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("异常清单", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                if !model.issues.isEmpty {
                    Text("\(model.issues.count)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.13)))
                }
                Spacer()
                Text("快照 >30 分钟 · 额度 <20% · 配置偏离 · 派单停用")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if model.issues.isEmpty {
                Label("当前没有命中巡检规则的异常", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 300), spacing: 10)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(model.issues) { issue in
                        HStack(spacing: 8) {
                            Image(systemName: issueIcon(issue.kind))
                                .foregroundStyle(issueColor(issue.kind))
                                .frame(width: 16)
                            Text(issue.accountAlias)
                                .font(.caption.weight(.semibold).monospaced())
                                .lineLimit(1)
                            Text(issue.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .cardBackground(cornerRadius: 9)
                    }
                }
            }
        }
        .padding(16)
        .sectionBackground()
    }

    private func issueIcon(_ kind: AccountInspectionIssue.Kind) -> String {
        switch kind {
        case .staleSnapshot: return "clock.badge.exclamationmark"
        case .lowQuota: return "gauge.with.dots.needle.0percent"
        case .configurationDrift: return "slider.horizontal.3"
        case .dispatchDisabled: return "pause.circle.fill"
        }
    }

    private func issueColor(_ kind: AccountInspectionIssue.Kind) -> Color {
        switch kind {
        case .lowQuota, .configurationDrift: return .red
        case .staleSnapshot, .dispatchDisabled: return .orange
        }
    }
}

private struct AccountInspectionCard: View {
    let account: AccountInspectionAccount
    let taskStatus: HubAccountTaskStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 7) {
                Text(account.alias)
                    .font(.headline.monospaced())
                    .lineLimit(1)
                Spacer(minLength: 4)
                if account.dispatchDisabled {
                    Text("已停用")
                        .inspectionBadge(color: .orange)
                }
                Text(account.planType?.uppercased() ?? "—")
                    .inspectionBadge(color: account.planType?.lowercased() == "pro" ? .accentColor : .secondary)
            }

            Text(account.maskedEmail ?? "—")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .textSelection(.disabled)

            HStack(spacing: 6) {
                Image(systemName: account.configuration.matchesBaseline
                    ? "checkmark.circle.fill"
                    : "exclamationmark.triangle.fill")
                Text(account.configuration.model ?? "—")
                Text("·")
                Text(account.configuration.reasoningEffort ?? "—")
            }
            .font(.caption.weight(.medium).monospaced())
            .foregroundStyle(account.configuration.matchesBaseline ? Color.secondary : Color.red)
            .lineLimit(1)
            .help(account.configuration.matchesBaseline ? "配置符合基线" : "配置偏离巡检基线")

            VStack(spacing: 7) {
                InspectionQuotaRow(title: "5h", remainingPercent: account.fiveHourRemainingPercent)
                InspectionQuotaRow(title: "7d", remainingPercent: account.sevenDayRemainingPercent)
            }

            Divider()

            taskStatusRow
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 183, alignment: .topLeading)
        .cardBackground(cornerRadius: 13, elevated: true)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var taskStatusRow: some View {
        taskRow(
            color: taskColor(taskStatus.phase),
            state: taskStatus.localizedLabel,
            date: taskStatus.updatedAt
        )
    }

    private func taskRow(color: Color, state: String, date: Date?) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(state)
                .font(.caption.weight(.medium))
                .foregroundStyle(state == "未运行" ? Color.secondary : Color.primary)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let date {
                Text(date.formatted(date: .omitted, time: .shortened))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func taskColor(_ phase: HubAccountTaskPhase) -> Color {
        switch phase {
        case .succeeded: return .green
        case .awaitingApproval, .starting, .running: return .accentColor
        case .cancelRequested, .uncertain, .unavailable: return .orange
        case .failed, .cancelled: return .red
        case .idle: return .secondary
        }
    }
}

private struct InspectionQuotaRow: View {
    let title: String
    let remainingPercent: Double?

    private var tint: Color {
        guard let remainingPercent else { return .secondary }
        if remainingPercent < 20 { return .red }
        if remainingPercent < 50 { return .orange }
        return .green
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(FixedVisualPalette.surfaceTrack)
                    if let remainingPercent {
                        Capsule()
                            .fill(tint)
                            .frame(width: proxy.size.width * max(0, min(1, remainingPercent / 100)))
                    }
                }
            }
            .frame(height: 6)

            Text(remainingPercent.map { "\(Int($0.rounded()))%" } ?? "—")
                .font(.caption.monospacedDigit())
                .foregroundStyle(remainingPercent == nil ? Color.secondary : tint)
                .frame(width: 38, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) 剩余额度")
        .accessibilityValue(remainingPercent.map { "\(Int($0.rounded()))%" } ?? "无快照")
    }
}

private extension View {
    func inspectionBadge(color: Color) -> some View {
        self
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.12)))
    }
}
