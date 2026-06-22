import SwiftUI

struct SettingsView: View {
    @Bindable var store: CloudSpendStore

    var body: some View {
        Form {
            Section("Refresh") {
                Slider(value: $store.refreshIntervalMinutes, in: 15...360, step: 15) {
                    Text("Interval")
                } minimumValueLabel: {
                    Text("15m")
                } maximumValueLabel: {
                    Text("6h")
                }

                Text("\(Int(store.refreshIntervalMinutes)) minutes")
                    .foregroundStyle(.secondary)
            }

            Section("Display Currency") {
                Picker("Currency", selection: $store.selectedCurrency) {
                    Text("Euro (€)").tag("EUR")
                    Text("US Dollar ($)").tag("USD")
                    Text("British Pound (£)").tag("GBP")
                    Text("Japanese Yen (¥)").tag("JPY")
                    Text("Swiss Franc (CHF)").tag("CHF")
                }
                .pickerStyle(.menu)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 360)
    }
}
