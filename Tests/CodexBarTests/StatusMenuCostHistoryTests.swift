import AppKit
import CodexBarCore
import Testing
@testable import CodexBar

@MainActor
@Suite(.serialized)
struct StatusMenuCostHistoryTests {
    @Test
    func `shows claude cost history submenu when daily cost exists`() {
        self.expectCostHistorySubmenu(for: .claude)
    }

    @Test
    func `shows bedrock cost history submenu when daily cost exists`() {
        self.expectCostHistorySubmenu(for: .bedrock)
    }

    private func expectCostHistorySubmenu(for provider: UsageProvider) {
        let previousRendering = StatusItemController.menuCardRenderingEnabled
        let previousRefresh = StatusItemController.menuRefreshEnabled
        StatusItemController.menuCardRenderingEnabled = false
        StatusItemController.setMenuRefreshEnabledForTesting(false)
        defer {
            StatusItemController.menuCardRenderingEnabled = previousRendering
            StatusItemController.setMenuRefreshEnabledForTesting(previousRefresh)
        }

        let settings = self.makeSettings()
        settings.statusChecksEnabled = false
        settings.refreshFrequency = .manual
        settings.mergeIcons = false
        settings.costUsageEnabled = true

        let registry = ProviderRegistry.shared
        for candidate in UsageProvider.allCases {
            guard let metadata = registry.metadata[candidate] else { continue }
            settings.setProviderEnabled(provider: candidate, metadata: metadata, enabled: candidate == provider)
        }

        let fetcher = UsageFetcher()
        let store = UsageStore(fetcher: fetcher, browserDetection: BrowserDetection(cacheTTL: 0), settings: settings)
        store._setTokenSnapshotForTesting(self.costSnapshot(), provider: provider)

        let controller = StatusItemController(
            store: store,
            settings: settings,
            account: fetcher.loadAccountInfo(),
            updater: DisabledUpdaterController(),
            preferencesSelection: PreferencesSelection(),
            statusBar: .system)
        defer { controller.releaseStatusItemsForTesting() }

        let menu = controller.makeMenu()
        controller.menuWillOpen(menu)
        let costItem = menu.items.first { $0.representedObject as? String == "menuCardCost" }
        #expect(costItem?.submenu?.items.first?.representedObject as? String == StatusItemController.costHistoryChartID)
        #expect(costItem?.submenu?.items.first?.toolTip == provider.rawValue)
    }

    private func makeSettings() -> SettingsStore {
        let suite = "StatusMenuCostHistoryTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return SettingsStore(
            userDefaults: defaults,
            configStore: testConfigStore(suiteName: suite),
            zaiTokenStore: NoopZaiTokenStore(),
            syntheticTokenStore: NoopSyntheticTokenStore())
    }

    private func costSnapshot() -> CostUsageTokenSnapshot {
        CostUsageTokenSnapshot(
            sessionTokens: nil,
            sessionCostUSD: 0.42,
            last30DaysTokens: nil,
            last30DaysCostUSD: 4.20,
            daily: [
                CostUsageDailyReport.Entry(
                    date: "2025-12-23",
                    inputTokens: nil,
                    outputTokens: nil,
                    totalTokens: nil,
                    costUSD: 0.42,
                    modelsUsed: nil,
                    modelBreakdowns: nil),
            ],
            updatedAt: Date())
    }
}
