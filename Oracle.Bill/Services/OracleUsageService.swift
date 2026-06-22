import Foundation

protocol OracleUsageFetching: Sendable {
    func fetchMonthlySpend(for account: CloudAccount) async throws -> CostSnapshot
    func fetchHistoricalSpend(for account: CloudAccount) async throws -> [HistoricalSpendPoint]
}

struct OracleUsageService: OracleUsageFetching {
    func fetchMonthlySpend(for account: CloudAccount) async throws -> CostSnapshot {
        guard let credential = try KeychainCredentialStore.load(for: account.id), !credential.isEmpty else {
            throw OracleUsageError.missingCredential
        }

        guard let userId = account.userId, let fingerprint = account.fingerprint else {
            throw OracleUsageError.incompleteConfiguration
        }

        return try await fetchFromOCIUsageAPI(
            account: account,
            userId: userId,
            fingerprint: fingerprint,
            privateKeyPEM: credential
        )
    }

    func fetchHistoricalSpend(for account: CloudAccount) async throws -> [HistoricalSpendPoint] {
        guard let credential = try KeychainCredentialStore.load(for: account.id), !credential.isEmpty else {
            throw OracleUsageError.missingCredential
        }

        guard let userId = account.userId, let fingerprint = account.fingerprint else {
            throw OracleUsageError.incompleteConfiguration
        }

        return try await fetchHistoricalFromOCIUsageAPI(
            account: account,
            userId: userId,
            fingerprint: fingerprint,
            privateKeyPEM: credential
        )
    }

    private func fetchFromOCIUsageAPI(
        account: CloudAccount,
        userId: String,
        fingerprint: String,
        privateKeyPEM: String
    ) async throws -> CostSnapshot {
        let period = Self.currentMonthPeriod()
        let endpoint = URL(string: "https://usageapi.\(account.region).oci.oraclecloud.com/20200107/usage")!
        let body = UsageAPIRequest(
            tenantId: account.tenancyId,
            timeUsageStarted: period.start,
            timeUsageEnded: period.end
        )
        let bodyData = try JSONEncoder.ociUsage.encode(body)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        try OCIRequestSigner(
            tenancyId: account.tenancyId,
            userId: userId,
            fingerprint: fingerprint,
            privateKeyPEM: privateKeyPEM
        ).sign(&request, body: bodyData)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OracleUsageError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorResponse = try? JSONDecoder.oracleBill.decode(OCIErrorResponse.self, from: data)
            throw OracleUsageError.requestFailed(httpResponse.statusCode, errorResponse?.message)
        }

        let decoded = try JSONDecoder.oracleBill.decode(UsageAPIResponse.self, from: data)
        let amount = try decoded.monthToDateUSDAmount()
        let resources = try decoded.resourceCosts()
        return CostSnapshot(
            amountUSD: amount,
            periodStart: period.start,
            periodEnd: period.end,
            lastUpdated: Date(),
            source: .ociUsageAPI,
            resources: resources
        )
    }

    private func fetchHistoricalFromOCIUsageAPI(
        account: CloudAccount,
        userId: String,
        fingerprint: String,
        privateKeyPEM: String
    ) async throws -> [HistoricalSpendPoint] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let now = Date()
        guard let startDate = calendar.date(byAdding: .month, value: -6, to: now) else {
            return []
        }

        let start = Self.utcMidnight(for: startDate)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let end = Self.utcMidnight(for: tomorrow)

        let endpoint = URL(string: "https://usageapi.\(account.region).oci.oraclecloud.com/20200107/usage")!
        let body = HistoricalUsageAPIRequest(
            tenantId: account.tenancyId,
            timeUsageStarted: start,
            timeUsageEnded: end
        )
        let bodyData = try JSONEncoder.ociUsage.encode(body)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        try OCIRequestSigner(
            tenancyId: account.tenancyId,
            userId: userId,
            fingerprint: fingerprint,
            privateKeyPEM: privateKeyPEM
        ).sign(&request, body: bodyData)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OracleUsageError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorResponse = try? JSONDecoder.oracleBill.decode(OCIErrorResponse.self, from: data)
            throw OracleUsageError.requestFailed(httpResponse.statusCode, errorResponse?.message)
        }

        let decoded = try JSONDecoder.oracleBill.decode(HistoricalUsageAPIResponse.self, from: data)
        return decoded.toHistoricalSpendPoints()
    }

    private static func currentMonthPeriod() -> (start: Date, end: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        let start = calendar.date(from: components) ?? now
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let end = utcMidnight(for: tomorrow)
        return (start, end)
    }

    private static func utcMidnight(for date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: components) ?? date
    }
}

private struct UsageAPIRequest: Encodable {
    var granularity = "MONTHLY"
    var queryType = "COST"
    var tenantId: String
    var timeUsageStarted: Date
    var timeUsageEnded: Date
    var isAggregateByTime = true
    var groupBy = ["resourceId"]
}

private struct UsageAPIResponse: Decodable {
    var items: [UsageAPIItem]

    func monthToDateUSDAmount() throws -> Decimal {
        try items.reduce(Decimal.zero) { total, item in
            total + (try item.validatedAmount())
        }
    }

    func resourceCosts() throws -> [ResourceCostSnapshot] {
        try items.compactMap { item in
            let amount = try item.validatedAmount()

            return ResourceCostSnapshot(
                resourceId: item.resourceId,
                displayName: item.resourceName ?? item.resourceId ?? item.service ?? "Oracle resource",
                amountUSD: amount
            )
        }
        .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
}

private struct UsageAPIItem: Decodable {
    var attributedCost: Decimal?
    var computedAmount: Decimal?
    var currency: String?
    var resourceId: String?
    var resourceName: String?
    var service: String?

