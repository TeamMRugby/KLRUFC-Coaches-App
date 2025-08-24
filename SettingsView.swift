
import SwiftUI

struct SettingsView: View {
    @AppStorage("baseURL") private var baseURL: String = ""
    @State private var tempURL: String = ""
    @State private var showingAlert = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Server")) {
                    TextField("https://your-streamlit-app-url", text: $tempURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    Button("Save URL") {
                        baseURL = tempURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        showingAlert = true
                    }
                    .alert("Saved", isPresented: $showingAlert) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text("Base URL set to \(baseURL)")
                    }

                    Button("Open GMS (RFU)") {
                        if let url = URL(string: "https://gms.rfu.com/") {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                Section(header: Text("Tips")) {
                    Text("Set the server URL once. Tabs will append ?view=dashboard|availability|teamsheet|pitch automatically.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onAppear { tempURL = baseURL }
        }
    }
}

#Preview {
    SettingsView()
}
