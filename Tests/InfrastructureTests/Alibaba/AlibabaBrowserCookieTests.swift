import Testing
import Foundation
import Mockable
@testable import Infrastructure
@testable import Domain

@Suite
struct AlibabaBrowserCookieTests {

    private func makeSettingsRepository() -> UserDefaultsProviderSettingsRepository {
        let suiteName = "com.claudebar.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let repo = UserDefaultsProviderSettingsRepository(userDefaults: defaults)
        repo.setEnabled(true, forProvider: "alibaba")
        return repo
    }

    private func mockSuccessResponse() -> (Data, URLResponse) {
        let json = """
        {
          "code": "200",
          "data": {
            "codingPlanInstanceInfos": [
              {
                "planName": "Test Plan",
                "status": "VALID",
                "codingPlanQuotaInfo": {
                  "per5HourUsedQuota": 10,
                  "per5HourTotalQuota": 100,
                  "perWeekUsedQuota": 50,
                  "perWeekTotalQuota": 500,
                  "perBillMonthUsedQuota": 100,
                  "perBillMonthTotalQuota": 2000
                }
              }
            ]
          },
          "success": true
        }
        """
        let data = Data(json.utf8)
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }

    // MARK: - isAvailable with auto cookie source

    @Test
    func `isAvailable returns true when auto cookie source and browser has cookies`() async {
        let repo = makeSettingsRepository()
        repo.setAlibabaCookieSource(.auto)

        let mockCookieProvider = MockAlibabaCookieProviding()
        given(mockCookieProvider).extractBrowserCookies().willReturn("login_aliyunid_ticket=browser_cookie")

        let probe = AlibabaUsageProbe(settingsRepository: repo, cookieProvider: mockCookieProvider)

        let available = await probe.isAvailable()
        #expect(available == true)
    }

    @Test
    func `isAvailable returns false when auto cookie source and browser has no cookies`() async {
        let repo = makeSettingsRepository()
        repo.setAlibabaCookieSource(.auto)

        let mockCookieProvider = MockAlibabaCookieProviding()
        given(mockCookieProvider).extractBrowserCookies().willReturn(nil)

        let probe = AlibabaUsageProbe(settingsRepository: repo, cookieProvider: mockCookieProvider)

        let available = await probe.isAvailable()
        #expect(available == false)
    }

    // MARK: - probe() with auto cookie source

    @Test
    func `probe with auto cookie uses browser cookie provider`() async throws {
        let repo = makeSettingsRepository()
        repo.setAlibabaCookieSource(.auto)

        let mockCookieProvider = MockAlibabaCookieProviding()
        given(mockCookieProvider).extractBrowserCookies().willReturn("login_aliyunid_ticket=abc; sec_token=browser_sec_token")

        let mockNetwork = MockNetworkClient()
        given(mockNetwork).request(.any).willReturn(mockSuccessResponse())

        let probe = AlibabaUsageProbe(settingsRepository: repo, networkClient: mockNetwork, cookieProvider: mockCookieProvider)

        let snapshot = try await probe.probe()
        #expect(snapshot.providerId == "alibaba")
        #expect(snapshot.quotas.count == 3)
    }

    @Test
    func `probe with auto cookie throws authenticationRequired when no browser cookie`() async throws {
        let repo = makeSettingsRepository()
        repo.setAlibabaCookieSource(.auto)

        let mockCookieProvider = MockAlibabaCookieProviding()
        given(mockCookieProvider).extractBrowserCookies().willReturn(nil)

        let probe = AlibabaUsageProbe(settingsRepository: repo, cookieProvider: mockCookieProvider)

        do {
            _ = try await probe.probe()
            Issue.record("Expected authenticationRequired error")
        } catch {
            #expect(error as? ProbeError == .authenticationRequired)
        }
    }

    @Test
    func `probe prefers API key over auto cookie`() async throws {
        let repo = makeSettingsRepository()
        repo.setAlibabaCookieSource(.auto)
        repo.saveAlibabaApiKey("sk-test-key")

        let mockCookieProvider = MockAlibabaCookieProviding()
        // Cookie provider should not be called when API key is available
        given(mockCookieProvider).extractBrowserCookies().willReturn("some_cookie")

        let mockNetwork = MockNetworkClient()
        given(mockNetwork).request(.any).willReturn(mockSuccessResponse())

        let probe = AlibabaUsageProbe(settingsRepository: repo, networkClient: mockNetwork, cookieProvider: mockCookieProvider)

        let snapshot = try await probe.probe()
        #expect(snapshot.providerId == "alibaba")
    }

    @Test
    func `probe with auto cookie returns empty string throws authenticationRequired`() async throws {
        let repo = makeSettingsRepository()
        repo.setAlibabaCookieSource(.auto)

        let mockCookieProvider = MockAlibabaCookieProviding()
        given(mockCookieProvider).extractBrowserCookies().willReturn("")

        let probe = AlibabaUsageProbe(settingsRepository: repo, cookieProvider: mockCookieProvider)

        do {
            _ = try await probe.probe()
            Issue.record("Expected authenticationRequired error")
        } catch {
            #expect(error as? ProbeError == .authenticationRequired)
        }
    }
}
