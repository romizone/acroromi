import SwiftUI
import PDFKit

struct SecurityView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    @State private var userPassword = ""
    @State private var ownerPassword = ""
    @State private var confirmUserPassword = ""
    @State private var confirmOwnerPassword = ""
    @State private var setUserPassword = false
    @State private var setOwnerPassword = false
    @State private var allowPrinting = true
    @State private var allowCopying = true
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Protect PDF")
                .font(.headline)

            GroupBox("Document Open Password") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Require password to open", isOn: $setUserPassword)

                    if setUserPassword {
                        SecureField("Password", text: $userPassword)
                            .textFieldStyle(.roundedBorder)
                        SecureField("Confirm Password", text: $confirmUserPassword)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(8)
            }

            GroupBox("Permissions Password") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Set permissions password", isOn: $setOwnerPassword)

                    if setOwnerPassword {
                        SecureField("Owner Password", text: $ownerPassword)
                            .textFieldStyle(.roundedBorder)
                        SecureField("Confirm Owner Password", text: $confirmOwnerPassword)
                            .textFieldStyle(.roundedBorder)

                        Divider()

                        Toggle("Allow Printing", isOn: $allowPrinting)
                        Toggle("Allow Copying Text", isOn: $allowCopying)
                    }
                }
                .padding(8)
            }

            if showError {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack {
                if appState.documentState.isEncrypted {
                    Button("Remove Protection") {
                        removeProtection()
                    }
                    .foregroundColor(.red)
                }

                Spacer()

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Apply") {
                    applyProtection()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canApply)
            }
        }
        .padding()
        .frame(width: 450)
    }

    var canApply: Bool {
        if setUserPassword {
            if userPassword.isEmpty || userPassword != confirmUserPassword { return false }
        }
        if setOwnerPassword {
            if ownerPassword.isEmpty || ownerPassword != confirmOwnerPassword { return false }
        }
        return setUserPassword || setOwnerPassword
    }

    private func applyProtection() {
        guard let doc = appState.documentState.pdfDocument else { return }

        if setUserPassword && userPassword != confirmUserPassword {
            errorMessage = "User passwords do not match"
            showError = true
            return
        }

        if setOwnerPassword && ownerPassword != confirmOwnerPassword {
            errorMessage = "Owner passwords do not match"
            showError = true
            return
        }

        guard let url = PDFDocumentManager.savePanel(
            defaultName: appState.documentState.fileName.isEmpty ? "protected.pdf" : appState.documentState.fileName
        ) else { return }

        var options: [PDFDocumentWriteOption: Any] = [:]

        if setUserPassword && !userPassword.isEmpty {
            options[.userPasswordOption] = userPassword
        }

        if setOwnerPassword && !ownerPassword.isEmpty {
            options[.ownerPasswordOption] = ownerPassword
        }

        let success = doc.write(to: url, withOptions: options)
        if success {
            appState.documentState.fileURL = url
            appState.documentState.fileName = url.lastPathComponent
            appState.documentState.isEncrypted = true
            dismiss()
        } else {
            errorMessage = "Failed to save protected PDF"
            showError = true
        }
    }

    private func removeProtection() {
        guard let doc = appState.documentState.pdfDocument,
              let url = PDFDocumentManager.savePanel(
                defaultName: "unprotected_\(appState.documentState.fileName)"
              ) else { return }

        if doc.write(to: url) {
            appState.documentState.fileURL = url
            appState.documentState.fileName = url.lastPathComponent
            appState.documentState.isEncrypted = false
            dismiss()
        }
    }
}

struct PasswordPromptView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    @State private var password = ""
    @State private var showError = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 36))
                .foregroundColor(.accentColor)

            Text("This PDF is password protected")
                .font(.headline)

            Text("Enter the password to open this document.")
                .foregroundColor(.secondary)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
                .onSubmit { unlock() }

            if showError {
                Text("Incorrect password. Please try again.")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack {
                Button("Cancel") {
                    appState.closeDocument()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Unlock") { unlock() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty)
            }
        }
        .padding()
        .frame(width: 350)
    }

    private func unlock() {
        if appState.documentState.unlockDocument(password: password) {
            dismiss()
        } else {
            showError = true
            password = ""
        }
    }
}
