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
    private let timestamp: Double
    var isNew: Bool
    private let fileURL: URL
    
    init(messages: [ChatMessage]) {
        self.id = UUID()
        self.messages = messages
        self.title = "New chat"
        self.timestamp = Date().timeIntervalSince1970
        self.isNew = true
        
        self.fileURL = getDocumentsDirectory().appendingPathComponent(generateUniqueFilename())
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.messages = try container.decode([ChatMessage].self, forKey: .messages)
        self.title = try container.decode(String.self, forKey: .title)
        self.timestamp = try container.decode(Double.self, forKey: .timestamp)
        self.isNew = false
        self.fileURL = try container.decode(URL.self, forKey: .fileURL)
    }
    
    mutating func append(_ message: ChatMessage) {
        self.messages.append(message)
    }
    
    func save() {
        do {
            let data = try JSONEncoder().encode(self)
            try data.write(to: self.fileURL)
        } catch {
            Logger.shared.log("Error saving chat: \(error)")
        }
    }
    
    static func loadAll() -> [ChatConversation] {
        let fileManager = FileManager.default
        let fileURLs = try! fileManager.contentsOfDirectory(at: fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0],
                                                            includingPropertiesForKeys: nil)
        var conversations = [ChatConversation]()
        for url in fileURLs {
            if url.lastPathComponent.hasSuffix("chatConversation.json") {
                do {
                    let data = try Data(contentsOf: url)
                    conversations.append(try JSONDecoder().decode(ChatConversation.self, from: data))
                } catch {
                    Logger.shared.log("Error loading conversation: \(error)")
                }
            }
        }
        Logger.shared.log("loadAll: loaded conversations: \(conversations)")
        return conversations
    }
}

func generateUniqueFilename() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyyMMddHHmmss"
    let timestamp = dateFormatter.string(from: Date())
    
    let uuid = UUID().uuidString
    
    return "conversation_\(timestamp)_\(uuid).\(conversationFileExtension)"
}


    
func generateTitle(messages: [ChatMessage], completion: @escaping (String) -> Void) {
    let TitlerChatAPI = TitlerChatAPI()
    let openAIMessages = messages.map { $0.openAIMessage }
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
