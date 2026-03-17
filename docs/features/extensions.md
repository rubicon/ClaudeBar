# Extensions Feature

User-built provider extensions for ClaudeBar. Drop a folder with a `manifest.json` and probe scripts into `~/.claudebar/extensions/` to add custom AI provider monitoring with your own data sources and card layouts.

---

## Quick Start

```bash
# Create an extension
mkdir -p ~/.claudebar/extensions/my-provider

# Add manifest.json (defines sections + probe commands)
cat > ~/.claudebar/extensions/my-provider/manifest.json <<'EOF'
{
    "id": "my-provider",
    "name": "My Provider",
    "version": "1.0.0",
    "icon": "cpu.fill",
    "colors": { "primary": "#FF6B35" },
    "sections": [
        {
            "id": "quotas",
            "type": "quotaGrid",
            "probe": { "command": "./probe.sh", "interval": 60 }
        }
    ]
}
EOF

# Add probe script (any language — just output JSON to stdout)
cat > ~/.claudebar/extensions/my-provider/probe.sh <<'PROBE'
#!/bin/sh
echo '{"quotas": [{"type": "weekly", "percentRemaining": 72.0}]}'
PROBE
chmod +x ~/.claudebar/extensions/my-provider/probe.sh

# Restart ClaudeBar — extension appears as a provider
```

---

## Manifest Format (`manifest.json`)

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique identifier (e.g., `"openrouter"`) |
| `name` | Yes | Display name shown in provider pills |
| `version` | Yes | Semver version string |
| `description` | No | Human-readable description |
| `icon` | No | SF Symbol name (e.g., `"cpu.fill"`, `"network"`) |
| `colors.primary` | No | Hex color for accent (e.g., `"#6366F1"`) |
| `colors.gradient` | No | Array of hex colors for gradient |
| `dashboardURL` | No | URL opened when user clicks "Dashboard" |
| `statusPageURL` | No | URL for provider status page |
| `sections` | Yes | Array of section definitions (min 1) |

### Section Definition

Each section has its own probe command and refresh interval for optimal performance:

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique section identifier within the extension |
| `type` | Yes | Section type (see below) |
| `probe.command` | Yes | Script/binary to execute (relative to extension dir) |
| `probe.interval` | No | Refresh interval in seconds (default: `60`) |
| `probe.timeout` | No | Execution timeout in seconds (default: `10`) |

### Section Types

| Type | Renders As | Use Case |
|------|-----------|----------|
| `quotaGrid` | Quota cards with % bars and reset timers | Usage limits (session, weekly, model-specific) |
| `costUsage` | Cost card with budget tracking | Spending / billing data |
| `dailyUsage` | Comparison cards (cost, tokens, working time vs previous) | Daily analytics |
| `metricsRow` | Generic value cards with progress bars and deltas | Custom metrics (API calls, latency, etc.) |
| `statusBanner` | Simple status text with severity level | Connection status, health checks |

---

## Probe Script Output

Probe scripts are executed via `/bin/sh -c <command>` in the extension directory. They must:
1. Exit with code `0` on success (non-zero = error)
2. Print valid JSON to stdout
3. Complete within the configured timeout

Each section type expects a specific JSON key in the output:

### `quotaGrid` Output

```json
{
    "quotas": [
        {
            "type": "session",
            "percentRemaining": 97.0,
            "resetsAt": "2026-03-17T18:00:00Z"
        },
        {
            "type": "weekly",
            "percentRemaining": 69.0
        },
        {
            "type": "model:sonnet",
            "percentRemaining": 99.0,
            "dollarRemaining": 50.00
        }
    ]
}
```

**Quota type values:** `session`, `weekly`, `model:<name>`, or any custom string (rendered as `timeLimit`).

### `metricsRow` Output

