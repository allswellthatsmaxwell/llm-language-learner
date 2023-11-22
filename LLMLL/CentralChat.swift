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


private let defaultChatTitle = "New chat"

struct TranscriptionResult: Codable {
    let text: String
}

struct ChatResult: Codable {
    let hangul: String
    let translation: String
    let comments: String
}

struct CircleIconButton: View {
    let iconName: String
    let action: () -> Void
    let size: CGFloat
    @State private var isHovering = false
    @Environment(\.colorScheme) var colorScheme
    
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
                .foregroundColor(isHovering ? (colorScheme == .dark ? Color.white : Color.black) : Color.gray)
        }
        .buttonStyle(PlainButtonStyle())
        .padding([.top, .bottom], 12)
        .padding([.leading, .trailing], 8)
        .onHover { hovering in isHovering = hovering }
    }
}

struct NewConversationButtonView: View {
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus.bubble")
                .font(.system(size: 56))
                .contentShape(Circle())
                .foregroundColor(isHovering ? (colorScheme == .dark ? Color.white : Color.black) : Color.gray)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity, alignment: .center)
        .padding([.top], 14)
        .onHover { hovering in isHovering = hovering }
        Divider()
            .background(Color.gray.opacity(0.15))
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let action: () -> Void
    let fontSize: CGFloat
    private let listenButtonSize = CGFloat(30)
    
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
                             size: self.listenButtonSize)
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
                .frame(minHeight: fontSize, maxHeight: 60)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
        }
        .font(.system(size: fontSize))
    }
}

struct ConversationsListView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(self.viewModel.conversations, id: \.id) { conversation in
                VStack(spacing: 0) {
                    Text(self.viewModel.titleStore.titles[conversation.id, default: defaultChatTitle])
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding([.leading, .trailing], 16)
                        .padding([.top, .bottom], 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            self.viewModel.activeConversation = conversation
                        }
                    Divider()
                        .background(Color.gray.opacity(0.15))
                }
                .background(self.isActiveConversation(conversation) ? Color.gray.brightness(-0.3) : Color.clear.brightness(0))

            }
        }
    }
    
    private func isActiveConversation(_ conversation: ChatConversation) -> Bool {
        return conversation.id == self.viewModel.activeConversation.id
    }
}

class ChatViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var conversations: [ChatConversation] = ChatConversation.loadAll()
    @Published var activeConversation = ChatConversation(messages: [])
    var audioRecorder = AudioRecorder()
    private var advisorChatAPI = AdvisorChatAPI()
    private let transcriptionAPI = TranscriptionAPI()
    private let textToSpeechAPI = TextToSpeechAPI()
    private let extractorChatAPI = ExtractorChatAPI()
    private var titlerChatAPI = TitlerChatAPI()
    private var audioPlayer: AVAudioPlayer?
    @Published var titleStore = TitleStore()
    
    init() {
        self.audioRecorder.onRecordingStopped { [weak self] audioURL in
            if let url = audioURL {
                self?.transcribeAudio(fileURL: url)
            } else {
                Logger.shared.log("AudioURL is nil")
            }
        }
        
        self.fetchTitlesForConversations()
    }
    
    func addNewConversation() {
        self.activeConversation = ChatConversation(messages: [])
        self.activeConversation.title = defaultChatTitle
        self.conversations.insert(self.activeConversation, at: 0)
    }
    
    func generateSingleTitle(conversation: ChatConversation) {
        generateTitle(conversation: conversation) { newTitle in
            DispatchQueue.main.async {
                self.titleStore.addTitle(chatId: conversation.id, title: newTitle)
            }
        }
    }
    
    func fetchTitlesForConversations() {
        self.conversations.forEach { conversation in generateSingleTitle(conversation: conversation) }
    }
    
    func generateTitle(conversation: ChatConversation, completion: @escaping (String) -> Void) {
        // use title if it exists
        if let title = self.titleStore.titles[conversation.id] {
            completion(title)
        } else {
            // otherwise, generate it
            self.titlerChatAPI.sendMessages(messages: conversation.messages.map( { $0.openAIMessage })) { createdTitle in
                DispatchQueue.main.async {
                    if let resultMessage = createdTitle {
                        self.titleStore.addTitle(chatId: conversation.id, title: resultMessage.content)
                        completion(resultMessage.content.trimmingCharacters(in: CharacterSet(charactersIn: "\"")))
                    } else {
                        Logger.shared.log("No title received, or an error occurred")
                        completion(defaultChatTitle)
                    }
                }
            }
        }
    }
    
    func hearButtonTapped(for message: ChatMessage) {
        let fileManager = FileManager.default
        let audioFilePath = getDocumentsDirectory().appendingPathComponent(message.audioFilename)
        
        if fileManager.fileExists(atPath: audioFilePath.path) {
            do {
                let audioData = try Data(contentsOf: audioFilePath)
                playAudio(from: audioData)
            } catch {
                Logger.shared.log("Error reading audio file: \(error)")
            }
        } else {
            Logger.shared.log("Audio file does not exist, extracting foreign text")
            self.extractorChatAPI.sendMessages(messages: [message.openAIMessage]) { firstMessage in
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
                            Logger.shared.log("Saved audio file to: \(audioFilePath)")
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
    
    func sendMessage() {
        Logger.shared.log("History so far: \(self.activeConversation.messages.map { $0.content })")
        let userMessage = ChatMessage(msg: OpenAIMessage(userContent: self.inputText))
        self.updateConversationWithNewMessage(userMessage)
        DispatchQueue.main.async { self.inputText = "" }
        
        let openAIMessages = self.activeConversation.messages.map { $0.openAIMessage }
        self.advisorChatAPI.sendMessages(messages: openAIMessages) { firstMessage in
            DispatchQueue.main.async {
                if let message = firstMessage {
                    Logger.shared.log("Received message: \(message.content)")
                    let newChatMessage = ChatMessage(msg: OpenAIMessage(AIContent: message.content))
                    self.updateConversationWithNewMessage(newChatMessage)
                    if self.activeConversation.isNew {
                        Logger.shared.log("Generating title.")
                        self.generateSingleTitle(conversation: self.activeConversation)
                        Logger.shared.log("sendMessage: Title generated: \(self.activeConversation.title)")
                    }
                    self.activeConversation.save()
                } else {
                    Logger.shared.log("No message received, or an error occurred")
                }
            }
        }
        self.inputText = ""
    }
    
    private func updateConversationWithNewMessage(_ message: ChatMessage) {
        // TODO: O(Conversations) update every time a message is sent.... not great. Required for current code because ChatConversation is a struct.
        if let index = conversations.firstIndex(where: { $0.id == activeConversation.id }) {
            conversations[index].append(message)
        }
        activeConversation.append(message)
        activeConversation.save()
    }
}

struct DividerLine: View {
    @Environment(\.colorScheme) var colorScheme
    var width: CGFloat? = nil
    var height: CGFloat? = nil

    var body: some View {
        let lineColor = colorScheme == .dark ? Color.white : Color.black

        Rectangle()
            .fill(lineColor)
            .frame(width: width, height: height)
            .padding(0)
    }
}

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    private let entryButtonSize = CGFloat(65)
    private let fontSize = CGFloat(18)
    
    var body: some View {
        HStack {
            ScrollView {
                VStack(alignment: .leading) {
                    NewConversationButtonView(action: self.viewModel.addNewConversation)
                    ConversationsListView(viewModel: self.viewModel)
                }
            }
            .frame(width: 200)
            
            DividerLine(width: 1)
            
            VStack {
                List(self.viewModel.activeConversation.messages) { message in
                    MessageBubble(
                        message: message,
                        action: { viewModel.hearButtonTapped(for: message) },
                        fontSize: self.fontSize)
                }
                
                DividerLine(height: 1)
                
                HStack {
                    CustomTextEditor(text: $viewModel.inputText, placeholder: "", fontSize: fontSize)
                    
                    CircleIconButton(iconName: viewModel.audioRecorder.isRecording ? "mic.circle.fill" : "mic.circle",
                                     action: viewModel.toggleRecording,
                                     size: entryButtonSize)
                    
                    CircleIconButton(iconName: "paperplane.circle.fill", action: self.viewModel.sendMessage, size: entryButtonSize)
                }
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
