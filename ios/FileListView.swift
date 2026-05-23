import SwiftUI

/// List view showing previously received files.
/// (Stub for future implementation — currently a placeholder.)
struct FileListView: View {
    @Environment(\.appLanguage) private var language

    var body: some View {
        NavigationStack {
            List {
                Text(language.text("files.empty"))
                    .foregroundColor(.secondary)
            }
            .navigationTitle(language.text("files.title"))
        }
    }
}

#Preview {
    FileListView()
}