```json
{
    "metrics": [
        {
            "label": "API Calls",
            "value": "1,234",
            "unit": "Requests",
            "icon": "arrow.up.arrow.down",
            "color": "#4CAF50",
            "progress": 0.65,
            "delta": {
                "vs": "Yesterday",
                "value": "+200",
                "percent": 19.3
            }
        }
    ]
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `label` | Yes | Card header text |
| `value` | Yes | Primary display value |
| `unit` | Yes | Unit label (e.g., "Requests", "USD", "ms") |
| `icon` | No | SF Symbol name |
| `color` | No | Hex color for accent |
| `progress` | No | Progress bar value (0.0–1.0) |
| `delta.vs` | No | Comparison reference (e.g., "Yesterday") |
| `delta.value` | No | Delta string (e.g., "+200", "-$5.00") |
| `delta.percent` | No | Change percentage |

### `costUsage` Output

```json
{
    "costUsage": {
        "totalCost": 10.26,
        "budget": 100.00,
        "apiDuration": 454.0,
        "wallDuration": 23600.0,
        "linesAdded": 150,
        "linesRemoved": 42
    }
}
```

### `dailyUsage` Output

```json
{
    "dailyUsage": {
        "today": {
            "totalCost": 10.26,
            "totalTokens": 8300000,
            "workingTime": 454.0,
            "date": "2026-03-17"
        },
        "previous": {
            "totalCost": 711.84,
            "totalTokens": 8693000,
            "workingTime": 42514.0,
            "date": "2026-03-16"
        }
    }
}
```

### `statusBanner` Output

```json
{
    "status": {
        "text": "Connected",
        "level": "healthy"
    }
}
```

**Level values:** `healthy`, `warning`, `critical`, `inactive`

---

## Multi-Section Example

An extension with separate probes for fast quota checks and slower daily analytics:

```json
{
    "id": "openrouter",
    "name": "OpenRouter",
    "version": "1.0.0",
    "icon": "network",
    "colors": {
        "primary": "#6366F1",
        "gradient": ["#6366F1", "#8B5CF6"]
    },
    "dashboardURL": "https://openrouter.ai/activity",
    "sections": [
        {
            "id": "status",
            "type": "statusBanner",
            "probe": { "command": "./probe-status.sh", "interval": 30, "timeout": 5 }
        },
        {
            "id": "quotas",
            "type": "quotaGrid",
            "probe": { "command": "./probe-quota.sh", "interval": 60 }
        },
        {
            "id": "daily",
            "type": "metricsRow",
            "probe": { "command": "./probe-metrics.sh", "interval": 300, "timeout": 15 }
        }
    ]
}
```

Each probe runs independently on its own interval, so fast health checks don't wait for heavy analytics.

---

## Architecture

```
ClaudeBarApp.init()
└── ExtensionRegistry.loadExtensions(into: monitor)
    └── ExtensionDirectoryScanner.scan(~/.claudebar/extensions/)
        └── For each valid manifest.json:
            ├── Parse → ExtensionManifest
            ├── Create ScriptProbe per section
            ├── Create ExtensionProvider (implements AIProvider)
            └── QuotaMonitor.addProvider(extensionProvider)
                 ↓
            Provider appears in UI alongside built-in providers
```

```
Sources/
├── Domain/Extension/
│   ├── ExtensionManifest.swift       [manifest.json → typed struct with sections]
│   ├── ExtensionSection.swift        [section type, probe command, interval, timeout]
│   ├── ExtensionMetric.swift         [generic metric + MetricDelta + StatusInfo]
│   ├── ExtensionProvider.swift       [AIProvider — owns N probes, merges snapshots]
│   └── SectionData.swift             [decodes probe JSON → UsageQuota/CostUsage/etc.]
├── Infrastructure/Extension/
│   ├── ScriptProbe.swift             [UsageProbe — executes script, parses JSON stdout]
│   ├── ExtensionDirectoryScanner.swift [scans extensions dir for manifest.json]
│   └── ExtensionRegistry.swift       [wires scanning → provider creation → registration]
└── App/Views/
    └── ExtensionMetricCardView.swift [renders generic metric cards in statsGrid]
