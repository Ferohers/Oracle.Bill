# Oracle Bill

Oracle Bill is a lightweight, premium macOS menu bar application designed to help you track month-to-date Oracle Cloud Infrastructure (OCI) spend in USD(or Euro) across multiple accounts or server groups.

It surfaces real-time costs directly in your menu bar, alerts you when your configured warning thresholds are breached, and stores all sensitive private keys and API credentials securely in the macOS Keychain.

![Menu Bar Popover](screenshots/Screenshot%202026-06-22%20at%2016.19.56.jpg)

---

## Features

- **Menu Bar Status**: Displays total month-to-date OCI spend in a clean, monospaced USD format directly in the menu bar.
- **Multi-Account Support**: Manage multiple OCI tenancy configurations independently without merged data unless requested.
- **Keychain Storage**: Securely saves sensitive private keys and OCI credentials in the system Keychain. Local `UserDefaults` only store harmless metadata.
- **Warnings & Notifications**: Trigger custom macOS notifications when an account's monthly spend crosses a user-defined USD threshold.
- **Tahoe Style UI**: Uses modern native macOS design patterns, standard system materials, semantic colors, and light/dark mode support.
- **Direct OCI Billing Queries**: Authenticates directly with the Oracle Usage API using native RSA OCI Request Signing (OCI Signature Version 1).
- **Monthly History Chart**: Visualise spending trends across the last 6 months per account.
- **Per-Resource Breakdown**: Drill down into Compute instances, Boot Volumes, Network Interfaces, and more within each account.

---

## Screenshots

### Menu Bar Popover
The compact popover shows total month-to-date spend and a row per configured account, with quick access to add accounts, refresh data, open settings, or quit.

![Menu Bar Popover](screenshots/Screenshot%202026-06-22%20at%2016.19.56.jpg)

### Account Manager — Spend Overview & History
Clicking an account opens the Account Manager window, showing region, tenancy ID, current spend, and a 6-month spending history chart.

![Account Manager Overview](screenshots/Screenshot%202026-06-22%20at%2016.20.04.jpg)

### Current Month Breakdown
Scrolling down in the Account Manager reveals a per-resource cost breakdown for the current billing period, covering Compute instances, Boot Volumes, Network Interfaces, and other OCI services.

![Current Month Breakdown](screenshots/Screenshot%202026-06-22%20at%2016.20.10.jpg)

---

## Setup & OCI Credentials

To connect Oracle Bill to your Oracle Cloud account, you need your OCI Configuration Details and a Private Key (`.pem` format) with read privileges for the Usage API.

### 1. Generate an API Key in the OCI Console

1. Log in to the **[Oracle Cloud Infrastructure Console](https://cloud.oracle.com)**.
2. Open the **Profile menu** (top-right corner) and click **User settings**.
3. Under the **Resources** section in the left sidebar, click **API Keys**.
4. Click **Add API Key**.
5. Select **Generate API Key Pair** and click **Download Private Key** to save the `.pem` file to your Mac. Keep this file safe — you will need it in the next step.
6. Click **Add** to confirm.
7. The console will show a **Configuration File Preview** containing your credentials. Copy the entire block — it looks like this:
   ```ini
   [DEFAULT]
   user=ocid1.user.oc1..aaaaaaaaxxx...
   fingerprint=xx:xx:xx:xx:xx:xx:xx:xx...
   tenancy=ocid1.tenancy.oc1..aaaaaaaaxxx...
   region=eu-zurich-1
   key_file=<path to your private keyfile>
   ```

### 2. Add the Account to Oracle Bill

1. Open the **Oracle Bill** menu bar popover and click the **+** button.
2. Paste the copied **OCI Configuration Block** into the configuration text area.
3. Open the downloaded `.pem` file in any text editor (e.g. TextEdit in plain-text mode), copy its entire contents — including the `-----BEGIN RSA PRIVATE KEY-----` and `-----END RSA PRIVATE KEY-----` lines — and paste into the **Private Key** field.
4. Click **Save**. Oracle Bill will securely store the private key in your macOS Keychain and immediately begin querying your OCI billing data.

> **Note**: Oracle Bill only ever requests the OCI Usage API. Your private key never leaves your Mac and is never transmitted anywhere.

---

## Technical Stack & Architecture

- **Platform**: macOS 14.0+
- **Language**: Swift 5.9 (SwiftUI)
- **UI Paradigm**: Menu Bar App (`MenuBarExtra` with `.window` style content)

### Folder Structure

| Path | Purpose |
|------|---------|
| `App/` | Entry point — `Oracle_BillApp.swift` |
| `Models/` | `CloudAccount`, `OCIConfiguration` data models |
| `Stores/` | `CloudSpendStore` — refresh lifecycle and state |
| `Services/OCIRequestSigner.swift` | Native OCI Signature v1 request signing (RSA/SHA-256) |
| `Services/OracleUsageService.swift` | OCI Usage API queries |
| `Services/KeychainCredentialStore.swift` | macOS Keychain integration |
| `Services/NotificationService.swift` | Local push notifications |
| `Views/MenuBarContentView.swift` | Menu bar dropdown content |
| `Views/AccountManagerView.swift` | Account list, history chart, and breakdown |
| `Views/WarningSettingsView.swift` | Warning threshold configuration |
| `Support/MoneyFormatter.swift` | Currency formatting utilities |

---

## Build & Release

### Generating App Icons
Regenerate all icon resolutions from the master `1024×1024` source:
```bash
./stuff/generate_icons.sh
```

### Creating a Release Bundle
```bash
./build_release.sh
```
This script will:
1. Clean previous build folders.
2. Compile using `xcodebuild` in **Release** configuration.
3. Export `dist/Oracle.Bill.app`.
4. Create `dist/Oracle.Bill.zip` — a zipped archive.
5. Create `dist/Oracle.Bill.dmg` — a macOS disk image installer with an Applications shortcut.

> The `dist/` folder is excluded from version control by `.gitignore`.

---

## Signed & Notiarized Releases 

[Github Releases](https://github.com/Ferohers/Oracle.Bill/releases)

## Security & Privacy

- **Outbound Connections**: The app requests sandbox outgoing network permissions solely to query the official OCI Usage API (`https://usageapi.<region>.oci.oraclecloud.com`) or your configured custom gateway/proxy endpoint.
- **No Third-Party Transmission**: All private keys, OCIDs, and configuration metadata remain 100% on your local machine. No tracking, telemetry, or third-party endpoints are used.
- **Keychain-Secured Credentials**: OCI private keys are stored in the macOS Keychain, protected by system-level hardware encryption. They are never written to disk in plaintext.
- **Least-Privilege IAM**: The OCI user used for cost queries should have only `read usage-report` permission — no write or administrative access required.
