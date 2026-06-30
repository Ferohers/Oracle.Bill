import Charts
import SwiftUI

struct AccountManagerView: View {
    @Bindable var store: CloudSpendStore
    @State private var accountToDelete: CloudAccount?
    @State private var isAddingAccount = false
    @State private var selectedAccountID: UUID?
    @State private var isSettingsExpanded = false
    @State private var isHoveringHeader = false

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $selectedAccountID) {
                    ForEach(store.accounts) { account in
                        AccountManagerRow(store: store, account: account)
                            .tag(account.id)
                            .contextMenu {
                                Button("Refresh") {
                                    Task {
                                        await store.refresh(accountID: account.id)
                                    }
                                }
                                Button("Remove", role: .destructive) {
                                    accountToDelete = account
                                }
                            }
                    }
                }

                Divider()

                VStack(spacing: 0) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            isSettingsExpanded.toggle()
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: isSettingsExpanded ? "chevron.down" : "chevron.up")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(isHoveringHeader ? .primary : .secondary)
                            
                            Text("General Settings")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isHoveringHeader ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isHoveringHeader ? Color.secondary.opacity(0.08) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.15)) {
                            isHoveringHeader = hovering
                        }
                    }
                    
                    if isSettingsExpanded {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Slider(value: $store.refreshIntervalMinutes, in: 5...360, step: 5) {
                                    Text("Auto Refresh")
                                        .font(.callout.weight(.medium))
                                } minimumValueLabel: {
                                    Text("5m").font(.caption2)
                                } maximumValueLabel: {
                                    Text("6h").font(.caption2)
                                }

                                Text("Interval: \(Int(store.refreshIntervalMinutes)) minutes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Picker("Currency", selection: $store.selectedCurrency) {
                                Text("Euro (€)").tag("EUR")
                                Text("US Dollar ($)").tag("USD")
                                Text("British Pound (£)").tag("GBP")
                                Text("Japanese Yen (¥)").tag("JPY")
                                Text("Swiss Franc (CHF)").tag("CHF")
                            }
                            .pickerStyle(.menu)
                        }
                        .padding([.horizontal, .bottom], 16)
                    }
                }
                .background(.background)
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 450)
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem {
                    Button {
                        isAddingAccount = true
                    } label: {
                        Label("Add Account", systemImage: "plus")
                    }
                    .help("Add Oracle account")
                }
            }
        } detail: {
            if let selectedAccountID, let account = store.accounts.first(where: { $0.id == selectedAccountID }) {
                AccountDetailView(store: store, account: account)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "cloud")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Select an Account")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $isAddingAccount) {
            AddAccountView(store: store)
        }
        .onChange(of: selectedAccountID) { _, newValue in
            if let newValue {
                Task {
                    await store.fetchHistory(for: newValue)
                }
            }
        }
        .onAppear {
            if selectedAccountID == nil, let firstAccount = store.accounts.first {
                selectedAccountID = firstAccount.id
            }
            if let selectedAccountID {
                Task {
                    await store.fetchHistory(for: selectedAccountID)
                }
            }
        }
        .alert("Remove Account?", isPresented: Binding(
            get: { accountToDelete != nil },
            set: { if !$0 { accountToDelete = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let accountToDelete {
                    store.remove(accountID: accountToDelete.id)
                    if selectedAccountID == accountToDelete.id {
                        selectedAccountID = store.accounts.first?.id
                    }
                }
                accountToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                accountToDelete = nil
            }
        } message: {
            Text("The saved credential for this account will also be removed from Keychain.")
        }
    }
}

private struct AccountManagerRow: View {
    var store: CloudSpendStore
    var account: CloudAccount
    @State private var name: String
    @State private var warningText: String
    @State private var notificationsEnabled: Bool

