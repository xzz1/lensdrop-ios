import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {

    @ObservedObject var session: CimbarSession

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        let isScanning: Bool = {
            switch session.state {
            case .idle, .complete: return false
            default: return true
            }
        }()
        if isScanning {
            context.coordinator.startIfNeeded()
        } else {
            context.coordinator.stop()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        let session: CimbarSession
        private let captureSession = AVCaptureSession()
        private var isRunning = false
        private var device: AVCaptureDevice?

        init(session: CimbarSession) {
            self.session = session
            super.init()
            setupCapture()
        }

        private func setupCapture() {
            captureSession.beginConfiguration()

            guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                     for: .video, position: .back)
            else {
                captureSession.commitConfiguration()
                return
            }
            self.device = dev

            try? dev.lockForConfiguration()
            if dev.isFocusModeSupported(.continuousAutoFocus) {
                dev.focusMode = .continuousAutoFocus
            }
            if dev.isExposureModeSupported(.continuousAutoExposure) {
                dev.exposureMode = .continuousAutoExposure
            }
            dev.unlockForConfiguration()

            guard let input = try? AVCaptureDeviceInput(device: dev),
                  captureSession.canAddInput(input)
            else {
                captureSession.commitConfiguration()
                return
            }
            captureSession.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "cimbar.camera",
                                                                       qos: .userInitiated))
            guard captureSession.canAddOutput(output) else {
                captureSession.commitConfiguration()
                return
            }
            captureSession.addOutput(output)

            if captureSession.canSetSessionPreset(.hd1280x720) {
                captureSession.sessionPreset = .hd1280x720
            } else if captureSession.canSetSessionPreset(.hd1920x1080) {
                captureSession.sessionPreset = .hd1920x1080
            }

            captureSession.commitConfiguration()
        }

        func startIfNeeded() {
            guard !isRunning else { return }
            isRunning = true
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }

        func stop() {
            guard isRunning else { return }
            isRunning = false
            captureSession.stopRunning()
        }

        // MARK: Tap to Focus

        func focus(at point: CGPoint, in view: UIView) {
            guard let device = self.device else { return }
            try? device.lockForConfiguration()

            let focusPoint = CGPoint(x: point.y / view.bounds.height,
                                     y: 1.0 - point.x / view.bounds.width)
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = focusPoint
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = focusPoint
                device.exposureMode = .autoExpose
            }

            device.unlockForConfiguration()
        }

        // MARK: Delegate

        func captureOutput(_ output: AVCaptureOutput,
                           didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection) {
            session.processFrame(sampleBuffer)
        }

        // MARK: Preview Layer

        func setPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
            layer.session = captureSession
            layer.videoGravity = .resizeAspectFill
        }
    }
}

// MARK: - CameraPreviewView

final class CameraPreviewView: UIView {

    var delegate: CameraPreview.Coordinator?
    private var focusBox: UIView?

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let coordinator = delegate else { return }
        coordinator.setPreviewLayer(previewLayer)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        delegate?.focus(at: point, in: self)
        showFocusBox(at: point)
    }

    private func showFocusBox(at point: CGPoint) {
        focusBox?.removeFromSuperview()
        let size: CGFloat = 80
        let box = UIView(frame: CGRect(x: point.x - size/2, y: point.y - size/2,
                                        width: size, height: size))
        box.layer.borderColor = UIColor.systemYellow.cgColor
        box.layer.borderWidth = 2
        box.alpha = 1
        addSubview(box)
        focusBox = box

        UIView.animate(withDuration: 0.3, delay: 0.6, options: .curveEaseOut) {
            box.alpha = 0
        } completion: { _ in
            box.removeFromSuperview()
        }
    }
}
