import Foundation

public struct PricingCatalog: Sendable {
    public struct Rates: Equatable, Sendable {
        public var inputPerMillion: Decimal
        public var cacheCreationPerMillion: Decimal?
        public var cacheReadPerMillion: Decimal?
        public var outputPerMillion: Decimal

        public init(
            inputPerMillion: Decimal,
            cacheCreationPerMillion: Decimal? = nil,
            cacheReadPerMillion: Decimal? = nil,
            outputPerMillion: Decimal
        ) {
            self.inputPerMillion = inputPerMillion
            self.cacheCreationPerMillion = cacheCreationPerMillion
            self.cacheReadPerMillion = cacheReadPerMillion
            self.outputPerMillion = outputPerMillion
        }
    }

    public static let sourceVersion = "2026-07-11"

    public init() {}

    public func estimatedCost(
        provider: Provider,
        model: String,
        inputTokens: Int?,
        cacheCreationInputTokens: Int? = nil,
        cacheReadInputTokens: Int? = nil,
        outputTokens: Int?
    ) -> Decimal? {
        guard let rates = rates(provider: provider, model: model) else {
            return nil
        }

        let standardInputTokens = max(
            0,
            (inputTokens ?? 0) - (provider == .codex ? (cacheReadInputTokens ?? 0) : 0)
        )
        let inputCost = cost(tokens: standardInputTokens, ratePerMillion: rates.inputPerMillion)
        let cacheCreationCost = cost(
            tokens: cacheCreationInputTokens ?? 0,
            ratePerMillion: rates.cacheCreationPerMillion ?? rates.inputPerMillion
        )
        let cacheReadCost = cost(
            tokens: cacheReadInputTokens ?? 0,
            ratePerMillion: rates.cacheReadPerMillion ?? rates.inputPerMillion
        )
        let outputCost = cost(tokens: outputTokens ?? 0, ratePerMillion: rates.outputPerMillion)

        return inputCost + cacheCreationCost + cacheReadCost + outputCost
    }

    public func rates(provider: Provider, model: String) -> Rates? {
        let normalizedModel = model.lowercased()

        switch provider {
        case .claude:
            if normalizedModel.contains("opus-4-8") || normalizedModel.contains("opus 4.8") {
                return Rates(
                    inputPerMillion: Decimal(5),
                    cacheCreationPerMillion: Decimal(string: "10"),
                    cacheReadPerMillion: Decimal(string: "0.50"),
                    outputPerMillion: Decimal(25)
                )
            }

            if normalizedModel.contains("sonnet-5") || normalizedModel.contains("sonnet 5") {
                return Rates(
                    inputPerMillion: Decimal(2),
                    cacheCreationPerMillion: Decimal(4),
                    cacheReadPerMillion: Decimal(string: "0.20"),
                    outputPerMillion: Decimal(10)
                )
            }

            if normalizedModel.contains("sonnet") {
                return Rates(
                    inputPerMillion: Decimal(3),
                    cacheCreationPerMillion: Decimal(6),
                    cacheReadPerMillion: Decimal(string: "0.30"),
                    outputPerMillion: Decimal(15)
                )
            }

            if normalizedModel.contains("opus") {
                return Rates(
                    inputPerMillion: Decimal(5),
                    cacheCreationPerMillion: Decimal(10),
                    cacheReadPerMillion: Decimal(string: "0.50"),
                    outputPerMillion: Decimal(25)
                )
            }

            return nil
        case .codex:
            if normalizedModel.contains("gpt-5.3-codex") || normalizedModel.contains("gpt-5-codex") {
                return Rates(
                    inputPerMillion: Decimal(string: "1.75")!,
                    cacheReadPerMillion: Decimal(string: "0.175"),
                    outputPerMillion: Decimal(14)
                )
            }

            if normalizedModel.contains("gpt-5.5") {
                return Rates(
                    inputPerMillion: Decimal(5),
                    cacheReadPerMillion: Decimal(string: "0.50"),
                    outputPerMillion: Decimal(30)
                )
            }

            return nil
        }
    }

    private func cost(tokens: Int, ratePerMillion: Decimal) -> Decimal {
        guard tokens > 0 else {
            return Decimal(0)
        }

        return Decimal(tokens) * ratePerMillion / Decimal(1_000_000)
    }
}
