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
    @Published var conversations: [UUID:ChatConversation] = ChatConversation.loadAll()
    @Published var conversationOrder: [UUID] = []
    
    @Published var activeConversationId: UUID
    @Published var titleStore = TitleStore()
    
    var audioRecorder = AudioRecorder()
    private var audioPlayer: AVAudioPlayer?
    
    private var advisorChatAPI = AdvisorChatAPI()
    private let transcriptionAPI = TranscriptionAPI()
    private let textToSpeechAPI = TextToSpeechAPI()
    private let extractorChatAPI = ExtractorChatAPI()
    private var titlerChatAPI = TitlerChatAPI()
    
    init() {
        let activeConversation = ChatConversation(messages: [])
        self.activeConversationId = activeConversation.id
        self.conversations[activeConversationId] = activeConversation
        
        let sortedConversations = self.conversations.sorted(by: { $0.value.timestamp > $1.value.timestamp })
        self.conversationOrder = sortedConversations.map { $0.key }
        
        self.audioRecorder.onRecordingStopped { [weak self] audioURL in
            if let url = audioURL {
                self?.transcribeAudio(fileURL: url)
            } else {
                Logger.shared.log("AudioURL is nil")
            }
        }
        generateAnyMissingConversationTitles()
    }
    
    func generateAnyMissingConversationTitles() {
        self.conversationOrder.forEach { conversationId in
            if let conversation = self.conversations[conversationId] {
                if conversation.messages.count >= 2 {
                    generateSingleTitle(conversation: conversation)
                }
            }
        }
    }
    
    private func alreadyAddedBlankConversation() -> Bool {
        guard let mostRecentConversationId = self.conversationOrder.first,
              let mostRecentConversation = self.conversations[mostRecentConversationId] else {
            return false
        }
        return mostRecentConversation.messages.isEmpty
    }
    
    func addNewConversation() {
        if let mostRecentConversationId = self.conversationOrder.first,
           let mostRecentConversation = self.conversations[mostRecentConversationId],
           mostRecentConversation.messages.isEmpty {
            // if there's already an empty conversation ready for the user, just set their selected conversation to that
            self.activeConversationId = mostRecentConversationId
        } else {
            // otherwise, make a new one for them
            var newConversation = ChatConversation(messages: [])
            newConversation.title = defaultChatTitle
            self.activeConversationId = newConversation.id
            newConversation.isNew = false // 11/22: there was a good reason we needed to do this... I just don't remember what it was
            self.conversations[newConversation.id] = newConversation
            self.conversationOrder.insert(newConversation.id, at: 0)
        }
    }
    
    
    func generateSingleTitle(conversation: ChatConversation) {
        generateTitle(conversation: conversation) { newTitle in
            DispatchQueue.main.async {
                self.titleStore.addTitle(chatId: conversation.id, title: newTitle)
            }
        }
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
        guard !self.inputText.isEmpty else { return }
        
        let userMessage = ChatMessage(msg: OpenAIMessage(userContent: self.inputText))
        let targetConversationId = self.activeConversationId
        
        if var targetConversation = self.conversations[targetConversationId] {
            DispatchQueue.main.async { self.inputText = "" }
            targetConversation.append(userMessage)
            self.conversations[targetConversationId] = targetConversation
            
            let openAIMessages = targetConversation.messages.map { $0.openAIMessage }
            Logger.shared.log("Sending messages: \(openAIMessages)")
            self.advisorChatAPI.sendMessages(messages: openAIMessages) { firstMessage in
                DispatchQueue.main.async {
                    if let message = firstMessage {
                        Logger.shared.log("Received message: \(message.content)")
                        let AIChatMessage = ChatMessage(msg: OpenAIMessage(AIContent: message.content))
                        targetConversation.append(AIChatMessage)
                        self.conversations[targetConversationId] = targetConversation
                        targetConversation.save()
                        
                        if targetConversation.title == defaultChatTitle && targetConversation.messages.count >= 2 {
                            self.generateSingleTitle(conversation: targetConversation)
                        }
                        self.conversations[targetConversationId] = targetConversation
                    } else {
                        Logger.shared.log("No message received, or an error occurred")
                    }
                }
            }
        } else {
            Logger.shared.log("Error in sendMessage: targetConversation is nil")
        }
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
                    NewConversationButtonView(action: { self.viewModel.addNewConversation() })
                    ConversationsListView(viewModel: self.viewModel)
                }
            }
            .frame(width: 200)
            
            DividerLine(width: 1)
            
            VStack {
                if let activeConversation = self.viewModel.conversations[self.viewModel.activeConversationId] {
                    List(activeConversation.messages) { message in
                        MessageBubble(
                            message: message,
                            action: { viewModel.hearButtonTapped(for: message) },
                            fontSize: self.fontSize)
                    }
                } else {
                    Text("Error: No active conversation")
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