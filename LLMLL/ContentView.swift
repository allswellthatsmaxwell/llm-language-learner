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


struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    private var audioPlayerManager = AudioPlayerManager(audioPath: "savedAudio.mp3");
    private var audioRecorder = AudioRecorder()
    private var textToSpeechAPI: TextToSpeechAPI
    
    init() {
        self.textToSpeechAPI = TextToSpeechAPI()
    }
    
    var body: some View {
        VStack {
            Button("Play Audio") {
                audioPlayerManager.playAudio()
            }
            
            Button("Synthesize Speech") {
                self.textToSpeechAPI.synthesizeSpeech(from: "저는 친구들과 공원에 갔어요") {
                    result in
                    
                    switch result {
                    case .success(let audioData):
                        // Handle the received data, e.g., play audio or save to file
                        Logger.shared.log("Audio Data Received")
                        self.audioPlayerManager.saveAudioFile(audioData: audioData)
                    case .failure(let error):
                        // Handle any errors
                        Logger.shared.log("Error: \(error.localizedDescription)")
                    }
                }
            }
            
            Button(action: {
                audioRecorder.toggleIsRecording()
            }) {
                Text(audioRecorder.isRecording ? "Stop Recording" : "Start Recording")
                    .foregroundColor(.white)
                    .padding()
                    .background(audioRecorder.isRecording ? Color.red : Color.blue)
                    .cornerRadius(8)
            }
        }
    }
}


//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}
