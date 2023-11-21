//
//  ChatConversation.swift
//  LLMLL
//
//  Created by Maxwell Peterson on 11/21/23.
//

import Foundation

private let conversationFileExtension = "chatConversation.json"


struct ChatConversation: Codable, Identifiable {
    let id: UUID
    var messages: [ChatMessage]
    var title: String
    var timestamp: Double
    var isNew: Bool
    
    init(messages: [ChatMessage]) {
        self.id = UUID()
        self.messages = messages
        self.title = "Title \(id)"
        self.timestamp = Date().timeIntervalSince1970
        self.isNew = true
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.messages = try container.decode([ChatMessage].self, forKey: .messages)
        self.title = try container.decode(String.self, forKey: .title)
        self.timestamp = try container.decode(Double.self, forKey: .timestamp)
        self.isNew = false
    }
    
    private var fileURL: URL {
        return getDocumentsDirectory().appendingPathComponent("\(self.timestamp).\(conversationFileExtension)")
    }
    
    mutating func append(_ message: ChatMessage) {
        self.messages.append(message)
    }
    
    func save() {
        do {
            if self.isNew {
                // ?
            }
            let data = try JSONEncoder().encode(self)
            try data.write(to: self.fileURL)
        } catch {
            Logger.shared.log("Error saving chat: \(error)")
        }
    }
    
    func generateTitle(completion: @escaping (String) -> Void) {
        let TitlerChatAPI = TitlerChatAPI()
        let openAIMessages = self.messages.map { $0.openAIMessage }
        TitlerChatAPI.sendMessages(messages: openAIMessages) { result in
            if let result = result {
                Logger.shared.log("generateTitle: \(result.content)")
                completion(result.content)
            } else {
                Logger.shared.log("Titler: No message received, or an error occurred")
                completion("New chat")
            }
        }
    }
    
    static func loadAll() -> [ChatConversation] {
        let fileManager = FileManager.default
        let fileURLs = try! fileManager.contentsOfDirectory(at: fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0],
                                                            includingPropertiesForKeys: nil)
        var conversations = [ChatConversation]()
        for fileURL in fileURLs {
            if fileURL.lastPathComponent.hasSuffix("chatConversation.json") {
                do {
                    let data = try Data(contentsOf: fileURL)
                    conversations.append(try JSONDecoder().decode(ChatConversation.self, from: data))
                } catch {
                    Logger.shared.log("Error loading conversation: \(error)")
                }
            }
        }
        Logger.shared.log("loadAll: loaded conversations: \(conversations)")
        return conversations
    }
    
    func generateUniqueFilename() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let timestamp = dateFormatter.string(from: Date())
        
        let uuid = UUID().uuidString
        
        return "conversation_\(timestamp)_\(uuid).\(conversationFileExtension)"
    }
}


func setMetadata(conversation: ChatConversation, completion: @escaping (ChatConversation) -> Void) {
    conversation.generateTitle() { newTitle in
        var updatedConversation = conversation
        updatedConversation.title = newTitle
        completion(updatedConversation)
        updatedConversation.timestamp = Date().timeIntervalSince1970
    }
}
