import SwiftUI
import Combine
@preconcurrency import CoreMedia
@preconcurrency import AVFoundation

// MARK: - Decode State

enum DecodeState: Equatable {
    case idle                        // camera off, waiting for user
    case scanning                    // camera on, looking for code
    case decoding(progress: Float, receivedFrames: Int, totalExtracted: Int)
    case complete(fileName: String, fileSize: String, data: Data)
    case error(message: String)

    static func == (lhs: DecodeState, rhs: DecodeState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.scanning, .scanning): return true
        case (.decoding(let a, let b, let c), .decoding(let x, let y, let z)):
            return a == x && b == y && c == z
        case (.complete(let a, let b, _), .complete(let x, let y, _)):
            return a == x && b == y
        case (.error(let a), .error(let b)):
            return a == b
        default: return false
        }
    }
}

private struct PendingFrame: @unchecked Sendable {
    let sampleBuffer: CMSampleBuffer
}

// MARK: - CimbarSession

@MainActor
final class CimbarSession: ObservableObject {

    @Published var state: DecodeState = .idle
    @Published var framesExtracted: Int = 0

    nonisolated(unsafe) private let bridge: CimbarDecoderBridge
    private let decodeQueue = DispatchQueue(label: "cimbar.decode", qos: .userInitiated)
    private var framesReceived: Int = 0
    private var startTime: Date?
    private var sessionGeneration: UInt = 0
    private var isProcessing = false
    private var frameSkipCounter: UInt8 = 0

    nonisolated init() {
        bridge = CimbarDecoderBridge(
            expectedFileSize: 0,
            colorBits: 2,
            symbolBits: 4,
            dark: true,
            configMode: 68
        )
    }

    // MARK: - Camera Control

    func startScanning() {
        sessionGeneration &+= 1
        decodeQueue.async { [weak self] in
            guard let self else { return }
            self.bridge.reset()
        }
        state = .scanning
        framesExtracted = 0
        framesReceived = 0
        startTime = nil
    }

    func stopScanning() {
        sessionGeneration &+= 1
        state = .idle
        decodeQueue.async { [weak self] in
            guard let self else { return }
            self.bridge.reset()
        }
        framesExtracted = 0
        framesReceived = 0
        startTime = nil
    }

    func stopActiveScanning() {
        switch state {
        case .scanning, .decoding:
            stopScanning()
        case .idle, .complete, .error:
            break
        }
    }

    // MARK: - Frame Processing

    nonisolated func processFrame(_ sampleBuffer: CMSampleBuffer) {
        Task { @MainActor [weak self] in
            self?.enqueueFrame(sampleBuffer)
        }
    }

    private func enqueueFrame(_ sampleBuffer: CMSampleBuffer) {
        guard isActivelyScanning else { return }
        if isProcessing { return }
        frameSkipCounter ^= 1
        if frameSkipCounter == 0 { return }

        let generation = sessionGeneration
        let frame = PendingFrame(sampleBuffer: sampleBuffer)
        isProcessing = true
        decodeQueue.async { [weak self] in
            guard let self else { return }

            let result = self.bridge.processFrame(frame.sampleBuffer)

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isProcessing = false
                guard generation == self.sessionGeneration else { return }
                guard self.isActivelyScanning else { return }
                guard let result else { return }

                self.framesExtracted += 1

                if result.success, let data = result.fileData {
                    let name = result.fileName ?? "received.bin"
                    let size = ByteCountFormatter.string(
                        fromByteCount: Int64(data.count), countStyle: .file)
                    self.state = .complete(fileName: name, fileSize: size, data: data)
                } else {
                    if self.startTime == nil { self.startTime = Date() }
                    self.framesReceived += 1
                    self.state = .decoding(
                        progress: result.progress,
                        receivedFrames: self.framesReceived,
                        totalExtracted: self.framesExtracted
                    )
                }
            }
        }
    }

    private var isActivelyScanning: Bool {
        switch state {
        case .scanning, .decoding:
            return true
        case .idle, .complete, .error:
            return false
        }
    }

    func reset() {
        stopScanning()
    }
}
