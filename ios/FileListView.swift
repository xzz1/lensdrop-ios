import SwiftUI

/// List view showing previously received files.
/// (Stub for future implementation — currently a placeholder.)
struct FileListView: View {
    var body: some View {
        NavigationStack {
            List {
                Text("No files received yet")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Received Files")
        }
    }
}

#Preview {
    FileListView()
}
