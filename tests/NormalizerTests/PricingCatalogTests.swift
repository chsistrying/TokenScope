import XCTest
@testable import TokenScope

final class PricingCatalogTests: XCTestCase {
    func testSourceVersionUsesReviewDateFormat() {
        XCTAssertNotNil(Self.catalogVersionDateFormatter.date(from: PricingCatalog.sourceVersion))
    }

    func testEstimatesClaudeSonnet5WithCacheTokens() {
        let catalog = PricingCatalog()

        let cost = catalog.estimatedCost(
            provider: .claude,
            model: "claude-sonnet-5",
            inputTokens: 2,
            cacheCreationInputTokens: 100,
            cacheReadInputTokens: 200,
            outputTokens: 50
        )

        XCTAssertEqual(cost, Decimal(string: "0.000944"))
    }

    func testEstimatesClaudeOpus48() {
        let catalog = PricingCatalog()

        let cost = catalog.estimatedCost(
            provider: .claude,
            model: "claude-opus-4-8",
            inputTokens: 1_000_000,
            cacheCreationInputTokens: 1_000_000,
            cacheReadInputTokens: 1_000_000,
            outputTokens: 1_000_000
        )

        XCTAssertEqual(cost, Decimal(string: "40.5"))
    }

    func testEstimatesCodexGpt55WithCachedInputSubset() {
        let catalog = PricingCatalog()

        let cost = catalog.estimatedCost(
            provider: .codex,
            model: "gpt-5.5",
            inputTokens: 200,
            cacheReadInputTokens: 40,
            outputTokens: 30
        )

        XCTAssertEqual(cost, Decimal(string: "0.00172"))
    }

    func testEstimatesCodexGpt5CodexAlias() {
        let catalog = PricingCatalog()

        let cost = catalog.estimatedCost(
            provider: .codex,
            model: "gpt-5-codex",
            inputTokens: 200,
            cacheReadInputTokens: 40,
            outputTokens: 30
        )

        XCTAssertEqual(cost, Decimal(string: "0.000707"))
    }

    func testUnknownModelHasNoEstimate() {
        let catalog = PricingCatalog()

        XCTAssertNil(catalog.estimatedCost(
            provider: .codex,
            model: "unknown",
            inputTokens: 100,
            outputTokens: 100
        ))
    }

    private static let catalogVersionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