```

---

## Domain Models

### `ExtensionManifest`

Parsed from `manifest.json`. Contains extension identity, visual config, and section definitions.

```swift
public struct ExtensionManifest: Sendable, Equatable {
    public let id: String
    public let name: String
    public let version: String
    public let description: String?
    public let icon: String?
    public let colors: ExtensionColors?
    public let dashboardURL: URL?
    public let statusPageURL: URL?
    public let sections: [ExtensionSection]
}
```

### `ExtensionSection`

A single section within an extension, with its own probe and refresh interval.

```swift
public struct ExtensionSection: Sendable, Equatable {
    public let id: String
    public let type: SectionType          // .quotaGrid, .metricsRow, .costUsage, .dailyUsage, .statusBanner
    public let probeCommand: String       // relative to extension dir
    public let refreshInterval: TimeInterval  // default: 60s
    public let timeout: TimeInterval          // default: 10s
}
```

### `ExtensionMetric`

Generic metric value for `metricsRow` sections.

```swift
public struct ExtensionMetric: Sendable, Equatable, Codable {
    public let label: String
    public let value: String
    public let unit: String
    public let icon: String?              // SF Symbol name
    public let color: String?             // hex color
    public let delta: MetricDelta?        // comparison data
    public let progress: Double?          // 0.0–1.0
}
```

### `SectionData`

Enum that decodes probe JSON into the correct domain model based on section type.

```swift
public enum SectionData: Sendable, Equatable {
    case quotas([UsageQuota])        // reuses existing model
    case cost(CostUsage)             // reuses existing model
    case daily(DailyUsageReport)     // reuses existing model
    case metrics([ExtensionMetric])  // new
    case status(StatusInfo)          // new
}
```

---

## File Map

**Sources:**

```
Sources/
├── Domain/Extension/
│   ├── ExtensionManifest.swift
│   ├── ExtensionSection.swift
│   ├── ExtensionMetric.swift
│   ├── ExtensionProvider.swift
│   └── SectionData.swift
├── Infrastructure/Extension/
│   ├── ScriptProbe.swift
│   ├── ExtensionDirectoryScanner.swift
│   └── ExtensionRegistry.swift
└── App/Views/
    └── ExtensionMetricCardView.swift
```

**Tests:**

```
Tests/
├── DomainTests/Extension/
│   ├── ExtensionManifestTests.swift          [8 tests — parsing, defaults, validation]
│   ├── ExtensionMetricTests.swift            [6 tests — model creation, JSON decoding]
│   ├── SectionDataTests.swift                [10 tests — all 5 section types, errors]
│   └── ExtensionProviderTests.swift          [10 tests — identity, refresh, merge, availability]
└── InfrastructureTests/Extension/
    ├── ScriptProbeTests.swift                [7 tests — execution, parsing, errors]
    └── ExtensionDirectoryScannerTests.swift  [5 tests — scanning, validation, missing dirs]
```

---

## Testing

```swift
@Test func `parses manifest with per-section probes`() throws {
    let json = """
    {
        "id": "test", "name": "Test", "version": "1.0.0",
        "sections": [
            { "id": "q", "type": "quotaGrid", "probe": { "command": "./fast.sh", "interval": 30 } },
            { "id": "m", "type": "metricsRow", "probe": { "command": "./slow.sh", "interval": 300 } }
        ]
    }
    """
    let manifest = try ExtensionManifest.parse(from: json.data(using: .utf8)!)
    #expect(manifest.sections[0].refreshInterval == 30)
    #expect(manifest.sections[1].refreshInterval == 300)
}
```

Run extension tests:

```bash
xcodebuild test -scheme ClaudeBar-Workspace -workspace ClaudeBar.xcworkspace \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:DomainTests/ExtensionManifestTests \
  -only-testing:DomainTests/ExtensionMetricTests \
  -only-testing:DomainTests/SectionDataTests \
  -only-testing:DomainTests/ExtensionProviderTests \
  -only-testing:InfrastructureTests/ScriptProbeTests \
  -only-testing:InfrastructureTests/ExtensionDirectoryScannerTests
# Test run with 46 tests in 6 suites passed
```

---

## Security

- Probe scripts run with the user's permissions (not elevated)
- Timeout enforcement prevents hanging scripts (default 10s)
- JSON-only output — no code injection into the app
- Extensions cannot access app internals; they only produce data via stdout
- Extension provider IDs are prefixed with `ext-` to avoid collisions with built-in providers
