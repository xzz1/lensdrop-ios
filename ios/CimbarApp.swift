import SwiftUI
import AVFoundation

@main
struct CimbarApp: App {
    @StateObject private var session = CimbarSession()

    var body: some Scene {
        WindowGroup {
            TabView {
                ScanView()
                    .environmentObject(session)
                    .tabItem {
                        Label("Scan", systemImage: "camera.fill")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
            }
        }
    }
}
