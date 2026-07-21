import Foundation

struct MenuBarSummaryFormatter {
    private let currencyFormatter: NumberFormatter
    private let integerFormatter: NumberFormatter
    private let timeFormatter: DateFormatter

    init(locale: Locale = .current, timeZone: TimeZone = .current) {
        currencyFormatter = NumberFormatter()
        currencyFormatter.locale = locale
        currencyFormatter.numberStyle = .currency
        currencyFormatter.currencyCode = "USD"
        currencyFormatter.currencySymbol = "$"
        currencyFormatter.positiveFormat = "$#,##0.00"
        currencyFormatter.negativeFormat = "-$#,##0.00"
        currencyFormatter.usesGroupingSeparator = true
        currencyFormatter.minimumFractionDigits = 2
        currencyFormatter.maximumFractionDigits = 2

        integerFormatter = NumberFormatter()
        integerFormatter.locale = locale
        integerFormatter.numberStyle = .decimal
        integerFormatter.usesGroupingSeparator = true
        integerFormatter.maximumFractionDigits = 0

        timeFormatter = DateFormatter()
        timeFormatter.locale = locale
        timeFormatter.timeZone = timeZone
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
    }

    func statusTitle(for snapshot: MenuBarSummarySnapshot, displayMode: MenuBarSummaryDisplayMode) -> String {
        switch displayMode {
        case .cost:
            if snapshot.totalCost == nil, snapshot.totalTokens > 0 {
                return "\(formattedTokens(snapshot.totalTokens)) tokens"
            }

            return formattedCost(snapshot.totalCost)
        case .tokens:
            return "\(formattedTokens(snapshot.totalTokens)) tokens"
        case .costAndTokens:
            return "\(formattedCost(snapshot.totalCost)) · \(formattedTokens(snapshot.totalTokens)) tokens"
        }
    }

    func menuCostText(_ cost: Decimal?) -> String {
        "\(formattedCost(cost)) estimated"
    }

    func compactCostText(_ cost: Decimal?) -> String {
        formattedCost(cost)
    }

    func menuTokensText(_ tokens: Int) -> String {
        "\(formattedTokens(tokens)) tokens"
    }

    func compactTokensText(_ tokens: Int) -> String {
        "\(formattedCompactNumber(tokens)) tokens"
    }

    func menuSessionText(_ count: Int) -> String {
        count == 1 ? "1 session" : "\(formattedTokens(count)) sessions"
    }

    func menuTimeText(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    private func formattedCost(_ cost: Decimal?) -> String {
        guard let cost else {
            return "—"
        }

        return currencyFormatter.string(from: roundedCurrency(cost) as NSDecimalNumber) ?? "\(cost)"
    }

    private func formattedTokens(_ tokens: Int) -> String {
        integerFormatter.string(from: NSNumber(value: tokens)) ?? "\(tokens)"
    }

    private func formattedCompactNumber(_ value: Int) -> String {
        let absoluteValue = abs(value)

        if absoluteValue >= 1_000_000 {
            return formattedCompact(value, divisor: 1_000_000, suffix: "M")
        }

        if absoluteValue >= 1_000 {
            return formattedCompact(value, divisor: 1_000, suffix: "K")
        }

        return formattedTokens(value)
    }

    private func formattedCompact(_ value: Int, divisor: Int, suffix: String) -> String {
        let number = Double(value) / Double(divisor)
        let text = number >= 10
            ? String(format: "%.0f", number)
            : String(format: "%.1f", number)

        return "\(text)\(suffix)"
    }

    private func roundedCurrency(_ cost: Decimal) -> Decimal {
        var input = cost
        var output = Decimal()
        NSDecimalRound(&output, &input, 2, .plain)
        return output
    }
}