    enum CodingKeys: String, CodingKey {
        case attributedCost
        case computedAmount
        case currency
        case resourceId
        case resourceName
        case service
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        attributedCost = try container.decodeFlexibleDecimalIfPresent(forKey: .attributedCost)
        computedAmount = try container.decodeFlexibleDecimalIfPresent(forKey: .computedAmount)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        resourceId = try container.decodeIfPresent(String.self, forKey: .resourceId)
        resourceName = try container.decodeIfPresent(String.self, forKey: .resourceName)
        service = try container.decodeIfPresent(String.self, forKey: .service)
    }

    func validatedAmount() throws -> Decimal {
        let expectedCurrency = UserDefaults.standard.string(forKey: "selectedCurrency") ?? "EUR"
        if let currency, currency.uppercased() != expectedCurrency.uppercased() {
            throw OracleUsageError.unsupportedCurrency(currency)
        }

        return attributedCost ?? computedAmount ?? .zero
    }
}

private struct OCIErrorResponse: Decodable {
    var message: String?
}

enum OracleUsageError: LocalizedError {
    case missingCredential
    case incompleteConfiguration
    case invalidResponse
    case requestFailed(Int, String?)
    case unsupportedCurrency(String)

    var errorDescription: String? {
        switch self {
        case .missingCredential:
            "Add an OCI private key."
        case .incompleteConfiguration:
            "Add a complete OCI config with user, fingerprint, tenancy, and region."
        case .invalidResponse:
            "The usage endpoint returned an invalid response."
        case .requestFailed(let statusCode, let message):
            message.map { "OCI Usage API failed (\(statusCode)): \($0)" } ?? "OCI Usage API failed with status \(statusCode)."
        case .unsupportedCurrency(let currency):
            "OCI returned \(currency), but this app is configured for \(UserDefaults.standard.string(forKey: "selectedCurrency") ?? "EUR") display."
        }
    }
}

extension JSONDecoder {
    static var oracleBill: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    static var ociUsage: JSONEncoder {
        let encoder = JSONEncoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        encoder.dateEncodingStrategy = .formatted(formatter)
        return encoder
    }
}

private struct HistoricalUsageAPIRequest: Encodable {
    var granularity = "MONTHLY"
    var queryType = "COST"
    var tenantId: String
    var timeUsageStarted: Date
    var timeUsageEnded: Date
    var isAggregateByTime = true
    var groupBy: [String] = []
}

private struct HistoricalUsageAPIResponse: Decodable {
    var items: [HistoricalUsageItem]

    func toHistoricalSpendPoints() -> [HistoricalSpendPoint] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"

        var monthPoints: [String: (date: Date, amount: Decimal)] = [:]
        let calendar = Calendar(identifier: .gregorian)
        var utcCalendar = calendar
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let now = Date()

        for monthsAgo in 0..<6 {
            if let date = utcCalendar.date(byAdding: .month, value: -monthsAgo, to: now) {
                let monthString = formatter.string(from: date)
                let components = utcCalendar.dateComponents([.year, .month], from: date)
                if let startOfMonth = utcCalendar.date(from: components) {
                    monthPoints[monthString] = (startOfMonth, .zero)
                }
            }
        }

        for item in items {
            guard let amount = try? item.validatedAmount(),
                  let startDate = item.timeUsageStarted else {
                continue
            }
            let monthString = formatter.string(from: startDate)
            let components = utcCalendar.dateComponents([.year, .month], from: startDate)
            if let startOfMonth = utcCalendar.date(from: components) {
                let existing = monthPoints[monthString] ?? (startOfMonth, .zero)
                monthPoints[monthString] = (startOfMonth, existing.amount + amount)
            }
        }

        return monthPoints.map { key, value in
            HistoricalSpendPoint(month: key, amountUSD: value.amount, date: value.date)
        }
        .sorted { $0.date < $1.date }
    }
}

private struct HistoricalUsageItem: Decodable {
    var attributedCost: Decimal?
    var computedAmount: Decimal?
    var currency: String?
    var timeUsageStarted: Date?

    enum CodingKeys: String, CodingKey {
        case attributedCost
        case computedAmount
        case currency
        case timeUsageStarted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        attributedCost = try container.decodeFlexibleDecimalIfPresent(forKey: .attributedCost)
        computedAmount = try container.decodeFlexibleDecimalIfPresent(forKey: .computedAmount)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        timeUsageStarted = try container.decodeIfPresent(Date.self, forKey: .timeUsageStarted)
    }

    func validatedAmount() throws -> Decimal {
        let expectedCurrency = UserDefaults.standard.string(forKey: "selectedCurrency") ?? "EUR"
        if let currency, currency.uppercased() != expectedCurrency.uppercased() {
            throw OracleUsageError.unsupportedCurrency(currency)
        }
        return attributedCost ?? computedAmount ?? .zero
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleDecimalIfPresent(forKey key: Key) throws -> Decimal? {
        if let decimal = try? decode(Decimal.self, forKey: key) {
            return decimal
        }
        if let string = try? decode(String.self, forKey: key) {
            return Decimal(string: string)
        }
        if let double = try? decode(Double.self, forKey: key) {
            return Decimal(double)
        }
        return nil
    }
}
