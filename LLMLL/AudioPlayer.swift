import Foundation
import AVFoundation

class AudioPlayerManager {
    private var audioPlayer: AVAudioPlayer?

    func playAudio(audioPath: String) {
        let fileURL = getDocumentsDirectory().appendingPathComponent(audioPath)

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
}


func saveAudioFile(audioData: Data, audioPath: String) {
    let filename = getDocumentsDirectory().appendingPathComponent(audioPath)

    do {
        try audioData.write(to: filename, options: [.atomicWrite, .completeFileProtection])
        Logger.shared.log("Audio saved to \(filename.path)")
    } catch {
        Logger.shared.log("Failed to save audio: \(error)")
    }
}
