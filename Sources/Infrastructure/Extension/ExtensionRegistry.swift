import Foundation
import Domain

/// Discovers extensions from disk, creates ExtensionProviders, and registers them with QuotaMonitor.
public final class ExtensionRegistry: Sendable {
    private let extensionsDirectory: URL
    private let scanner: ExtensionDirectoryScanner
    private let settingsRepository: ProviderSettingsRepository
    private let cliExecutor: CLIExecutor?

    /// Default extensions directory: ~/.claudebar/extensions/
    public static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".claudebar")
            .appending(path: "extensions")
    }

    public init(
        extensionsDirectory: URL? = nil,
        scanner: ExtensionDirectoryScanner = ExtensionDirectoryScanner(),
        settingsRepository: ProviderSettingsRepository,
        cliExecutor: CLIExecutor? = nil
    ) {
        self.extensionsDirectory = extensionsDirectory ?? Self.defaultDirectory
        self.scanner = scanner
        self.settingsRepository = settingsRepository
        self.cliExecutor = cliExecutor
    }

    /// Scans for extensions and registers them with the monitor.
    /// Returns the list of registered extension providers.
    @discardableResult
    public func loadExtensions(into monitor: QuotaMonitor) -> [ExtensionProvider] {
        ensureDirectoryExists()

        let scanResults = scanner.scan(directory: extensionsDirectory)
        var providers: [ExtensionProvider] = []

        for result in scanResults {
            let probes = createProbes(for: result)
            let provider = ExtensionProvider(
                manifest: result.manifest,
                probes: probes,
                settingsRepository: settingsRepository
            )
            monitor.addProvider(provider)
            providers.append(provider)
        }

        return providers
    }

    // MARK: - Private

    private func ensureDirectoryExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: extensionsDirectory.path()) {
            try? fm.createDirectory(at: extensionsDirectory, withIntermediateDirectories: true)
        }
    }

    private func createProbes(for result: ExtensionScanResult) -> [String: any UsageProbe] {
        var probes: [String: any UsageProbe] = [:]

        for section in result.manifest.sections {
            let probe = ScriptProbe(
                scriptPath: section.probeCommand,
                extensionDir: result.directory,
                providerId: "ext-\(result.manifest.id)",
                sectionType: section.type,
                timeout: section.timeout,
                cliExecutor: cliExecutor
            )
            probes[section.id] = probe
        }

        return probes
    }
}
