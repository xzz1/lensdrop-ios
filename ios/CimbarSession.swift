import SwiftUI
import Combine
@preconcurrency import CoreMedia
@preconcurrency import AVFoundation

// MARK: - Decode State

enum DecodeState: Equatable {
    case idle                        // camera off, waiting for user
    case scanning                    // camera on, looking for code
    case decoding(progress: Float, metrics: DecodeMetrics)
    case complete(fileName: String, fileSize: String, data: Data)
    case error(message: String)

    static func == (lhs: DecodeState, rhs: DecodeState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.scanning, .scanning): return true
        case (.decoding(let a, let b), .decoding(let x, let y)):
            return a == x && b == y
        case (.complete(let a, let b, _), .complete(let x, let y, _)):
            return a == x && b == y
        case (.error(let a), .error(let b)):
            return a == b
        default: return false
        }
    }
}

struct DecodeMetrics: Equatable {
    var processedFrames: Int = 0
    var extractedFrames: Int = 0
    var decodedFrames: Int = 0
    var decodedBytes: UInt64 = 0
    var averageFrameMilliseconds: Double = 0
    var lastFrameMilliseconds: Double = 0
    var activeFrames: Int = 0

    var decodedByteString: String {
        ByteCountFormatter.string(
            fromByteCount: Int64(min(decodedBytes, UInt64(Int64.max))),
            countStyle: .file
        )
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
    private let decodeQueue = DispatchQueue(label: "cimbar.decode", qos: .userInitiated, attributes: .concurrent)
    private var startTime: Date?
    private var sessionGeneration: UInt = 0
    private var inFlightFrames = 0
    private let maxInFlightFrames = min(max(ProcessInfo.processInfo.activeProcessorCount / 2, 1), 3)
    private var lastMetrics = DecodeMetrics()
    private var lastUIUpdate = Date.distantPast
    private let uiUpdateInterval: TimeInterval = 0.15

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
        decodeQueue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            self.bridge.reset()
        }
        state = .scanning
        framesExtracted = 0
        startTime = nil
        lastMetrics = DecodeMetrics()
        lastUIUpdate = .distantPast
    }

    func stopScanning() {
        sessionGeneration &+= 1
        state = .idle
        decodeQueue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            self.bridge.reset()
        }
        framesExtracted = 0
        startTime = nil
        lastMetrics = DecodeMetrics()
        lastUIUpdate = .distantPast
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
        guard inFlightFrames < maxInFlightFrames else { return }

        let generation = sessionGeneration
        let frame = PendingFrame(sampleBuffer: sampleBuffer)
        inFlightFrames += 1
        decodeQueue.async { [weak self] in
            guard let self else { return }

            let result = self.bridge.processFrame(frame.sampleBuffer)

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.inFlightFrames = max(0, self.inFlightFrames - 1)
                guard generation == self.sessionGeneration else { return }
                guard self.isActivelyScanning else { return }
                guard let result else { return }

                self.framesExtracted = Int(result.extractedFrames)

                if result.success, let data = result.fileData {
                    let name = result.fileName ?? "received.bin"
                    let size = ByteCountFormatter.string(
                        fromByteCount: Int64(data.count), countStyle: .file)
                    self.state = .complete(fileName: name, fileSize: size, data: data)
                } else {
                    if self.startTime == nil { self.startTime = Date() }
                    self.updateDecodingState(from: result)
                }
            }
        }
    }

    private func updateDecodingState(from result: CimbarDecodeResult) {
        let now = Date()
        let isFirstDecodingUpdate: Bool
        if case .scanning = state {
            isFirstDecodingUpdate = true
        } else {
            isFirstDecodingUpdate = false
        }
        let shouldPublish = now.timeIntervalSince(lastUIUpdate) >= uiUpdateInterval
            || result.progress >= 1.0
            || isFirstDecodingUpdate
            || result.decodedFrames != UInt64(lastMetrics.decodedFrames)

        lastMetrics = DecodeMetrics(
            processedFrames: Int(result.processedFrames),
            extractedFrames: Int(result.extractedFrames),
            decodedFrames: Int(result.decodedFrames),
            decodedBytes: result.decodedBytes,
            averageFrameMilliseconds: rollingAverage(
                previousAverage: lastMetrics.averageFrameMilliseconds,
                previousCount: max(lastMetrics.extractedFrames, 0),
                nextValue: result.frameMilliseconds
            ),
            lastFrameMilliseconds: result.frameMilliseconds,
            activeFrames: inFlightFrames
        )

        guard shouldPublish else { return }
        lastUIUpdate = now
        state = .decoding(progress: result.progress, metrics: lastMetrics)
    }

    private func rollingAverage(previousAverage: Double,
                                previousCount: Int,
                                nextValue: Double) -> Double {
        guard nextValue > 0 else { return previousAverage }
        guard previousCount > 0 else { return nextValue }
        return ((previousAverage * Double(previousCount)) + nextValue) / Double(previousCount + 1)
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
