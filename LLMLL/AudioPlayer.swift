import Foundation
import AVFoundation

class AudioPlayerManager {
    private var audioPlayer: AVAudioPlayer?
    var audioEngine = AVAudioEngine()
    var timePitch = AVAudioUnitTimePitch()
    var playerNode: AVAudioPlayerNode?
    
    init() {
        audioEngine.attach(timePitch)
    }
    
    func setupPlayerNode(for audioFile: AVAudioFile) {
        if self.playerNode == nil {
            let node = AVAudioPlayerNode()
            self.audioEngine.attach(node)
            self.audioEngine.connect(node, to: self.timePitch, format: audioFile.processingFormat)
            self.audioEngine.connect(self.timePitch, to: self.audioEngine.mainMixerNode, format: audioFile.processingFormat)
            self.playerNode = node
        }
    }
    
    func setRate(_ rate: Float) {
        self.timePitch.rate = rate
        self.timePitch.pitch = -300 * log2(rate)
    }
    
    func playAudio(audioPathURL: URL, rate: Float = 1.0) throws {
        let audioFile = try AVAudioFile(forReading: audioPathURL)
        Logger.shared.log("Attempting to setupPlayerNode.")
        setupPlayerNode(for: audioFile)
        Logger.shared.log("Successfully setupPlayerNode.")
        
        if let node = self.playerNode {
            node.scheduleFile(audioFile, at: nil, completionHandler: nil)
            if !self.audioEngine.isRunning {
                do {
                    Logger.shared.log("Attempting to start audio engine.")
                    try self.audioEngine.start()
                    Logger.shared.log("Successfully started audio engine.")
                    node.play()
                } catch {
                    print("Error starting the audio engine: \(error)")
                }
            } else {
                node.play()
            }
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
