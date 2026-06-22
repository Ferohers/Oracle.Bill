import SwiftUI

@main
struct Oracle_BillApp: App {
    @State private var store = CloudSpendStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(store: store)
                .frame(width: 380)
        } label: {
            MenuBarLabelView(store: store)
        }
        .menuBarExtraStyle(.window)

        Window("Oracle Bill", id: "accounts") {
            AccountManagerView(store: store)
                .frame(minWidth: 520, minHeight: 520)
        }
        .windowResizability(.contentMinSize)

        Window("Add Oracle Account", id: "add-account") {
            AddAccountView(store: store)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 560, height: 560)

        Settings {
            SettingsView(store: store)
        }
    }
}
