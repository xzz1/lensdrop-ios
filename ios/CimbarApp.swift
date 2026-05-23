import SwiftUI
import AVFoundation

@main
struct CimbarApp: App {
    private enum AppTab {
        case scan
        case settings
    }

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var session = CimbarSession()
    @State private var selectedTab: AppTab = .scan
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .english
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                ScanView()
                    .environmentObject(session)
                    .tabItem {
                        Label(language.text("tab.scan"), systemImage: "camera.fill")
                    }
                    .tag(AppTab.scan)

                SettingsView(languageCode: $languageCode)
                    .tabItem {
                        Label(language.text("tab.settings"), systemImage: "gearshape.fill")
                    }
                    .tag(AppTab.settings)
            }
            .environment(\.appLanguage, language)
            .environment(\.locale, language.locale)
            .onChange(of: selectedTab) { tab in
                if tab != .scan {
                    session.stopActiveScanning()
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase != .active {
                    session.stopActiveScanning()
                }
            }
        }
    }
}
