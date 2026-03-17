import Foundation

/// Defines a single section within an extension, with its own probe command and refresh interval.
public struct ExtensionSection: Sendable, Equatable {
    public let id: String
    public let type: SectionType
    public let probeCommand: String
    public let refreshInterval: TimeInterval
    public let timeout: TimeInterval

    public init(
        id: String,
        type: SectionType,
        probeCommand: String,
        refreshInterval: TimeInterval = 60,
        timeout: TimeInterval = 10
    ) {
        self.id = id
        self.type = type
        self.probeCommand = probeCommand
        self.refreshInterval = refreshInterval
        self.timeout = timeout
    }
}

/// The type of UI section an extension section renders as.
public enum SectionType: String, Sendable, Equatable {
    /// Quota cards with percentage bars (SESSION, WEEKLY, etc.)
    case quotaGrid
    /// Cost-based usage card
    case costUsage
    /// Daily usage comparison cards (cost, tokens, working time)
    case dailyUsage
    /// Generic metric cards with values, units, and deltas
    case metricsRow
    /// Simple status banner (e.g., "Active", "Connected")
    case statusBanner
}
