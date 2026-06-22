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
    var amountUSD: Decimal
    var periodStart: Date
    var periodEnd: Date
    var lastUpdated: Date
    var source: SpendDataSource
    var resources: [ResourceCostSnapshot] = []
}

struct ResourceCostSnapshot: Codable, Equatable, Identifiable {
    var resourceId: String?
    var displayName: String
    var amountUSD: Decimal

    var id: String {
        resourceId ?? displayName
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
    var amountUSD: Decimal
    var date: Date
}
