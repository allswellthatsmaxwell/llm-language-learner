import AVFoundation
import Foundation

class AudioRecorder: NSObject, AVCaptureFileOutputRecordingDelegate {
    private var captureSession: AVCaptureSession?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var audioFileOutput: AVCaptureAudioFileOutput?
    var isRecording = false

    override init() {
        super.init()
        setupCaptureSession()
    }

    private func setupCaptureSession() {
        captureSession = AVCaptureSession()

        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            print("Audio device not found")
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
            print("Error setting up audio input: \(error)")
        }
    }

    public func toggleIsRecording() {
        isRecording.toggle()
        if isRecording {
            startRecording()
        } else {
            stopRecording()
        }
    }

    private func startRecording() {
        guard let captureSession = captureSession, !captureSession.isRunning,
              let audioFileOutput = audioFileOutput else { return }
        captureSession.startRunning()

        // Define the output URL for the audio file
        let outputURL = getDocumentsDirectory().appendingPathComponent("Recording-\(Date().timeIntervalSince1970).m4a")

        // Define the output file type
        let outputFileType = AVFileType.m4a

        // Start recording with specified file type
        audioFileOutput.startRecording(to: outputURL, outputFileType: outputFileType, recordingDelegate: self)
    }

    private func stopRecording() {
        guard let captureSession = captureSession, captureSession.isRunning else { return }
        captureSession.stopRunning()
        audioFileOutput?.stopRecording()
    }

    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    // AVCaptureFileOutputRecordingDelegate methods
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Recording error: \(error)")
        } else {
            print("Recording finished successfully. Saved to \(outputFileURL.path)")
        }
    }
}
