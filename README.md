# Oracle Bill

Oracle Bill is a lightweight, premium macOS menu bar application designed to help you track month-to-date Oracle Cloud Infrastructure (OCI) spend in USD across multiple accounts or server groups.

It surfaces real-time costs directly in your menu bar, alerts you when your configured warning thresholds are breached, and stores all sensitive private keys and API credentials securely in the macOS Keychain.

---

## Features

- **Menu Bar Status**: Displays total month-to-date OCI spend in a clean, monospaced USD format directly in the menu bar.
- **Multi-Account Support**: Manage multiple OCI tenancy configurations independently without merged data unless requested.
- **Keychain Storage**: Securely saves sensitive private keys and OCI credentials in the system Keychain. Local `UserDefaults` only store harmless metadata.
- **Warnings & Notifications**: Trigger custom macOS notifications when an account’s monthly spend crosses a user-defined USD threshold.
- **Tahoe Style UI**: Uses modern native macOS design patterns, standard system materials, semantic colors, and light/dark mode support.
- **Direct OCI Billing Queries**: Authenticates directly with the Oracle Usage API using native RSA OCI Request Signing (OCI Signature Version 1).

---

## Technical Stack & Architecture

- **Platform**: macOS 14.0+
- **Language**: Swift 5.9 (SwiftUI)
- **UI Paradigm**: Menu Bar App (`MenuBarExtra` with `.window` style content)

### Folder Structure

- [App](file:///Users/altan/Documents/Oracle.Bill/Oracle.Bill/App): Entry points and global app initialization ([Oracle_BillApp.swift](file:///Users/altan/Documents/Oracle.Bill/Oracle.Bill/App/Oracle_BillApp.swift)).
- [Models](file:///Users/altan/Documents/Oracle.Bill/Oracle.Bill/Models): Application models including [CloudAccount.swift](file:///Users/altan/Documents/Oracle.Bill/Oracle.Bill/Models/CloudAccount.swift) and [OCIConfiguration.swift](file:///Users/altan/Documents/Oracle.Bill/Oracle.Bill/Models/OCIConfiguration.swift).
- [Stores](file:///Users/altan/Documents/Oracle.Bill/Oracle.Bill/Stores): State management store ([CloudSpendStore.swift](file:///Users/altan/Documents/Oracle.Bill/Oracle.Bill/Stores/CloudSpendStore.swift)) managing refresh lifecycle.
- [Services](file:///Users/altan/Documents/Oracle.Bill/Oracle.Bill/Services):
  - [OCIRequestSigner.swift](file:///Users/altan/Documents/Oracle.Bill/Oracle.Bill/Services/OCIRequestSigner.swift): Signs native HTTPS requests using SHA-256 and RSA PEM keys.
  - [OracleUsageService.swift](file:///Users/altan/Documents/Oracle.Bill/Oracle.Bill/Services/OracleUsageService.swift): Calls OCI Usage API to query cost reports.
  - [KeychainCredentialStore.swift](file:///Users/altan/Documents/Oracle.Bill/Oracle.Bill/Services/KeychainCredentialStore.swift): Secure integration with macOS Keychain Services.
  - [NotificationService.swift](file:///Users/altan/Documents/Oracle.Bill/Oracle.Bill/Services/NotificationService.swift): Triggers local push notifications.
- [Views](file:///Users/altan/Documents/Oracle.Bill/Oracle.Bill/Views):
  - [MenuBarContentView.swift](file:///Users/altan/Documents/Oracle.Bill/Oracle.Bill/Views/MenuBarContentView.swift): Content container for the menu bar dropdown window.
  - [AccountManagerView.swift](file:///Users/altan/Documents/Oracle.Bill/Oracle.Bill/Views/AccountManagerView.swift): Window to add, view, and delete accounts and credentials.
  - [WarningSettingsView.swift](file:///Users/altan/Documents/Oracle.Bill/Oracle.Bill/Views/WarningSettingsView.swift): Notification/alert limits setup.
- [Support](file:///Users/altan/Documents/Oracle.Bill/Oracle.Bill/Support): Formatting and utilities like [MoneyFormatter.swift](file:///Users/altan/Documents/Oracle.Bill/Oracle.Bill/Support/MoneyFormatter.swift).
---

## Setup & OCI Credentials

To connect Oracle Bill to your Oracle Cloud account, you need your OCI Configuration Details and a Private Key (`.pem` format) with read privileges for the usage API.

### 1. Generating API Key & Configuration in OCI Console
1. Log in to your **Oracle Cloud Infrastructure Console**.
2. Open the Profile menu in the top-right corner and click **User settings**.
3. Under the **Resources** section on the left sidebar, click **API Keys**.
4. Click the **Add API Key** button.
5. Choose **Generate API Key Pair** and click **Download Private Key** to save the private key `.pem` file locally.
6. Click **Add**.
7. The console will display a **Configuration File Preview** text box containing details similar to:
   ```ini
   [DEFAULT]
   user=ocid1.user.oc1..aaaaaaaaxxx...
   fingerprint=xx:xx:xx:xx:xx:xx:xx:xx...
   tenancy=ocid1.tenancy.oc1..aaaaaaaaxxx...
   region=us-ashburn-1
   key_file=<path to your private keyfile>
   ```
8. Copy the entire configuration text block.

### 2. Adding the Account to Oracle Bill
1. Open the **Oracle Bill** menu bar popover and select **Account Manager** (or settings icon).
2. Click **Add Account** (or the `+` button).
3. Paste the copied **OCI Configuration Block** into the configuration text area.
4. Open the downloaded `.pem` private key file in any text editor, copy its entire contents (including `-----BEGIN RSA PRIVATE KEY-----` and `-----END RSA PRIVATE KEY-----`), and paste it into the **Private Key** field.
5. Click **Save**. The app will securely upload the private key to your macOS Keychain and begin displaying your OCI billing data.

---

## Build and Release

The project includes custom build automation scripts in the `stuff` and root folders.

### 1. Generating App Icons
To compile the source app icon asset into all resolutions:
```bash
./stuff/generate_icons.sh
```
This takes the 1024x1024 master icon file `stuff/1024x app icon.png` and populates the `AppIcon.appiconset` with properly formatted macOS and iOS resolutions.

### 2. Creating a Release Bundle
To compile a production release and generate distribution packages:
```bash
./build_release.sh
```
This script will:
1. Clean previous build folders.
2. Build the project using `xcodebuild` under the **Release** configuration.
3. Export the compiled application bundle to `dist/Oracle.Bill.app`.
4. Create a zipped archive at `dist/Oracle.Bill.zip`.
5. Package the app as a macOS disk image installer at `dist/Oracle.Bill.dmg`.

---

## Security & Privacy

- **Outbound Connections**: The app requests sandbox outgoing network permissions solely to query the official OCI Usage API (`https://usageapi.<region>.oci.oraclecloud.com`) or your configured custom gateway/proxy endpoint.
- **No Third-Party Transmission**: All your private keys, OCIDs, and configuration metadata remain 100% on your local machine. No tracking, telemetry, or third-party analytical endpoints are included.
- **Local Credentials**: OCI private keys are secured in macOS Keychain, protected by system-level hardware encryption.
