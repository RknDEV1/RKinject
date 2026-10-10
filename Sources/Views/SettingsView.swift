import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(PackageManager.self) private var pm
    @AppStorage("catalogURL") private var catalogURL = ""

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("settings.open_settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                } header: {
                    Text("settings.language")
                } footer: {
                    Text("settings.language_hint")
                }

                Section {
                    TextField("settings.catalog_placeholder", text: $catalogURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onSubmit { Task { await pm.loadCatalog() } }
                } header: {
                    Text("settings.catalog")
                } footer: {
                    Text("settings.catalog_hint")
                }

                Section("settings.about") {
                    LabeledContent("settings.version", value: version)
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") {
                        Task { await pm.loadCatalog() }
                        dismiss()
                    }
                }
            }
        }
    }
}
