//
//  CentralChat.swift
//  LLMLL
//
//  Created by Maxwell Peterson on 11/18/23.
//

import Foundation
import SwiftUI
import SwiftData
import AVFoundation

struct ChatMessage: Identifiable {
    let id = UUID()
    var openAIMessage: OpenAIMessage
    var isUser: Bool // True for user messages, false for bot messages
    let content: String
    let audioFilename: String
    
    init(msg: OpenAIMessage) {
        self.openAIMessage = msg
        self.isUser = msg.isUser
        self.content = msg.content
        self.audioFilename = "\(id).mp3"
    }
}

struct TranscriptionResult: Codable {
    let text: String
}

struct ChatResult: Codable {
    let hangul: String
    let translation: String
    let comments: String
}

class ChatViewModel: ObservableObject {
    @Published var inputText: String = ""
    var audioRecorder = AudioRecorder()
    private var transcriptionAPI = TranscriptionAPI()
    private var textToSpeechAPI = TextToSpeechAPI()
    private var extractorChatAPI = ExtractorChatAPI()
    private var audioPlayer: AVAudioPlayer?
    
    
    init() {
        audioRecorder.onRecordingStopped { [weak self] audioURL in
            if let url = audioURL {
                self?.transcribeAudio(fileURL: url)
            } else {
                Logger.shared.log("AudioURL is nil")
            }
        }
    }
    
    func hearButtonTapped(for message: ChatMessage) {
        let fileManager = FileManager.default
        let audioFilePath = self.documentsDirectory.appendingPathComponent(message.audioFilename)
        
        if fileManager.fileExists(atPath: audioFilePath.path) {
            do {
                let audioData = try Data(contentsOf: audioFilePath)
                playAudio(from: audioData)
            } catch {
                Logger.shared.log("Error reading audio file: \(error)")
            }
        } else {
            Logger.shared.log("Audio file does not exist, extracting foreign text")
            // extract foreign text from the message
            self.extractorChatAPI.sendMessages(messages: [message]) { firstMessage in
                guard let message = firstMessage else {
                    Logger.shared.log("extractor/speaker: No message received, or an error occurred")
                    return
                }
                Logger.shared.log("Received message: \(message.content)")
                // Synthesize speech and then play it
                self.textToSpeechAPI.synthesizeSpeech(from: message.content) { [weak self] result in
                    switch result {
                    case .success(let audioData):
                        do {
                            try audioData.write(to: audioFilePath)
                            self?.playAudio(from: audioData)
                        } catch {
                            Logger.shared.log("Error saving audio file: \(error)")
                        }
                    case .failure(let error):
                        Logger.shared.log("Failed to synthesize speech: \(error)")
                    }
                }
            }
        }
    }
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    
    private func playAudio(from data: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.play()
        } catch {
            Logger.shared.log("Failed to play audio: \(error)")
        }
    }
    
    func toggleRecording() {
        audioRecorder.toggleIsRecording()
    }
    
    private func transcribeAudio(fileURL: URL) {
        transcriptionAPI.transcribe(fileURL: fileURL) { [weak self] result in
            switch result {
            case .success(let transcriptData):
                do {
                    let transcriptionResult = try JSONDecoder().decode(TranscriptionResult.self, from: transcriptData)
                    DispatchQueue.main.async {
                        self?.inputText = transcriptionResult.text
                        Logger.shared.log("inputText set to transcript: " + transcriptionResult.text)
                    }
                    Logger.shared.log("Transcription Received")
                } catch {
                    Logger.shared.log("Failed to decode transcription result: \(error.localizedDescription)")
                }
            case .failure(let error):
                Logger.shared.log("Error: \(error.localizedDescription)")
            }
        }
    }
}

struct ChatView: View {
    @State private var messages: [ChatMessage] = []
    @StateObject private var viewModel = ChatViewModel()
    private var advisorChatAPI = AdvisorChatAPI()
    
    private let fontSize = CGFloat(18)
    private let entryButtonHeight = CGFloat(30)
    private let entryButtonWidth = CGFloat(30)
    
    private func sendMessage() {
        Logger.shared.log("History so far: \(self.messages.map { $0.content })")
        let userMessage = ChatMessage(msg: OpenAIMessage(userContent: viewModel.inputText))
        self.messages.append(userMessage)
        let allMessages = self.messages + [userMessage]
        DispatchQueue.main.async { self.viewModel.inputText = "" }
        
        self.advisorChatAPI.sendMessages(messages: allMessages) { firstMessage in
            DispatchQueue.main.async {
                if let message = firstMessage {
                    Logger.shared.log("Received message: \(message.content)")
                    self.messages.append(ChatMessage(msg: OpenAIMessage(AIContent: message.content)))
                } else {
                    Logger.shared.log("No message received, or an error occurred")
                }
            }
        }
        self.viewModel.inputText = ""
    }
    
    var body: some View {
        VStack {
            List(messages) { message in
                HStack {
                    if message.isUser {
                        Spacer() // Right-align user messages
                        Text(message.content)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                            .font(.system(size: fontSize))
                        Button(action: {
                            viewModel.hearButtonTapped(for: message)
                        }) {
                            Image(systemName: "speaker.fill")
                        }
                    } else {
                        // AI message with a hear button
                        Text(message.content)
                            .padding()
                            .background(Color.gray)
                            .cornerRadius(10)
                            .font(.system(size: fontSize))
                        
                        Button(action: {
                            viewModel.hearButtonTapped(for: message)
                        }) {
                            Image(systemName: "speaker.fill")
                        }
                        .padding()
                        
                        Spacer() // Left-align AI messages
                    }
                }
            }
            
            HStack {
                ZStack(alignment: .topLeading) {
                    if viewModel.inputText.isEmpty {
                        Text("Placeholder") // Placeholder text
                            .foregroundColor(.gray)
                            .padding(.leading, 4)
                            .padding(.top, 8)
                    }
                    TextEditor(text: $viewModel.inputText)
                        .frame(minHeight: fontSize, maxHeight: 40)
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }
                .font(.system(size: fontSize))
                
                
                Button(action: viewModel.toggleRecording) {
                    Image(systemName: viewModel.audioRecorder.isRecording ? "mic.fill" : "mic")
                        .resizable()
                        .scaledToFit()
                        .frame(width: entryButtonWidth, height: entryButtonHeight)
                        .padding() // Add padding to create a larger clickable area
                        // .background(viewModel.audioRecorder.isRecording ? Color.red : Color.blue) // Optional: Change color when recording
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                }
                .buttonStyle(PlainButtonStyle())
                
                .padding()
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: entryButtonWidth, height: entryButtonHeight)
                        .padding() // Add padding to create a larger clickable area
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                }
                .buttonStyle(PlainButtonStyle())
                
                .padding()
            }
        }
    }
}

//
// struct CentralChatView_Previews: PreviewProvider {
//     static var previews: some View {
//         ChatView()
//     }
// }
