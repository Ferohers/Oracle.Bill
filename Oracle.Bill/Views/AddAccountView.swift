import SwiftUI
import UniformTypeIdentifiers

struct AddAccountView: View {
    var store: CloudSpendStore
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var configText = ""
    @State private var privateKeyPEM: String?
    @State private var importedKeyName: String?
    @State private var isImportingPrivateKey = false
    @State private var importError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            setupFields
            actions
        }
        .padding(24)
        .frame(width: 560)
        .fileImporter(
            isPresented: $isImportingPrivateKey,
            allowedContentTypes: [.data, .item],
            allowsMultipleSelection: false,
            onCompletion: importPrivateKey
        )
        .onChange(of: configText) { _, newValue in
            updateDisplayName(from: newValue)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Add Oracle Account")
                .font(.title3.weight(.semibold))
            Text("Paste the OCI config Oracle gives you, then import the matching private key file.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var setupFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            labeledField(number: 1, title: "Name this account") {
                TextField("Example Server 1", text: $displayName)
                    .textFieldStyle(.roundedBorder)
            }

            labeledField(number: 2, title: "Paste OCI config") {
                TextEditor(text: $configText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 150)
                    .padding(6)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.quaternary, lineWidth: 1)
                    }
            }

            labeledField(number: 3, title: "Import private key") {
                HStack {
                    Button {
                        isImportingPrivateKey = true
                    } label: {
                        Label(importedKeyName ?? "Choose .pem File", systemImage: "key")
                    }

                    if privateKeyPEM != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    Spacer()
                }
            }

            if let importedKeyName {
                Text(importedKeyName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let importError {
                Text(importError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actions: some View {
        HStack {
            Spacer()
            Button("Cancel", role: .cancel) {
                dismiss()
            }
            Button("Add Account") {
                addAccount()
                if store.lastError == nil {
                    dismiss()
                } else {
                    importError = store.lastError
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAdd)
        }
    }

    private func labeledField<Content: View>(
        number: Int,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label {
                Text(title)
                    .font(.callout.weight(.medium))
            } icon: {
                Text("\(number)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .frame(width: 18, height: 18)
                    .background(.regularMaterial, in: Circle())
            }

            content()
        }
    }

    private var canAdd: Bool {
        guard (try? OCIConfigurationParser.parse(configText)) != nil else {
            return false
        }

        return privateKeyPEM != nil || configText.contains("key_file=")
    }

    private func addAccount() {
        importError = nil

        do {
            let config = try OCIConfigurationParser.parse(configText)
            store.addOCIAccount(
                displayName: displayName.isEmpty ? "Oracle \(config.region)" : displayName,
                config: config,
                privateKeyPEM: privateKeyPEM
            )
        } catch {
            importError = error.localizedDescription
        }
    }

    private func importPrivateKey(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                return
            }

            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            privateKeyPEM = try String(contentsOf: url, encoding: .utf8)
            importedKeyName = url.lastPathComponent
            importError = nil
        } catch {
            importError = error.localizedDescription
        }
    }

    private func updateDisplayName(from configText: String) {
        guard displayName.isEmpty, let config = try? OCIConfigurationParser.parse(configText) else {
            return
        }

        displayName = "Oracle \(config.region)"
    }
}
