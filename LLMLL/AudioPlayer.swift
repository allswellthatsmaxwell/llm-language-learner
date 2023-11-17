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
            print("Audio file does not exist")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.prepareToPlay() // Prepare the player for playback
            audioPlayer?.play()
        } catch {
            print("Failed to play audio: \(error)")
        }
    }

    func saveAudioFile(audioData: Data) {
        let filename = getDocumentsDirectory().appendingPathComponent(self.audioPath)

        do {
            try audioData.write(to: filename, options: [.atomicWrite, .completeFileProtection])
            print("Audio saved to \(filename.path)")
        } catch {
            print("Failed to save audio: \(error)")
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
