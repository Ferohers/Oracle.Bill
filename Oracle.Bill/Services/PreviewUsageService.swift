import Foundation

struct PreviewUsageService: OracleUsageFetching {
    func fetchMonthlySpend(for account: CloudAccount) async throws -> CostSnapshot {
        CostSnapshot(
            amount: 0,
            currency: "USD",
            periodStart: Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date(),
            periodEnd: Date(),
            lastUpdated: Date(),
            source: .preview,
            resources: [
                ResourceCostSnapshot(resourceId: "preview-server-1", displayName: "Example Server 1", amount: 0, currency: "USD"),
                ResourceCostSnapshot(resourceId: "preview-server-2", displayName: "Example Server 2", amount: 0, currency: "USD")
            ]
        )
    }

    func fetchHistoricalSpend(for account: CloudAccount) async throws -> [HistoricalSpendPoint] {
        let calendar = Calendar.current
        let now = Date()
        return (0..<6).reversed().compactMap { monthsAgo -> HistoricalSpendPoint? in
            guard let date = calendar.date(byAdding: .month, value: -monthsAgo, to: now) else {
                return nil
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            let monthString = formatter.string(from: date)
            // Generate some realistic preview amounts: e.g. $120, $150, $85, $210, $175, $230
            let amounts: [Decimal] = [120, 150, 85, 210, 175, 230]
            let amount = amounts[monthsAgo % amounts.count]
            return HistoricalSpendPoint(month: monthString, amount: amount, currency: "USD", date: date)
        }
    }
}
