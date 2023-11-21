//
//  ChatConversation.swift
//  LLMLL
//
//  Created by Maxwell Peterson on 11/21/23.
//

import Foundation


struct ChatConversation: Codable, Identifiable {
    let id: UUID
    var messages: [ChatMessage]
    var title: String
    var timestamp: Double // 11/21 9am: if I make these two variables ? then it conforms to Decodable..?
    // we should use timestamp as the ID somehow, instead of the UUID, but need it to be int or str then, not double.
    var isNew: Bool
    
    init(messages: [ChatMessage]) {
        #if DEBUG
        let id = getPersistentUUID(key: "700-of-770")
        #else
        let id = UUID()
        #endif
        self.id = id
        self.messages = messages
        self.title = "Title \(id)"
        self.timestamp = Date().timeIntervalSince1970
        self.isNew = true
    }
    
    private var fileURL: URL {
        return getDocumentsDirectory().appendingPathComponent("\(self.timestamp).chatConversation.json")
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
    
    static func load(from chatId: UUID) -> ChatConversation? {
        let fileManager = FileManager.default
        let fileURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("\(chatId).chatConversation.json")
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(ChatConversation.self, from: data)
        } catch {
            Logger.shared.log("Error loading chat: \(error)")
            return nil
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
    
    private enum CodingKeys: String, CodingKey {
        case id, messages, title
    }
}


func getPersistentUUID(key: String) -> UUID {
    if let uuidString = UserDefaults.standard.string(forKey: key),
       let uuid = UUID(uuidString: uuidString) {
        Logger.shared.log("getPersistentUUID branch 1: UUID: \(uuid)")
        return uuid
    } else {
        let uuid = UUID()
        UserDefaults.standard.set(uuid.uuidString, forKey: key)
        Logger.shared.log("getPersistentUUID branch 2: UUID: \(uuid)")
        return uuid
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
