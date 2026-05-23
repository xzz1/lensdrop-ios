import SwiftUI

struct ScanView: View {
    @EnvironmentObject var session: CimbarSession

    private var blurredBg: Bool {
        switch session.state {
        case .idle, .complete: return true
        default: return false
        }
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            CameraPreview(session: session)
                .ignoresSafeArea()
                .scaleEffect(blurredBg ? 1.08 : 1)
                .compositingGroup()
                .blur(radius: blurredBg ? 20 : 0)
                .animation(.easeInOut(duration: 0.3), value: blurredBg)

            // Center overlay by state
            switch session.state {
            case .idle:
                IdleOverlay(onStart: { session.startScanning() })

            case .scanning:
                EmptyView()  // camera is live, user is aiming

            case .decoding(let progress, let received, let total):
                DecodingHUD(progress: progress,
                            receivedFrames: received,
                            totalExtracted: total)

            case .complete(let fileName, let fileSize, let data):
                CompleteSheet(fileName: fileName,
                              fileSize: fileSize,
                              data: data,
                              onReset: { session.startScanning() })

            case .error(let message):
                ErrorHUD(message: message) { session.reset() }
            }

            // Bottom toolbar — always visible
            VStack {
                Spacer()
                BottomBar(session: session)
            }
        }
    }
}

// MARK: - Bottom Bar

private struct BottomBar: View {
    @ObservedObject var session: CimbarSession
    @Environment(\.appLanguage) private var language

    var body: some View {
        HStack {
            Spacer()

            if case .decoding(let progress, _, _) = session.state, progress > 0 {
                VStack(spacing: 2) {
                    ProgressView(value: Double(progress))
                        .tint(.green)
                        .frame(width: 120)
                    Text(language.format("scan.percent", Int(progress * 100)))
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.green)
                }
            }

            Spacer()

            if case .idle = session.state {
                EmptyView()
            } else if case .complete = session.state {
                EmptyView()
            } else {
                Button(action: { session.stopScanning() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                        Text(language.text("scan.stop"))
                    }
                    .font(.caption.bold())
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
}

// MARK: - Idle Overlay

private struct IdleOverlay: View {
    let onStart: () -> Void
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.6))

            Text(language.text("scan.idle.instructions"))
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Button(action: onStart) {
                Label(language.text("scan.start"), systemImage: "play.fill")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 60)
        }
    }
}

// MARK: - Decoding HUD

private struct DecodingHUD: View {
    let progress: Float
    let receivedFrames: Int
    let totalExtracted: Int
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text(language.text("scan.decoding"))
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Text(language.format("scan.complete.percent", Int(progress * 100)))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white.opacity(0.7))
            }

            ProgressView(value: Double(progress))
                .tint(.green)
                .padding(.horizontal, 60)

            Text(language.format("scan.frame.progress", receivedFrames, totalExtracted))
                .font(.caption2.monospacedDigit())
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 40)
    }
}

// MARK: - Complete Sheet

private struct CompleteSheet: View {
    let fileName: String
    let fileSize: String
    let data: Data
    let onReset: () -> Void

    @State private var showSave = false
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text(language.text("scan.file.received"))
                .font(.title.bold())
                .foregroundColor(.white)

            VStack(spacing: 4) {
                Text(fileName)
                    .font(.body.monospaced().bold())
                Text(fileSize)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(spacing: 10) {
                Button(action: { showSave = true }) {
                    Label(language.text("scan.save"), systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: onReset) {
                    Label(language.text("scan.again"), systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white.opacity(0.7))
                .controlSize(.large)
            }
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 32)
        .sheet(isPresented: $showSave) {
            DocumentSaver(data: data, fileName: fileName)
        }
    }
}

// MARK: - Error HUD

private struct ErrorHUD: View {
    let message: String
    let onReset: () -> Void
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text(language.text("scan.error"))
                .font(.title3.bold())
                .foregroundColor(.white)
            Text(message)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            Button(language.text("scan.retry"), action: onReset)
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Document Saver (UIDocumentPicker, like Android's ACTION_CREATE_DOCUMENT)

private struct DocumentSaver: UIViewControllerRepresentable {
    let data: Data
    let fileName: String

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
        try? data.write(to: tmp, options: .atomic)
        context.coordinator.tempURL = tmp

        let picker = UIDocumentPickerViewController(forExporting: [tmp], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ ui: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var tempURL: URL?

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            // System copied the file — clean up temp
            if let tmp = tempURL { try? FileManager.default.removeItem(at: tmp) }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            if let tmp = tempURL { try? FileManager.default.removeItem(at: tmp) }
        }
    }
}
