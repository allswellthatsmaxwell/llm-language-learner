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
    
    var audioRecorder = AudioRecorder()
    private var audioPlayerManager = AudioPlayerManager()
    private var textToSpeechAPI = TextToSpeechAPI()
    private var transcriptionAPI = TranscriptionAPI()
    private var chatAPI: ChatAPI = ChatAPI()
    
    
    var body: some View {
        VStack {
            Button("Play Audio") {
                audioPlayerManager.playAudio(audioPath: "savedAudio.mp3")
            }
            
            Button("Synthesize Speech") {
                self.textToSpeechAPI.synthesizeSpeech(from: "저는 친구들과 공원에 갔어요") {
                    result in
                    
                    switch result {
                    case .success(let audioData):
                        Logger.shared.log("Audio Data Received")
                        saveAudioFile(audioData: audioData, audioPath: "savedAudio.mp3")
                    case .failure(let error):
                        Logger.shared.log("Error: \(error.localizedDescription)")
                    }
                }
            }
            
            Button("Transcribe") {
                if let audioURL = self.audioRecorder.savedAudioURL {
                    self.transcriptionAPI.transcribe(fileURL: audioURL) {
                        result in switch result {
                        case .success(let transcriptData):
                            if let transcriptString = String(data: transcriptData, encoding: .utf8) {
                                Logger.shared.log("Transcription Received")
                                Logger.shared.log(transcriptString)
                            } else {
                                Logger.shared.log("Failed to convert transcript data to string")
                            }
                        case .failure(let error):
                            // Handle any errors
                            Logger.shared.log("Error: \(error.localizedDescription)")
                        }
                    }
                } else {
                    Logger.shared.log("AudioURL is nil")
                }
            }
            
            Button("Send Chat Message") {
                self.chatAPI.sendChat(messages: [OpenAIMessage(userContent: "hi")]) {
                    result in switch result {
                        case .success(let completion):
                        if let completionString = String(data: completion, encoding: .utf8) {
                            Logger.shared.log(completionString)
                        } else {
                            Logger.shared.log("Failed to convert chat completion data to string")
                        }
                        
                    case .failure(let error):
                        Logger.shared.log("Failed to get chat completion: \(error.localizedDescription)")
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
