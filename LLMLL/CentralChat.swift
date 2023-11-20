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

struct CircleIconButton: View {
    let iconName: String
    let action: () -> Void
    let size: CGFloat

    init(iconName: String, action: @escaping () -> Void, size: CGFloat) {
        self.iconName = iconName
        self.action = action
        self.size = size
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundColor(.white)
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .padding()
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let action: () -> Void
    let iconSize: CGFloat
    let fontSize: CGFloat
    
    var body: some View {
        HStack {
            if self.message.isUser { Spacer() } // Right-align user messages
            
            Text(self.message.content)
                .padding()
                .background(self.message.isUser ? Color.blue : Color.gray)
                .cornerRadius(10)
                .font(.system(size: self.fontSize))
            
            if !self.message.isUser { Spacer() } // Left-align AI messages
            CircleIconButton(iconName: "speaker.circle",
                             action: self.action,
                             size: self.iconSize)
        }
    }
}

struct CustomTextEditor: View {
    @Binding var text: String
    var placeholder: String
    var fontSize: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.gray)
                    .padding(.leading, 4)
                    .padding(.top, 8)
            }
            TextEditor(text: $text)
                .frame(minHeight: fontSize, maxHeight: 40)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
        }
        .font(.system(size: fontSize))
    }
}

struct ChatView: View {
    @State private var messages: [ChatMessage] = []
    @StateObject private var viewModel = ChatViewModel()
    private var advisorChatAPI = AdvisorChatAPI()
    
    private let fontSize = CGFloat(18)
    private let listenButtonSize = CGFloat(30)
    private let entryButtonSize = CGFloat(55)
    
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
                MessageBubble(
                        message: message,
                        action: { viewModel.hearButtonTapped(for: message) },
                        iconSize: entryButtonSize,
                        fontSize: fontSize)
            }
            
            HStack {
                CustomTextEditor(text: $viewModel.inputText, placeholder: "Type your message here", fontSize: fontSize)
                
                CircleIconButton(iconName: viewModel.audioRecorder.isRecording ? "mic.circle.fill" : "mic.circle",
                                 action: viewModel.toggleRecording,
                                 size: entryButtonSize)
                
                CircleIconButton(iconName: "paperplane.circle.fill", action: sendMessage, size: entryButtonSize)
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
