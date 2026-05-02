import SwiftUI
import Domain

/// Displays a single daily usage metric (cost, tokens, or working time)
/// matching the existing WrappedStatCard glassmorphism style.
struct DailyUsageCardView: View {
    let metric: DailyUsageMetric
    let report: DailyUsageReport
    let delay: Double

    @Environment(\.appTheme) private var theme
    @State private var isHovering = false
    @State private var animateProgress = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row with icon and label
            HStack(alignment: .top, spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: metric.iconName)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(metric.color)

                    Text(metric.label.uppercased())
                        .font(.system(size: 8, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .tracking(0.3)
                }

                Spacer(minLength: 4)
            }

            // Large value display
            HStack(alignment: .firstTextBaseline) {
                Text(primaryValue)
                    .font(.system(size: 24, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .contentTransition(.numericText())

                Spacer()

                Text(metric.unitLabel)
                    .font(.system(size: 11, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }

            // Optional subtitle (e.g., cache breakdown for tokens card)
            if let subtitle = subtitleText {
                Text(subtitle)
                    .font(.system(size: 9, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.progressTrack)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(
                            colors: [metric.color.opacity(0.8), metric.color],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: animateProgress ? geo.size.width * progress : 0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(delay + 0.2), value: animateProgress)
                }
            }
            .frame(height: 5)

            // Delta comparison line
            if let deltaText = formattedDelta {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 7))

                    Text(deltaText)
                        .font(.system(size: 8, weight: .medium, design: theme.fontDesign))
                }
                .foregroundStyle(deltaColor)
                .lineLimit(1)
            }
        }
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                    .fill(theme.cardGradient)

                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                    .stroke(theme.glassBorder, lineWidth: 1)
            }
        )
        .scaleEffect(isHovering ? 1.015 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
        .onAppear {
            animateProgress = true
        }
    }

    // MARK: - Computed Properties

    private var primaryValue: String {
        switch metric {
        case .cost: return report.today.formattedCost
        case .tokens: return report.today.formattedTotalTokensWithCache
        case .workingTime: return report.today.formattedWorkingTime
        case .cacheHitRate: return report.today.formattedHitRate
        case .cacheSavings: return report.today.formattedSavings
        case .cacheTokens: return report.today.formattedCacheTokens
        }
    }

    private var subtitleText: String? {
        switch metric {
        case .tokens:
            // Show cache breakdown only when cache data exists
            let cacheTotal = report.today.totalCacheTokens
            guard cacheTotal > 0 else { return nil }
            let cachePct = Double(cacheTotal) / Double(max(1, report.today.totalTokensWithCache)) * 100
            return "Cache: \(report.today.formattedCacheTokens) (\(String(format: "%.1f", cachePct))%)"
        case .cacheHitRate:
            // Show absolute counts under hit rate
            let read = report.today.cacheReadTokens
            return "\(formatTokenCompact(read)) read"
        default:
            return nil
        }
    }

    private func formatTokenCompact(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000.0) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000.0) }
        return "\(n)"
    }

    private var progress: Double {
        switch metric {
        case .cost: return min(1, max(0, report.costProgress))
        case .tokens: return min(1, max(0, report.tokenProgress))
        case .workingTime: return min(1, max(0, report.timeProgress))
        case .cacheHitRate: return min(1, max(0, report.today.cacheHitRate))
        case .cacheSavings:
            let total = report.today.cachedSavings + report.previous.cachedSavings
            guard total > 0 else { return 0 }
            return Double(truncating: report.today.cachedSavings as NSDecimalNumber) / Double(truncating: total as NSDecimalNumber)
        case .cacheTokens:
            let total = report.today.totalCacheTokens + report.previous.totalCacheTokens
            guard total > 0 else { return 0 }
            return Double(report.today.totalCacheTokens) / Double(total)
        }
    }

    private var formattedDelta: String? {
        guard !report.previous.isEmpty else { return nil }
        let date = report.previous.formattedDate
        switch metric {
        case .cost:
            let delta = report.formattedCostDelta
            if let pct = report.costChangePercent {
                return "Vs \(date) \(delta) (\(String(format: "%.1f", abs(pct)))%)"
            }
            return "Vs \(date) \(delta)"
        case .tokens:
            let delta = report.formattedTokenDelta
            if let pct = report.tokenChangePercent {
                return "Vs \(date) \(delta) (\(String(format: "%.1f", abs(pct)))%)"
            }
            return "Vs \(date) \(delta)"
        case .workingTime:
            let delta = report.formattedTimeDelta
            if let pct = report.timeChangePercent {
                return "Vs \(date) \(delta) (\(String(format: "%.1f", abs(pct)))%)"
            }
            return "Vs \(date) \(delta)"
        case .cacheHitRate:
            return "Vs \(date) \(report.formattedCacheHitRateDelta)"
        case .cacheSavings:
            return "Vs \(date) \(report.formattedSavingsDelta)"
        case .cacheTokens:
            return "Vs \(date) \(report.formattedCacheTokenDelta)"
        }
    }

    private var deltaColor: Color {
        switch metric {
        case .cost:
            return report.costDelta <= 0 ? .green : .orange
        case .tokens:
            return report.tokenDelta <= 0 ? .green : .orange
        case .workingTime:
            return theme.textTertiary
        case .cacheHitRate:
            // Higher hit rate is better
            return report.cacheHitRateDelta >= 0 ? .green : .orange
        case .cacheSavings:
            // More savings is better
            return report.savingsDelta >= 0 ? .green : .orange
        case .cacheTokens:
            return theme.textTertiary
        }
    }
}

// MARK: - Metric Type

enum DailyUsageMetric {
    case cost
    case tokens
    case workingTime
    case cacheHitRate
    case cacheSavings
    case cacheTokens

    var label: String {
        switch self {
        case .cost: return "Cost Usage"
        case .tokens: return "Token Usage"
        case .workingTime: return "Working Time"
        case .cacheHitRate: return "Cache Hit"
        case .cacheSavings: return "Cache Saved"
        case .cacheTokens: return "Cache Tokens"
        }
    }

    var iconName: String {
        switch self {
        case .cost: return "dollarsign.circle.fill"
        case .tokens: return "number.circle.fill"
        case .workingTime: return "clock.fill"
        case .cacheHitRate: return "bolt.fill"
        case .cacheSavings: return "arrow.down.circle.fill"
        case .cacheTokens: return "tray.full.fill"
        }
    }

    var unitLabel: String {
        switch self {
        case .cost: return "Spent"
        case .tokens: return "Tokens"
        case .workingTime: return "Duration"
        case .cacheHitRate: return "Hit Rate"
        case .cacheSavings: return "Saved"
        case .cacheTokens: return "Cached"
        }
    }

    var color: Color {
        switch self {
        case .cost: return .yellow
        case .tokens: return .green
        case .workingTime: return .purple
        case .cacheHitRate: return .cyan
        case .cacheSavings: return .mint
        case .cacheTokens: return .teal
        }
    }
}