    init(store: CloudSpendStore, account: CloudAccount) {
        self.store = store
        self.account = account
        _name = State(initialValue: account.displayName)
        _warningText = State(initialValue: account.warningAmountUSD.map { NSDecimalNumber(decimal: $0).stringValue } ?? "")
        _notificationsEnabled = State(initialValue: account.notificationsEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Account name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.headline)
                    .onSubmit {
                        store.rename(accountID: account.id, to: name)
                    }

                Spacer()

                Text(account.snapshot.map { MoneyFormatter.string(from: $0.amount, currency: $0.currency) } ?? "--")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                Toggle("Warning", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        saveWarning(enabled: newValue)
                    }

                TextField(MoneyFormatter.currencyCode, text: $warningText)
                    .frame(width: 72)
                    .textFieldStyle(.roundedBorder)
                    .monospacedDigit()
                    .onSubmit {
                        saveWarning(enabled: notificationsEnabled)
                    }

                Spacer()

                Button {
                    Task {
                        await store.refresh(accountID: account.id)
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .help("Refresh usage")
            }
            .font(.caption)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 6)
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

    private func saveWarning(enabled: Bool) {
        store.setWarning(
            accountID: account.id,
            amount: Decimal(string: warningText),
            enabled: enabled
        )
    }
}

struct AccountDetailView: View {
    var store: CloudSpendStore
    var account: CloudAccount

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header card
                VStack(alignment: .leading, spacing: 8) {
                    Text(account.displayName)
                        .font(.title.weight(.bold))

                    HStack(spacing: 16) {
                        VStack(alignment: .leading) {
                            Text("Region")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(account.region)
                                .font(.subheadline.weight(.semibold))
                        }

                        Divider()
                            .frame(height: 24)

                        VStack(alignment: .leading) {
                            Text("Tenancy ID")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(account.tenancyId)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        if let currentSpend = account.snapshot {
                            Divider()
                                .frame(height: 24)

                            VStack(alignment: .leading) {
                                Text("Current Spend")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(MoneyFormatter.string(from: currentSpend.amount, currency: currentSpend.currency))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                // History chart section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Monthly Spending History")
                        .font(.headline)

                    if store.isFetchingHistory[account.id] == true {
                        HStack {
                            Spacer()
                            ProgressView("Fetching history...")
                                .controlSize(.small)
                            Spacer()
                        }
                        .frame(height: 200)
                    } else if let error = store.historyError[account.id] {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title)
                                .foregroundStyle(.red)
                            Text("Failed to load historical data")
                                .font(.subheadline.weight(.semibold))
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Try Again") {
                                Task {
                                    await store.fetchHistory(for: account.id)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    } else if let points = store.historicalSpend[account.id], !points.isEmpty {
                        Chart {
                            ForEach(points) { point in
                                    BarMark(
                                        x: .value("Month", point.month),
                                        y: .value("Spend (\(point.currency ?? MoneyFormatter.currencyCode))", Double(truncating: point.amount as NSDecimalNumber))
                                    )
                                    .foregroundStyle(Color.accentColor.gradient)
                                    .annotation(position: .top, alignment: .center) {
                                        Text(MoneyFormatter.string(from: point.amount, currency: point.currency))
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                            }

                            if let limit = account.warningAmountUSD, account.notificationsEnabled {
                                RuleMark(y: .value("Warning Limit", Double(truncating: limit as NSDecimalNumber)))
                                    .foregroundStyle(.red)
                                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                                    .annotation(position: .top, alignment: .leading) {
                                        Text("Warning Limit (\(MoneyFormatter.string(from: limit)))")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.red)
                                    }
                            }
                        }
                        .frame(height: 200)
                        .padding(.top, 16)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "chart.bar")
                                .font(.title)
                                .foregroundStyle(.secondary)
                            Text("No historical data available")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Resources list section
                if let resources = account.snapshot?.resources, !resources.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Month Breakdown")
                            .font(.headline)

                        VStack(spacing: 0) {
                            ForEach(resources) { resource in
                                HStack {
                                    Text(store.displayName(for: resource, in: account))
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                Text(MoneyFormatter.string(from: resource.amount, currency: resource.currency))
                                        .font(.subheadline.monospacedDigit())
                                }
                                .padding(.vertical, 8)

                                if resource != resources.last {
                                    Divider()
                                }
                            }
                        }
                        .padding(14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
