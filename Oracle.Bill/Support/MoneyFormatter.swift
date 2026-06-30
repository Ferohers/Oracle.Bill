import Foundation

enum MoneyFormatter {
    /// The user's chosen display currency (used as a fallback when the OCI billing currency is unknown).
    static var currencyCode: String {
        UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD"
    }

    static var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.currencySymbol ?? ""
    }

    /// Formats `amount` using `currencyCode` (the user's display-currency preference).
    /// Use this only when you don't know the actual OCI billing currency.
    static func string(from amount: Decimal) -> String {
        string(from: amount, currency: currencyCode)
    }

    /// Formats `amount` using the given ISO 4217 `currency` code.
    /// Pass the currency that came back from OCI so the value is shown in its true denomination.
    static func string(from amount: Decimal, currency: String?) -> String {
        let code = currency ?? currencyCode
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(code) \(amount)"
    }
}

extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
