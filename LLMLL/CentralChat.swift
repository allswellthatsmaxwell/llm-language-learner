//
//  CentralChat.swift
//  LLMLL
//
//  Created by Maxwell Peterson on 11/18/23.
//

import Foundation
import SwiftUI
import SwiftData

struct ChatMessage: Identifiable {
    let id = UUID()
    var openAIMessage: OpenAIMessage
    var isUser: Bool // True for user messages, false for bot messages
    let content: String
    
    init(msg: OpenAIMessage) {
        self.openAIMessage = msg
        self.isUser = msg.isUser
        self.content = msg.content
    }
}

struct TranscriptionResult: Codable {
    var text: String
}

class ChatViewModel: ObservableObject {
    @Published var inputText: String = ""
    var audioRecorder = AudioRecorder()
    private var transcriptionAPI = TranscriptionAPI()
    
    init() {
        audioRecorder.onRecordingStopped { [weak self] audioURL in
            if let url = audioURL {
                self?.transcribeAudio(fileURL: url)
            } else {
                Logger.shared.log("AudioURL is nil")
            }
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
    private var chatAPI: ChatAPI = ChatAPI()
    
    var body: some View {
        VStack {
            // Messages List
            List(messages) { message in
                HStack {
                    if message.isUser {
                        Spacer() // Push user messages to the right
                    }
                    Text(message.openAIMessage.content)
                        .padding()
                        .background(message.isUser ? Color.blue : Color.gray)
                        .cornerRadius(10)
                    if !message.isUser {
                        Spacer() // Push bot messages to the left
                    }
                }
            }
            
            HStack {
                TextField("Type a message", text: $viewModel.inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button(action: viewModel.toggleRecording) {
                    Image(systemName: viewModel.audioRecorder.isRecording ? "mic.fill" : "mic")
                }
                
                .padding()
                
                Button("Send") {
                    Logger.shared.log("History so far: \(messages.map { $0.content })")
                    sendMessage { firstMessage in
                        if let message = firstMessage {
                            print("Received message: \(message.content)")
                            self.messages.append(ChatMessage(msg: OpenAIMessage(AIContent: message.content)))
                        } else { Logger.shared.log("No message received, or an error occurred") }
                    }
                }
                .padding()
            }
        }
    }
    
    private func sendMessage(completion: @escaping (OpenAIMessage?) -> Void) {
        let msg = OpenAIMessage(userContent: viewModel.inputText)
        let newMessage = ChatMessage(msg: msg)
        self.messages.append(newMessage)
        self.chatAPI.sendChat(messages: [msg]) { result in
            switch result {
            case .success(let data):
                do {
                    let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                    if let firstMessage = response.choices.first?.message {
                        Logger.shared.log("Message: \(firstMessage.content)")
                        return completion(firstMessage)
                    } else { Logger.shared.log("No messages found in response") }
                } catch { Logger.shared.log("Failed to decode response: \(error.localizedDescription)") }
                
            case .failure(let error): Logger.shared.log("Failed to get chat completion: \(error.localizedDescription)")
            }
        }
    }
}


struct CentralChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
    }
}
