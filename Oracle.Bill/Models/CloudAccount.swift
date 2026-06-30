import Foundation

struct CloudAccount: Codable, Identifiable, Equatable {
    var id: UUID
    var displayName: String
    var region: String
    var tenancyId: String
    var userId: String?
    var fingerprint: String?
    var warningAmountUSD: Decimal?
    var notificationsEnabled: Bool
    var resourcePreferences: [String: ResourcePreference]
    var snapshot: CostSnapshot?
    var status: AccountStatus

    init(
        id: UUID = UUID(),
        displayName: String,
        region: String,
        tenancyId: String,
        userId: String? = nil,
        fingerprint: String? = nil,
        warningAmountUSD: Decimal? = nil,
        notificationsEnabled: Bool = false,
        resourcePreferences: [String: ResourcePreference] = [:],
        snapshot: CostSnapshot? = nil,
        status: AccountStatus = .needsRefresh
    ) {
        self.id = id
        self.displayName = displayName
        self.region = region
        self.tenancyId = tenancyId
        self.userId = userId
        self.fingerprint = fingerprint
        self.warningAmountUSD = warningAmountUSD
        self.notificationsEnabled = notificationsEnabled
        self.resourcePreferences = resourcePreferences
        self.snapshot = snapshot
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case region
        case tenancyId
        case userId
        case fingerprint
        case warningAmountUSD
        case notificationsEnabled
        case resourcePreferences
        case snapshot
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        region = try container.decode(String.self, forKey: .region)
        tenancyId = try container.decode(String.self, forKey: .tenancyId)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        fingerprint = try container.decodeIfPresent(String.self, forKey: .fingerprint)
        warningAmountUSD = try container.decodeIfPresent(Decimal.self, forKey: .warningAmountUSD)
        notificationsEnabled = try container.decode(Bool.self, forKey: .notificationsEnabled)
        resourcePreferences = try container.decodeIfPresent([String: ResourcePreference].self, forKey: .resourcePreferences) ?? [:]
        snapshot = try container.decodeIfPresent(CostSnapshot.self, forKey: .snapshot)
        status = try container.decode(AccountStatus.self, forKey: .status)
    }
}

struct ResourcePreference: Codable, Equatable {
    var displayName: String?
    var warningAmountUSD: Decimal?
    var notificationsEnabled: Bool
}

struct CostSnapshot: Codable, Equatable {
    /// The billed amount in whatever currency OCI returns for this tenancy.
    var amount: Decimal
    /// ISO 4217 currency code as returned by OCI (e.g. "USD", "SGD", "EUR").
    /// `nil` when the currency is unknown (e.g. preview data or old cached snapshots).
    var currency: String?
    var periodStart: Date
    var periodEnd: Date
    var lastUpdated: Date
    var source: SpendDataSource
    var resources: [ResourceCostSnapshot]

    // MARK: - Backward-compatible decoding

    enum CodingKeys: String, CodingKey {
        case amount
        case amountUSD   // legacy key — kept so old persisted JSON can still be read
        case currency
        case periodStart
        case periodEnd
        case lastUpdated
        case source
        case resources
    }

    init(
        amount: Decimal,
        currency: String? = nil,
        periodStart: Date,
        periodEnd: Date,
        lastUpdated: Date,
        source: SpendDataSource,
        resources: [ResourceCostSnapshot] = []
    ) {
        self.amount = amount
        self.currency = currency
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.lastUpdated = lastUpdated
        self.source = source
        self.resources = resources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Prefer the new "amount" key; fall back to the legacy "amountUSD" key
        if let newAmount = try container.decodeIfPresent(Decimal.self, forKey: .amount) {
            amount = newAmount
        } else {
            amount = try container.decode(Decimal.self, forKey: .amountUSD)
        }
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        periodStart = try container.decode(Date.self, forKey: .periodStart)
        periodEnd = try container.decode(Date.self, forKey: .periodEnd)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        source = try container.decode(SpendDataSource.self, forKey: .source)
        resources = try container.decodeIfPresent([ResourceCostSnapshot].self, forKey: .resources) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(amount, forKey: .amount)
        try container.encodeIfPresent(currency, forKey: .currency)
        try container.encode(periodStart, forKey: .periodStart)
        try container.encode(periodEnd, forKey: .periodEnd)
        try container.encode(lastUpdated, forKey: .lastUpdated)
        try container.encode(source, forKey: .source)
        try container.encode(resources, forKey: .resources)
    }
}

struct ResourceCostSnapshot: Codable, Equatable, Identifiable {
    var resourceId: String?
    var displayName: String
    /// The billed amount in whatever currency OCI returns for this tenancy.
    var amount: Decimal
    /// ISO 4217 currency code as returned by OCI.
    var currency: String?

    var id: String {
        resourceId ?? displayName
    }

    // MARK: - Backward-compatible decoding

    enum CodingKeys: String, CodingKey {
        case resourceId
        case displayName
        case amount
        case amountUSD   // legacy key
        case currency
    }

    init(
        resourceId: String? = nil,
        displayName: String,
        amount: Decimal,
        currency: String? = nil
    ) {
        self.resourceId = resourceId
        self.displayName = displayName
        self.amount = amount
        self.currency = currency
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resourceId = try container.decodeIfPresent(String.self, forKey: .resourceId)
        displayName = try container.decode(String.self, forKey: .displayName)
        if let newAmount = try container.decodeIfPresent(Decimal.self, forKey: .amount) {
            amount = newAmount
        } else {
            amount = try container.decode(Decimal.self, forKey: .amountUSD)
        }
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(resourceId, forKey: .resourceId)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(amount, forKey: .amount)
        try container.encodeIfPresent(currency, forKey: .currency)
    }
}

enum SpendDataSource: String, Codable {
    case ociUsageAPI = "OCI Usage API"
    case costReport = "Cost Report"
    case preview = "Preview"
}

enum AccountStatus: Codable, Equatable {
    case needsRefresh
    case refreshing
    case current
    case connectorUnavailable(String)
    case failed(String)
}

struct HistoricalSpendPoint: Codable, Identifiable, Equatable {
    var id: String { month }
    var month: String
    /// The billed amount in whatever currency OCI returns for this tenancy.
    var amount: Decimal
    /// ISO 4217 currency code as returned by OCI.
    var currency: String?
    var date: Date

    // MARK: - Backward-compatible decoding

    enum CodingKeys: String, CodingKey {
        case month
        case amount
        case amountUSD   // legacy key
        case currency
        case date
    }

    init(month: String, amount: Decimal, currency: String? = nil, date: Date) {
        self.month = month
        self.amount = amount
        self.currency = currency
        self.date = date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        month = try container.decode(String.self, forKey: .month)
        if let newAmount = try container.decodeIfPresent(Decimal.self, forKey: .amount) {
            amount = newAmount
        } else {
            amount = try container.decode(Decimal.self, forKey: .amountUSD)
        }
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        date = try container.decode(Date.self, forKey: .date)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(month, forKey: .month)
        try container.encode(amount, forKey: .amount)
        try container.encodeIfPresent(currency, forKey: .currency)
        try container.encode(date, forKey: .date)
    }
}
