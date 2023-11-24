import AVFoundation
import Foundation

class AudioRecorder: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    private var captureSession: AVCaptureSession?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var audioFileOutput: AVCaptureAudioFileOutput?
    @Published var isRecording = false
    private var recordingStoppedCompletion: ((URL?) -> Void)?
    var savedAudioURL: URL?

    override init() {
        super.init()
        self.setupCaptureSession()
    }

    private func setupCaptureSession() {
        captureSession = AVCaptureSession()

        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            Logger.shared.log("Audio device not found")
            return
        }

        do {
            audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
            if let captureSession = captureSession, captureSession.canAddInput(audioDeviceInput!) {
                captureSession.addInput(audioDeviceInput!)
            }

            audioFileOutput = AVCaptureAudioFileOutput()
            if let captureSession = captureSession, captureSession.canAddOutput(audioFileOutput!) {
                captureSession.addOutput(audioFileOutput!)
            }
        } catch {
            Logger.shared.log("Error setting up audio input: \(error)")
        }
    }

    public func toggleIsRecording() {
        DispatchQueue.main.async {
            self.isRecording.toggle()
        }
        if self.isRecording {
            self.startRecording()
        } else {
            self.stopRecording()
        }
    }

    private func startRecording() {
        guard let captureSession = captureSession, !captureSession.isRunning,
              let audioFileOutput = self.audioFileOutput else { return }
        captureSession.startRunning()

        let audioURL = getDocumentsDirectory().appendingPathComponent("Recording-\(Date().timeIntervalSince1970).m4a")
        let outputFileType = AVFileType.m4a
        audioFileOutput.startRecording(to: audioURL, outputFileType: outputFileType, recordingDelegate: self)
        self.savedAudioURL = audioURL
    }
    
    func onRecordingStopped(completion: @escaping (URL?) -> Void) {
        self.recordingStoppedCompletion = completion
    }

    private func stopRecording() {
        guard let captureSession = captureSession, captureSession.isRunning else { return }
        captureSession.stopRunning()
        self.audioFileOutput?.stopRecording()
        self.recordingStoppedCompletion?(savedAudioURL)
    }

    // AVCaptureFileOutputRecordingDelegate methods
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            Logger.shared.log("Recording error: \(error)")
        } else {
            Logger.shared.log("Recording finished successfully. Saved to \(outputFileURL.path)")
        }
    }
}

