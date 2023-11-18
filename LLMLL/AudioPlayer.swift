import Foundation
import AVFoundation

class AudioPlayerManager {
    private var audioPlayer: AVAudioPlayer?
    private var audioPath: String

    init(audioPath: String) {
        self.audioPath = audioPath
    }

    func playAudio() {
        let fileURL = getDocumentsDirectory().appendingPathComponent(self.audioPath)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            Logger.shared.log("Audio file does not exist")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            Logger.shared.log("Failed to play audio: \(error)")
        }
    }

    func saveAudioFile(audioData: Data) {
        let filename = getDocumentsDirectory().appendingPathComponent(self.audioPath)

        do {
            try audioData.write(to: filename, options: [.atomicWrite, .completeFileProtection])
            Logger.shared.log("Audio saved to \(filename.path)")
        } catch {
            Logger.shared.log("Failed to save audio: \(error)")
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
