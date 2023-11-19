//
//  OpenAIChatAPI.swift
//  LLMLL
//
//  Created by Maxwell Peterson on 11/18/23.
//

import Foundation


class OpenAIMessage: Codable {
    var role: String
    var content: String
    let isUser: Bool
    
    init(role: String, content: String) {
        self.role = role
        self.content = content
        isUser = role == "user"
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decode(String.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        isUser = role == "user"
    }
    
    convenience init(userContent: String) {
        self.init(role: "user", content: userContent)
    }
    
    convenience init(systemContent: String) {
        self.init(role: "system", content: systemContent)
    }
    
    convenience init(AIContent: String) {
        self.init(role: "ai", content: AIContent)
    }
}

struct OpenAIResponse: Codable {
    var choices: [Choice]
}

struct Choice: Codable {
    var message: OpenAIMessage
}


class ChatAPI: OpenAIAPI {
    
    var systemPrompt: String {
        fatalError("Subclasses need to provide their own systemMessage.")
    }
    
    override var url: String {
        return "https://api.openai.com/v1/chat/completions"
    }
    
    func submit(messages: [OpenAIMessage], completion: @escaping (Result<Data, Error>) -> Void) {
        guard var request = constructRequest(url: url) else { return }
        
        let allMessages = [OpenAIMessage(systemContent: self.systemPrompt)] + messages
        
        let messageDicts = allMessages.map { ["role": $0.role, "content": $0.content] }
        
        do {
            let requestBody: [String: Any] = [
                "model": "gpt-3.5-turbo-1106",
                "messages": messageDicts            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            submitRequest(request: request, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }
}

class AdvisorChatAPI: ChatAPI {
    override var systemPrompt: String {
        return """
You are to act as a teacher for Korean language and grammar, for a student who speaks English as their first language.
The user will send you a transcript of them speaking Korean. They spoke it aloud, and the text you receive \
is the result of a transcription algorithm. The student's pronunciation will not be great, \
so the transcription may have issues.
Therefore, you should do your best to interpret what they are trying to say, \
giving your best guess as to what they meant to say.
(Not using the polite form, with 요 in the right places, counts as a mistake you should correct.)

* If there are no problems with the Korean you receive, just respond with the original Hangul, as well as the English translation of what you received.
* If there are problems:
  * respond with the corrected word/sentence/phrase/paragraph/whatever (in Hangul)
  * give a breakdown (in English) of the corrections you made.
    * In the breakdown, list the Hangul you added, removed, or changed, with the description of why.
    * Use only the 요, not the formal 니다 form, unless the user themselves included a formal 니다 form in their transcription.
  * Finally, give the translation.
* Do not include the english pronunciation. A separate utility will pronounce the Korean you provide, using text-to-speech technology.
"""
    }
}

class ExtractorChatAPI: ChatAPI {
    override var systemPrompt: String {
        return """
Extract the Korean Hangul text from the first part of the message the user gives you. Only extract the one Hangul word/phrase/sentence/paragraph/text.
Don't extract any English. Return only the Hangul you extract, with no additional text.
"""
    }
}

