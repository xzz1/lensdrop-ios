import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Binding var languageCode: String
    @Environment(\.appLanguage) private var language
    @State private var showSenderExporter = false
    @State private var senderDocument: SenderHTMLDocument?
    @State private var resourceErrorKey: String?

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let ver = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(ver) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section(language.text("settings.language")) {
                    Picker(language.text("settings.language.selection"), selection: $languageCode) {
                        Text("English")
                            .tag(AppLanguage.english.rawValue)
                        Text("简体中文")
                            .tag(AppLanguage.simplifiedChinese.rawValue)
                    }
                    .pickerStyle(.menu)
                }

                Section(language.text("settings.sender")) {
                    Text(language.text("settings.sender.description"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button {
                        exportOfflineSender()
                    } label: {
                        Label(language.text("settings.sender.export"), systemImage: "square.and.arrow.up")
                    }

                    Link(destination: URL(string: "https://github.com/sz3/libcimbar/releases/latest/download/cimbar_js.html")!) {
                        Label(language.text("settings.sender.latest"), systemImage: "arrow.down.circle")
                    }

                    Text(language.text("settings.sender.bundled"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Section(language.text("settings.about")) {
                    Text("LensDrop")
                        .font(.headline)
                    Text(language.text("settings.about.summary"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Text(language.text("settings.about.version"))
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    Text(language.text("settings.about.license"))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label(language.text("privacy.title"), systemImage: "hand.raised")
                    }
                }
            }
            .navigationTitle(language.text("settings.title"))
        }
        .fileExporter(
            isPresented: $showSenderExporter,
            document: senderDocument,
            contentType: .html,
            defaultFilename: "cimbar_js"
        ) { _ in }
        .alert(language.text("settings.sender.unavailable"), isPresented: Binding(
            get: { resourceErrorKey != nil },
            set: { if !$0 { resourceErrorKey = nil } }
        )) {
            Button(language.text("common.ok"), role: .cancel) {}
        } message: {
            Text(resourceErrorKey.map(language.text) ?? "")
        }
    }

    private func exportOfflineSender() {
        guard let url = Bundle.main.url(forResource: "cimbar_js", withExtension: "html") else {
            resourceErrorKey = "settings.sender.notFound"
            return
        }

        do {
            senderDocument = SenderHTMLDocument(data: try Data(contentsOf: url))
            showSenderExporter = true
        } catch {
            resourceErrorKey = "settings.sender.loadFailed"
        }
    }
}

private struct SenderHTMLDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.html] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    SettingsView(languageCode: .constant(AppLanguage.english.rawValue))
        .environment(\.appLanguage, .english)
}
