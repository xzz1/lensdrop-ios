import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    static let storageKey = "appLanguage"

    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    func text(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }

    private var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue = AppLanguage.english
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}
