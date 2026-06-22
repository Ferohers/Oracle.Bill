import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @Bindable var store: CloudSpendStore
    @Environment(\.openWindow) private var openWindow
    @State private var selectedAccount: CloudAccount?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if store.hasAccounts {
                accountList
            } else {
                emptyState
            }

            Divider()

            footer
        }
        .padding(16)
        // AddAccountView is opened as a separate Window scene (id: "add-account")
        // to avoid focus-loss dismissal of the MenuBarExtra popup.
        .sheet(item: $selectedAccount) { account in
            WarningSettingsView(store: store, account: account)
        }
        .task {
            await store.refreshAll()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Oracle Spend")
                    .font(.headline)
                Text("Month to date")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(store.totalSpendText)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
        }
    }

    private var accountList: some View {
        VStack(spacing: 8) {
            ForEach(store.accounts) { account in
                Button {
                    selectedAccount = account
                } label: {
                    AccountSpendRow(account: account)
                }
                .buttonStyle(.plain)
                .help("Set a spend warning for \(account.displayName)")
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No Oracle accounts yet", systemImage: "cloud.fill")
                .font(.headline)
            Text("Add your Oracle config and private key to start tracking monthly USD spend.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var footer: some View {
        HStack {
            Button {
                openWindow(id: "add-account")
            } label: {
                Label("Add", systemImage: "plus")
            }

            Button {
                Task {
                    await store.refreshAll()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }

            Spacer()

            Button {
                openWindow(id: "accounts")
            } label: {
                Label("Accounts", systemImage: "gearshape")
            }

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .help("Quit Oracle Bill")
        }
        .labelStyle(.iconOnly)
        .controlSize(.small)
    }
}

struct MenuBarLabelView: View {
    var store: CloudSpendStore

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "cloud")
            Text(store.totalSpendText)
                .monospacedDigit()
        }
    }
}

private struct AccountSpendRow: View {
    var account: CloudAccount
    var resource: ResourceCostSnapshot? = nil
    var displayName: String? = nil
    var warningAmount: Decimal? = nil

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(displayName ?? resource?.displayName ?? account.displayName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text(amountText)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .monospacedDigit()

                if let limit = warningAmount ?? accountWarningAmount {
                    Label(MoneyFormatter.string(from: limit), systemImage: "bell")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .contentShape(Rectangle())
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var amountText: String {
        if let amount = resource?.amountUSD {
            return MoneyFormatter.string(from: amount)
        }

        if let amount = account.snapshot?.amountUSD {
            return MoneyFormatter.string(from: amount)
        }

        return "--"
    }

    private var accountWarningAmount: Decimal? {
        guard resource == nil, account.notificationsEnabled else {
            return nil
        }

        return account.warningAmountUSD
    }

    private var statusText: String {
        switch account.status {
        case .needsRefresh:
            "Needs refresh"
        case .refreshing:
            "Refreshing..."
        case .current:
            account.snapshot?.source.rawValue ?? "Current"
        case .connectorUnavailable(let message), .failed(let message):
            message
        }
    }
}

private struct ResourceWarningTarget: Identifiable {
    var account: CloudAccount
    var resource: ResourceCostSnapshot

    var id: String {
        "\(account.id.uuidString)-\(resource.preferenceKey)"
    }
}

#Preview {
    MenuBarContentView(store: CloudSpendStore(usageService: PreviewUsageService()))
}
