import SwiftUI

struct WarningSettingsView: View {
    var store: CloudSpendStore
    var account: CloudAccount
    @Environment(\.dismiss) private var dismiss
    @State private var warningText = ""
    @State private var notificationsEnabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(account.displayName)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text("Set a monthly \(MoneyFormatter.currencyCode) warning for this account.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Current spend")
                    Spacer()
                    Text(currentSpend)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                }

                Toggle("Notify when this account reaches", isOn: $notificationsEnabled)

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
                    store.setWarning(
                        accountID: account.id,
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
        .frame(width: 380)
        .onAppear {
            warningText = account.warningAmountUSD.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
            notificationsEnabled = account.notificationsEnabled
        }
    }

    private var currentSpend: String {
        guard let amount = account.snapshot?.amountUSD else {
            return "--"
        }

        return MoneyFormatter.string(from: amount)
    }
}
