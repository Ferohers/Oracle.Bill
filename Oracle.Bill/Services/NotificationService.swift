import Foundation
import UserNotifications

protocol SpendNotificationing {
    func requestAuthorizationIfNeeded() async -> Bool
    func notifyIfNeeded(for account: CloudAccount)
}

struct UserNotificationService: SpendNotificationing {
    func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            return true
        }

        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func notifyIfNeeded(for account: CloudAccount) {
        guard let snapshot = account.snapshot else {
            return
        }

        notifyAccountIfNeeded(account: account, snapshot: snapshot)
        notifyResourcesIfNeeded(account: account, snapshot: snapshot)
    }

    private func notifyAccountIfNeeded(account: CloudAccount, snapshot: CostSnapshot) {
        guard account.notificationsEnabled,
              let limit = account.warningAmountUSD,
              snapshot.amount >= limit else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "\(account.displayName) reached its Oracle spend warning"
        content.body = "\(MoneyFormatter.string(from: snapshot.amount, currency: snapshot.currency)) of \(MoneyFormatter.string(from: limit, currency: snapshot.currency)) this month."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "spend-warning-\(account.id.uuidString)-\(snapshot.periodEnd.timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func notifyResourcesIfNeeded(account: CloudAccount, snapshot: CostSnapshot) {
        for resource in snapshot.resources {
            guard let preference = account.resourcePreferences[resource.preferenceKey],
                  preference.notificationsEnabled,
                  let limit = preference.warningAmountUSD,
                  resource.amount >= limit else {
                continue
            }

            let displayName = preference.displayName?.isEmpty == false ? preference.displayName ?? resource.displayName : resource.displayName
            let content = UNMutableNotificationContent()
            content.title = "\(displayName) reached its Oracle spend warning"
            content.body = "\(MoneyFormatter.string(from: resource.amount, currency: resource.currency)) of \(MoneyFormatter.string(from: limit, currency: resource.currency)) this month."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "spend-warning-\(account.id.uuidString)-\(resource.preferenceKey)-\(snapshot.periodEnd.timeIntervalSince1970)",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }
}
