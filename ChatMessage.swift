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
    var content: String
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


