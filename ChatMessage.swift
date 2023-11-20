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
        self.id = UUID()
        self.openAIMessage = msg
        self.isUser = msg.isUser
        self.content = msg.content
        self.audioFilename = "\(id).mp3"
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

class ChatConversation: Codable, Identifiable {
    let id: UUID
    var messages: [ChatMessage]
    private let fileManager = FileManager.default
    
    init(messages: [ChatMessage]) {
        self.id = UUID()
        self.messages = messages
    }
    
    private var fileURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("\(id).chatConversation.json")
    }
    
    func append(_ message: ChatMessage) {
        messages.append(message)
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
    
    required init(from decoder: Decoder) throws {
           let container = try decoder.container(keyedBy: CodingKeys.self)
           id = try container.decode(UUID.self, forKey: .id)
           messages = try container.decode([ChatMessage].self, forKey: .messages)
       }

       private enum CodingKeys: String, CodingKey {
           case id, messages
       }
}



