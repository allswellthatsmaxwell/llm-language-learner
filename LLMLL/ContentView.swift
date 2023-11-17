//
//  ContentView.swift
//  LLMLL
//
//  Created by Maxwell Peterson on 11/16/23.
//

import SwiftUI
import SwiftData
import AVFoundation


struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var audioPlayer: AVAudioPlayer?
    
    private var textToSpeechAPI: TextToSpeechAPI
    
    init() {
        textToSpeechAPI = TextToSpeechAPI(apiKey: "OPENAI_API_KEY")
    }
    
    private func playAudio() {
        let fileURL = getDocumentsDirectory().appendingPathComponent("savedAudio.mp3")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("Audio file does not exist")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.play()
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
    
    var body: some View {
        VStack {
            Button("Play Audio") {
                playAudio()
            }
            
            
            Button("Synthesize Speech") {
                textToSpeechAPI.synthesizeSpeech(from: "The quick brown fox jumped over the lazy dog.") {
                    result in
                    
                    switch result {
                    case .success(_):
                        // Handle the received data, e.g., play audio or save to file
                        print("Audio Data Received")
                        saveAudioFile(audioData: <#T##Data#>)
                    case .failure(let error):
                        // Handle any errors
                        print("Error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

    
func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}

func saveAudioFile(audioData: Data) {
    let filename = getDocumentsDirectory().appendingPathComponent("savedAudio.mp3")

    do {
        try audioData.write(to: filename, options: [.atomicWrite, .completeFileProtection])
        print("Audio saved to \(filename.path)")
    } catch {
        print("Failed to save audio: \(error)")
    }
}
