import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.appLanguage) private var language

    var body: some View {
        List {
            Text(language.text("privacy.introduction"))
                .font(.callout)

            policySection("privacy.collection.title", bodyKey: "privacy.collection.body")
            policySection("privacy.camera.title", bodyKey: "privacy.camera.body")
            policySection("privacy.files.title", bodyKey: "privacy.files.body")
            policySection("privacy.preferences.title", bodyKey: "privacy.preferences.body")
            policySection("privacy.external.title", bodyKey: "privacy.external.body")
            policySection("privacy.offlineSender.title", bodyKey: "privacy.offlineSender.body")
        }
        .navigationTitle(language.text("privacy.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func policySection(_ titleKey: String, bodyKey: String) -> some View {
        Section(language.text(titleKey)) {
            Text(language.text(bodyKey))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
            .environment(\.appLanguage, .english)
    }
}
