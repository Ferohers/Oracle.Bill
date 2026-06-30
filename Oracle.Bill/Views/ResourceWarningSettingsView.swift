import SwiftUI

struct ResourceWarningSettingsView: View {
    var store: CloudSpendStore
    var account: CloudAccount
    var resource: ResourceCostSnapshot
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var warningText = ""
    @State private var notificationsEnabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName.isEmpty ? store.displayName(for: resource, in: account) : displayName)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(account.displayName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Current spend")
                    Spacer()
                    Text(MoneyFormatter.string(from: resource.amount, currency: resource.currency))
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                }

                TextField("Resource name", text: $displayName)
                    .textFieldStyle(.roundedBorder)

                Toggle("Notify when this resource reaches", isOn: $notificationsEnabled)

                HStack {
                    Text(MoneyFormatter.currencySymbol)
                        .foregroundStyle(.secondary)
                    TextField("25.00", text: $warningText)
                        .textFieldStyle(.roundedBorder)
                        .monospacedDigit()
                }
                .disabled(!notificationsEnabled)
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Button("Save") {
                    store.setResourcePreference(
                        accountID: account.id,
                        resource: resource,
                        displayName: displayName,
                        amount: Decimal(string: warningText),
                        enabled: notificationsEnabled
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(notificationsEnabled && Decimal(string: warningText) == nil)
            }
        }
        .padding(22)
        .frame(width: 400)
        .onAppear {
            let preference = account.resourcePreferences[resource.preferenceKey]
            displayName = preference?.displayName ?? store.displayName(for: resource, in: account)
            warningText = preference?.warningAmountUSD.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
            notificationsEnabled = preference?.notificationsEnabled ?? false
        }
    }
}
