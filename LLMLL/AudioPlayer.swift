import Foundation
import AVFoundation

class AudioPlayerManager {
    private var audioPlayer: AVAudioPlayer?

    func playAudio(audioPathURL: URL, rate: Float = 1.0) throws {

        guard FileManager.default.fileExists(atPath: audioPathURL.path) else {
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorFileDoesNotExist, userInfo: [NSLocalizedDescriptionKey: "File does not exist at \(audioPathURL.path)"])
        }
        audioPlayer = try AVAudioPlayer(contentsOf: audioPathURL)
        audioPlayer?.enableRate = true
        audioPlayer?.rate = rate
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
        
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
