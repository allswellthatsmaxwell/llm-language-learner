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
    
    @Published var audioRecorder = AudioRecorder()
    private var audioPlayer = AudioPlayerManager()
    
    private var advisorChatAPI = AdvisorChatAPI()
    private let transcriptionAPI = TranscriptionAPI()
    private let textToSpeechAPI = TextToSpeechAPI()
    private let extractorChatAPI = ExtractorChatAPI()
    private var titlerChatAPI = TitlerChatAPI()
    
    @Published var isLoading: Bool = false
    @Published var slowMode: Bool = false
    
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
    
    func toggleSlowMode() {
        self.slowMode.toggle()
        self.audioPlayer.setRate(slowMode: self.slowMode)
    }
    
    func processAndSynthesizeAudio(_ message: ChatMessage, audioFilePath: URL, toggleLoadingState: @escaping () -> Void) {
        toggleLoadingState() // turn on
        Logger.shared.log("processAndSynthesizeAudio: received message parameter '\(message.openAIMessage.content)'")
        self.extractorChatAPI.sendMessages(messages: [message.openAIMessage]) { firstMessage in
            // TODO: When sendMessages fails to return, that failure doesn't make it back here, so we never execute any
            // of the code in this block. So the loading-spinny on the "speak this text" button spins forever.
            // We need to propogate that error up here, and toggle the loading state in that case too.
            guard let extractedMessage = firstMessage else {
                toggleLoadingState() // turn off
                Logger.shared.log("extractor/speaker: No message received, or an error occurred")
                return
            }
            Logger.shared.log("processAndSynthesizeAudio: Extractor returned: \(extractedMessage.content)")
            self.textToSpeechAPI.synthesizeSpeech(from: extractedMessage.content) { result in
                switch result {
                case .success(let audioData):
                    do {
                        try audioData.write(to: audioFilePath)
                        Logger.shared.log("Saved audio file to: \(audioFilePath)")
                        try self.audioPlayer.playAudio(audioPathURL: audioFilePath)
                    } catch {
                        Logger.shared.log("Error saving or playing audio file: \(error)")
                    }
                    toggleLoadingState() // turn off
                case .failure(let error):
                    Logger.shared.log("Failed to synthesize speech: \(error)")
                    toggleLoadingState() // turn off
                }
            }
        }
    }
    
    func getAudioFile(_ message: ChatMessage) -> URL {
        return getDocumentsDirectory().appendingPathComponent(message.audioFilename)
    }
    
    func hearButtonTapped(for message: ChatMessage, completion: @escaping () -> Void) {
        let audioFilePath = self.getAudioFile(message)
        
        do {
            try self.audioPlayer.playAudio(audioPathURL: audioFilePath)
        } catch {
            Logger.shared.log("Couldn't read audio file: \(error). Extracting foreign text.")
            processAndSynthesizeAudio(message, audioFilePath: audioFilePath, toggleLoadingState: completion)
        }
    }
    
    private func transcribeAudio(fileURL: URL) {
        transcriptionAPI.transcribe(fileURL: fileURL) { [weak self] result in
            switch result {
            case .success(let transcriptData):
                do {
                    let transcriptionResult = try JSONDecoder().decode(TranscriptionResult.self, from: transcriptData)
                    DispatchQueue.main.async {
                        
                        self?.inputText += transcriptionResult.text
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
    
//    func sendMessage() {
//        guard !self.inputText.isEmpty else { return }
//        
//        let userMessage = ChatMessage(msg: OpenAIMessage(userContent: self.inputText))
//        let targetConversationId = self.activeConversationId
//        
//        if var targetConversation = self.conversations[targetConversationId] {
//            DispatchQueue.main.async { self.inputText = "" }
//            targetConversation.append(userMessage)
//            self.conversations[targetConversationId] = targetConversation
//            
//            let openAIMessages = targetConversation.messages.map { $0.openAIMessage }
//            Logger.shared.log("Sending messages: \(openAIMessages)")
//            self.advisorChatAPI.sendMessages(messages: openAIMessages) { firstMessage in
//                DispatchQueue.main.async {
//                    if let message = firstMessage {
//                        Logger.shared.log("Received message: \(message.content)")
//                        let aiChatMessage = ChatMessage(msg: OpenAIMessage(AIContent: message.content))
//                        targetConversation.append(aiChatMessage)
//                        self.conversations[targetConversationId] = targetConversation
//                        targetConversation.save()
//                        
//                        if targetConversation.title == defaultChatTitle && targetConversation.messages.count >= 2 {
//                            self.generateSingleTitle(conversation: targetConversation)
//                        }
//                        self.conversations[targetConversationId] = targetConversation
//                    } else {
//                        Logger.shared.log("No message received, or an error occurred")
//                    }
//                }
//            }
//        } else {
//            Logger.shared.log("Error in sendMessage: targetConversation is nil")
//        }
//    }
    
    func sendMessageWithStreamedResponse() {
        guard !self.inputText.isEmpty else { return }
        
        let userMessage = ChatMessage(msg: OpenAIMessage(userContent: self.inputText))
        let targetConversationId = self.activeConversationId

        if var targetConversation = self.conversations[targetConversationId] {
            DispatchQueue.main.async { self.inputText = "" }
            targetConversation.append(userMessage)
            self.conversations[targetConversationId] = targetConversation
            
            receiveStreamedResponse(&targetConversation, targetConversationId)
        }
    }
    
    private func receiveStreamedResponse(_ targetConversation: inout ChatConversation, _ targetConversationId: UUID) {
        
        let openAIMessages = targetConversation.messages.map { $0.openAIMessage }
        Logger.shared.log("Sending messages: \(openAIMessages)")
        
        let dispatchGroup = DispatchGroup()

        let emptyMessage = ChatMessage(msg: OpenAIMessage(AIContent: ""))
        targetConversation.append(emptyMessage)
        self.conversations[targetConversationId] = targetConversation
        self.advisorChatAPI.getChatCompletionResponse(
            messages: openAIMessages,
            chunkCompletion: { result in
                Logger.shared.log("Received result: \(result)")
                dispatchGroup.enter()
                DispatchQueue.main.async {
                    switch result {
                    case .success(let chatMessage):
                        let targetConversationId = self.activeConversationId
                        if var targetConversation = self.conversations[targetConversationId] {
                            self.updateResponseText(chatMessage, &targetConversation, targetConversationId)
                        }
                            // Logger.shared.log("Conversation updated!")
                    case .failure(let error):
                        Logger.shared.log("Streaming error: \(error.localizedDescription)")
                    }
                    dispatchGroup.leave()
                }
            },
            streamCompletion: {
                dispatchGroup.notify(queue: DispatchQueue.main) {
                    if let targetConversation = self.conversations[targetConversationId] {
                        if targetConversation.messages.count >= 2 {
                            Logger.shared.log("Saving conversation.")
                            DispatchQueue.main.async { targetConversation.save() }
                        }
                        Logger.shared.log("Title: \(targetConversation.title)")
                        if targetConversation.title == defaultChatTitle && targetConversation.messages.count >= 2 {
                            Logger.shared.log("Generating title")
                            DispatchQueue.main.async { self.generateSingleTitle(conversation: targetConversation) }
                            
                        }
                    }
                }
            })
    }
    
    
    func updateResponseText(_ chatMessage: ChatMessage, _ targetConversation: inout ChatConversation, _ targetConversationId: UUID) {
        if var lastMessage = targetConversation.messages.last {
            lastMessage = lastMessage.appendContent(chatMessage.content)
            targetConversation.messages[targetConversation.messages.count - 1] = lastMessage
            self.conversations[targetConversationId] = targetConversation
        } else {
            Logger.shared.log("updateResponseText: Failed to update message text in conversation.")
        }
    }
}

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    private let entryButtonSize = CGFloat(65)
    private let fontSize = CGFloat(18)
        
    var body: some View {
        HStack {
            ZStack (alignment: .topLeading) {
                ScrollView {
                    VStack {
                        NewConversationButtonView(action: { self.viewModel.addNewConversation() })
                            .keyboardShortcut("n", modifiers: .command)
                        ConversationsListView(viewModel: self.viewModel)
                    }
                }
                .frame(width: 200)
                
                SlowModeButtonView(viewModel: self.viewModel)
                    .keyboardShortcut("s", modifiers: .command)
            }
            
            DividerLine(width: 1)
            
            VStack {
                if let activeConversation = self.viewModel.conversations[self.viewModel.activeConversationId] {
                    List(activeConversation.messages) { message in
                        MessageBubble(
                            message: message,
                            action: { completion in
                                self.viewModel.hearButtonTapped(for: message, completion: completion)
                            },
                            fontSize: self.fontSize,
                            viewModel: self.viewModel)
                    }
                } else {
                    Text("Error: No active conversation")
                }
                
                DividerLine(height: 1)
                
                HStack {
                    CustomTextEditor(text: $viewModel.inputText, placeholder: "", fontSize: fontSize) {
                        viewModel.sendMessageWithStreamedResponse()
                    }
                    
                    AudioCircleIconButton(
                        audioRecorder: self.viewModel.audioRecorder,
                        action: {
                            viewModel.audioRecorder.toggleIsRecording()
                        },
                        size: entryButtonSize)
                    .keyboardShortcut("m", modifiers: .command)
                    
                    CircleIconButton(iconName: "paperplane.circle.fill", action: self.viewModel.sendMessageWithStreamedResponse, size: entryButtonSize)
                        .keyboardShortcut(.return, modifiers: .command)
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
