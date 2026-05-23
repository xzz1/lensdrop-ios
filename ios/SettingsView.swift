import SwiftUI

struct SettingsView: View {

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let ver = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(ver) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("App Info") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                }

                Section("About") {
                    Text("LensDrop")
                        .font(.headline)
                    Text("Powered by libcimbar - Color Icon Matrix Barcodes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Optical data transfer through camera lens. No network required.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
