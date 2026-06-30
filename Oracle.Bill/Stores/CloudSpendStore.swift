import Foundation
import Observation

@Observable
final class CloudSpendStore {
    private let accountsKey = "cloudAccounts"
    private let usageService: OracleUsageFetching
    private let notificationService: SpendNotificationing

    private(set) var accounts: [CloudAccount] = []
    var refreshIntervalMinutes: Double = {
        let val = UserDefaults.standard.double(forKey: "refreshIntervalMinutes")
        return val == 0 ? 5 : val
    }() {
        didSet {
            UserDefaults.standard.set(refreshIntervalMinutes, forKey: "refreshIntervalMinutes")
            startAutoRefresh()
        }
    }
    var lastError: String?

    var historicalSpend: [UUID: [HistoricalSpendPoint]] = [:]
    var isFetchingHistory: [UUID: Bool] = [:]
    var historyError: [UUID: String] = [:]

    /// Kept for backward compatibility only — no longer used to validate OCI response currency.
    /// The actual currency is read from each account's CostSnapshot.currency field.
    var selectedCurrency: String = UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD" {
        didSet {
            UserDefaults.standard.set(selectedCurrency, forKey: "selectedCurrency")
        }
    }

    private var refreshTask: Task<Void, Never>?

    init(
        usageService: OracleUsageFetching = OracleUsageService(),
        notificationService: SpendNotificationing = UserNotificationService()
    ) {
        self.usageService = usageService
        self.notificationService = notificationService
        loadAccounts()
        startAutoRefresh()
    }

    var totalSpend: Decimal {
        accounts.reduce(Decimal.zero) { result, account in
            result + (account.snapshot?.amount ?? Decimal.zero)
        }
    }

    /// The total spend formatted for display.
    /// When all accounts share the same OCI billing currency that currency is used;
    /// when accounts have different currencies (e.g. USD + SGD) the amounts cannot
    /// be meaningfully summed, so we display each account's value separately.
    var totalSpendText: String {
        let currencies = Set(accounts.compactMap { $0.snapshot?.currency })
        if currencies.count == 1, let currency = currencies.first {
            return MoneyFormatter.string(from: totalSpend, currency: currency)
        } else if currencies.count > 1 {
            // Mixed billing currencies — show per-account amounts instead of a misleading sum
            return accounts.compactMap { account -> String? in
                guard let snapshot = account.snapshot else { return nil }
                return MoneyFormatter.string(from: snapshot.amount, currency: snapshot.currency)
            }.joined(separator: " + ")
        } else {
            return MoneyFormatter.string(from: totalSpend, currency: nil)
        }
    }

    var hasAccounts: Bool {
        !accounts.isEmpty
    }

    func addOCIAccount(displayName: String, config: OCIConfiguration, privateKeyPEM: String?) {
        lastError = nil

        let account = CloudAccount(
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            region: config.region,
            tenancyId: config.tenancyId,
            userId: config.userId,
            fingerprint: config.fingerprint
        )

        do {
            let key = try privateKeyPEM ?? loadPrivateKey(from: config.keyFile)
            try KeychainCredentialStore.save(key, for: account.id)
            accounts.append(account)
            saveAccounts()
            Task {
                await refresh(accountID: account.id)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func rename(accountID: CloudAccount.ID, to displayName: String) {
        update(accountID: accountID) { account in
            account.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func setWarning(accountID: CloudAccount.ID, amount: Decimal?, enabled: Bool) {
        update(accountID: accountID) { account in
            account.warningAmountUSD = amount
            account.notificationsEnabled = enabled
        }

        if enabled {
            Task {
                _ = await notificationService.requestAuthorizationIfNeeded()
            }
        }
    }

    func displayName(for resource: ResourceCostSnapshot, in account: CloudAccount) -> String {
        if let preferredName = account.resourcePreferences[resource.preferenceKey]?.displayName?.nilIfBlank {
            return preferredName
        }
        return formatResourceName(displayName: resource.displayName, resourceId: resource.resourceId)
    }

    private func formatResourceName(displayName: String, resourceId: String?) -> String {
        let rawName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        if rawName.hasPrefix("ocid1.") {
            return parseOCID(rawName)
        }

        if let resourceId, resourceId.hasPrefix("ocid1.") {
            let type = parseOCID(resourceId)
            return "\(type): \(rawName)"
        }

        if rawName.contains("_") {
            let cleanName = rawName
                .replacingOccurrences(of: "oci_", with: "")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
            return cleanName
        }

        return rawName
    }

    private func parseOCID(_ ocid: String) -> String {
        let parts = ocid.components(separatedBy: ".")
        guard parts.count >= 2 else {
            return ocid
        }

        let type = parts[1]

        let readableType: String
        switch type.lowercased() {
        case "bootvolume": readableType = "Boot Volume"
        case "volume": readableType = "Block Volume"
        case "instance": readableType = "Compute Instance"
        case "vnic": readableType = "Network Interface"
        case "subnet": readableType = "Subnet"
        case "vcn": readableType = "Virtual Network"
        case "image": readableType = "Compute Image"
        case "bucket": readableType = "Object Storage"
        case "loadbalancer": readableType = "Load Balancer"
        case "key": readableType = "KMS Key"
        case "vault": readableType = "Key Vault"
        case "internetgateway": readableType = "Internet Gateway"
        case "natgateway": readableType = "NAT Gateway"
        case "securitylist": readableType = "Security List"
        case "routetable": readableType = "Route Table"
        default:
            readableType = type.capitalized
        }

        if let lastPart = parts.last, lastPart.count > 8 {
            let prefix = String(lastPart.prefix(4))
            let suffix = String(lastPart.suffix(4))
            return "\(readableType) (\(prefix)...\(suffix))"
        } else if let lastPart = parts.last {
            return "\(readableType) (\(lastPart))"
        }

        return readableType
    }

    func warningAmount(for resource: ResourceCostSnapshot, in account: CloudAccount) -> Decimal? {
        guard account.resourcePreferences[resource.preferenceKey]?.notificationsEnabled == true else {
            return nil
        }

        return account.resourcePreferences[resource.preferenceKey]?.warningAmountUSD
    }

    func setResourcePreference(
        accountID: CloudAccount.ID,
        resource: ResourceCostSnapshot,
        displayName: String,
        amount: Decimal?,
        enabled: Bool
    ) {
        update(accountID: accountID) { account in
            account.resourcePreferences[resource.preferenceKey] = ResourcePreference(
                displayName: displayName.nilIfBlank,
                warningAmountUSD: amount,
                notificationsEnabled: enabled
            )
        }

        if enabled {
            Task {
                _ = await notificationService.requestAuthorizationIfNeeded()
            }
        }
    }

    func remove(accountID: CloudAccount.ID) {
        accounts.removeAll { $0.id == accountID }
        KeychainCredentialStore.delete(for: accountID)
        saveAccounts()
    }

    func refreshAll() async {
        for account in accounts {
            await refresh(accountID: account.id)
        }
    }

    func refresh(accountID: CloudAccount.ID) async {
        guard let index = accounts.firstIndex(where: { $0.id == accountID }) else {
            return
        }

        accounts[index].status = .refreshing

        do {
            let snapshot = try await usageService.fetchMonthlySpend(for: accounts[index])
            accounts[index].snapshot = snapshot
            accounts[index].status = .current
            notificationService.notifyIfNeeded(for: accounts[index])
            saveAccounts()
        } catch let error as OracleUsageError {
            accounts[index].status = .connectorUnavailable(error.localizedDescription)
            saveAccounts()
        } catch {
            accounts[index].status = .failed(error.localizedDescription)
            saveAccounts()
        }
    }

    func fetchHistory(for accountID: CloudAccount.ID) async {
        guard let account = accounts.first(where: { $0.id == accountID }) else {
            return
        }

        isFetchingHistory[accountID] = true
        historyError[accountID] = nil

        do {
            let points = try await usageService.fetchHistoricalSpend(for: account)
            historicalSpend[accountID] = points
        } catch {
            historyError[accountID] = error.localizedDescription
        }

        isFetchingHistory[accountID] = false
    }

    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                let minutes = self.refreshIntervalMinutes
                do {
                    try await Task.sleep(nanoseconds: UInt64(minutes * 60 * 1_000_000_000))
                } catch {
                    break
                }
                if Task.isCancelled { break }
                await self.refreshAll()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func update(accountID: CloudAccount.ID, _ body: (inout CloudAccount) -> Void) {
        guard let index = accounts.firstIndex(where: { $0.id == accountID }) else {
            return
        }

        body(&accounts[index])
        saveAccounts()
    }

    private func loadAccounts() {
        guard let data = UserDefaults.standard.data(forKey: accountsKey) else {
            return
        }

        do {
            accounts = try JSONDecoder.oracleBill.decode([CloudAccount].self, from: data)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func saveAccounts() {
        do {
            let data = try JSONEncoder.oracleBill.encode(accounts)
            UserDefaults.standard.set(data, forKey: accountsKey)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func loadPrivateKey(from keyFile: String?) throws -> String {
        guard let keyFile,
              !keyFile.isEmpty,
              keyFile != "<path to your private keyfile>" else {
            throw OracleUsageError.missingCredential
        }

        return try String(contentsOfFile: NSString(string: keyFile).expandingTildeInPath, encoding: .utf8)
    }
}

extension JSONEncoder {
    static var oracleBill: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension ResourceCostSnapshot {
    var preferenceKey: String {
        resourceId ?? displayName
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
