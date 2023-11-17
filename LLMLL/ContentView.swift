//
//  ContentView.swift
//  LLMLL
//
//  Created by Maxwell Peterson on 11/16/23.
//

import SwiftUI
import SwiftData
import AVFoundation


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

func readApiKey() -> String? {
    if let path = Bundle.main.path(forResource: "keys", ofType: "plist"),
       let config = NSDictionary(contentsOfFile: path) as? [String: Any] {
        let apiKey = config["OPENAI_API_KEY"] as? String
        return apiKey
    }
    return nil
}


struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var audioPlayer: AVAudioPlayer?
    
    private var textToSpeechAPI: TextToSpeechAPI
    
    init() {
        var apiKey: String?
        if let apiKeyLocal = readApiKey() {
            // Use apiKey safely here
            print("API Key: \(apiKeyLocal)")
            apiKey = apiKeyLocal
        } else {
            print("Failed to find OPENAI_API_KEY")
        }
        textToSpeechAPI = TextToSpeechAPI(apiKey: apiKey ?? "MissingAPIKey")

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
                textToSpeechAPI.synthesizeSpeech(from: "저는 친구들과 공원에 갔어요") {
                    result in
                    
                    switch result {
                    case .success(let audioData):
                        // Handle the received data, e.g., play audio or save to file
                        print("Audio Data Received")
                        saveAudioFile(audioData: audioData)
                    case .failure(let error):
                        // Handle any errors
                        print("Error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
        // .environment(\.modelContext, YourModelContextHere)
        // Use this if you need to inject any specific environment objects
    }
}
