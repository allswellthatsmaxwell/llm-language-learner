//
//  ChatMessage.swift
//  LLMLL
//
//  Created by Maxwell Peterson on 11/20/23.
//

import Foundation


struct ChatMessage: Identifiable, Codable {
    let id: UUID
    var openAIMessage: OpenAIMessage
    var isUser: Bool // True for user messages, false for AI messages
    let content: String
    let audioFilename: String
    
    enum CodingKeys: CodingKey {
        case id, openAIMessage, isUser, content, audioFilename
    }
    
    init(msg: OpenAIMessage) {
        id = UUID()
        openAIMessage = msg
        isUser = msg.isUser
        content = msg.content
        audioFilename = "\(id).mp3"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        openAIMessage = try container.decode(OpenAIMessage.self, forKey: .openAIMessage)
        isUser = try container.decode(Bool.self, forKey: .isUser)
        content = try container.decode(String.self, forKey: .content)
        audioFilename = try container.decode(String.self, forKey: .audioFilename)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(openAIMessage, forKey: .openAIMessage)
        try container.encode(isUser, forKey: .isUser)
        try container.encode(content, forKey: .content)
        try container.encode(audioFilename, forKey: .audioFilename)
    }
}


struct ChatConversation: Codable, Identifiable {
    let id: UUID
    var messages: [ChatMessage]
    var title: String
    private var timestamp: Double?
    private let fileManager = FileManager.default
    
    init(messages: [ChatMessage]) {
        #if DEBUG
        let id = getPersistentUUID(key: "700-of-770")
        #else
        let id = UUID()
        #endif
        self.id = id
        self.messages = messages
        self.title = "Title \(id)"
    }
    
    private var fileURL: URL {
        self.fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("\(self.id).chatConversation.json")
    }
    
    mutating func append(_ message: ChatMessage) {
        self.messages.append(message)
    }
    
    func isNew() -> Bool {
        return self.fileManager.fileExists(atPath: fileURL.path)
    }
    
//    func setupMetadata() {
//        // get timestamp
//        self.timestamp = Date().timeIntervalSince1970
//    }
    
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

