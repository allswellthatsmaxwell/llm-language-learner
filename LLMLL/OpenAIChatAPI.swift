//
//  OpenAIChatAPI.swift
//  LLMLL
//
//  Created by Maxwell Peterson on 11/18/23.
//

import Foundation

enum ChatAPIError: Error {
    case missingData
    case decodingError
    case networkError(String)
    // Add other error cases as needed
}

extension ChatAPIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingData:
            return NSLocalizedString("Missing data in response.", comment: "Missing Data Error")
        case .decodingError:
            return NSLocalizedString("Error decoding response data.", comment: "Decoding Error")
        case .networkError(let message):
            return NSLocalizedString("Network error: \(message)", comment: "Network Error")
        }
    }
}

class OpenAIMessage: Codable {
    var role: String
    var content: String
    let isUser: Bool
    
    init(role: String, content: String) {
        self.role = role
        self.content = content
        self.isUser = role == "user"
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.role = try container.decode(String.self, forKey: .role)
        self.content = try container.decode(String.self, forKey: .content)
        self.isUser = role == "user"
    }
    
    convenience init(userContent: String) {
        self.init(role: "user", content: userContent)
    }
    
    convenience init(systemContent: String) {
        self.init(role: "system", content: systemContent)
    }
    
    convenience init(AIContent: String) {
        self.init(role: "assistant", content: AIContent)
    }
}

struct OpenAIResponse: Codable {
    var choices: [Choice]
}

struct OpenAIStreamingResponse: Codable {
    struct Choice: Codable {
        struct Delta: Codable {
            let content: String?
            let role: String?
        }
        let delta: Delta?
        let finish_reason: String?
        let index: Int
    }

    let choices: [Choice]
    let created: Int
    let id: String
    let model: String
    let object: String
}

struct Choice: Codable {
    let message: OpenAIMessage
    let finish_reason: String?
}


class ChatAPI: OpenAIAPI {
    
    var systemPrompt: String {
        fatalError("Subclasses need to provide their own systemMessage.")
    }
    
    override var url: String {
        return "https://api.openai.com/v1/chat/completions"
    }
    
    func getChatCompletionResponse(messages: [OpenAIMessage], completion: @escaping (Result<Data, Error>) -> Void) {
        guard var request = constructRequest(url: url) else { return }
        
        let allMessages = [OpenAIMessage(systemContent: self.systemPrompt)] + messages
        
        let messageDicts = allMessages.map { ["role": $0.role, "content": $0.content] }
        
        do {
            let requestBody: [String: Any] = [
                "model": "gpt-4-1106-preview",
                // "model": "gpt-3.5-turbo-1106",
                "messages": messageDicts,
                "stream": false
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            submitRequest(request: request, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }
        
    
    func sendMessages(messages: [OpenAIMessage], completion: @escaping (OpenAIMessage?) -> Void) {
        self.getChatCompletionResponse(messages: messages) { result in
            switch result {
            case .success(let data):
                do {
                    Logger.shared.log("sendMessages: Received response: \(String(data: data, encoding: .utf8) ?? "No data")")
                    let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                    if let firstMessage = response.choices.first?.message {
                        return completion(firstMessage)
                    } else {
                        Logger.shared.log("No messages found in response")
                    }
                } catch {
                    Logger.shared.log("Failed to decode response: \(error.localizedDescription)")
                    if let error = error as? DecodingError {
                        switch error {
                        case .dataCorrupted(let context), .keyNotFound(_, let context),
                                .typeMismatch(_, let context), .valueNotFound(_, let context):
                            Logger.shared.log("Decoding error: \(context.debugDescription)")
                        @unknown default:
                            Logger.shared.log("Unknown decoding error")
                        }
                    }
                }
            case .failure(let error): Logger.shared.log("Failed to get chat completion: \(error.localizedDescription)")
            }
        }
    }
}

class ChatStreamingAPI: ChatAPI {
    func getChatCompletionResponse(messages: [OpenAIMessage], 
                                   chunkCompletion: @escaping (Result<ChatMessage, Error>) -> Void,
                                   streamCompletion: @escaping () -> Void) {
        Logger.shared.log("Entered getChatCompletionResponseStreaming")
        guard var request = constructRequest(url: url) else { return }
        
        let allMessages = [OpenAIMessage(systemContent: self.systemPrompt)] + messages
        let messageDicts = allMessages.map { ["role": $0.role, "content": $0.content] }
        
        let requestBody: [String: Any] = [
            "model": "gpt-4-1106-preview",
            "messages": messageDicts,
            "stream": true
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            Logger.shared.log("ChatStreamingAPI.getChatCompletionResponse: Error when constructing httpBody: \(error.localizedDescription)")
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                Logger.shared.log("ChatStreamingAPI.getChatCompletionResponse: Error in shared.dataTask: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                Logger.shared.log("ChatStreamingAPI.getChatCompletionResponse: No data received")
                return
            }
            self.processStreamedData(
                data,
                chunkCompletion: { chatMessage in DispatchQueue.main.async { chunkCompletion(chatMessage) } },
                streamCompletion: { DispatchQueue.main.async { streamCompletion() } })
        }
        
        task.resume()
    }
    
    private func processStreamedData(_ data: Data, 
                                     chunkCompletion: @escaping (Result<ChatMessage, Error>) -> Void,
                                     streamCompletion: @escaping () -> Void) {
        Logger.shared.log("processStreamedData")
        // Assuming the data is UTF8 encoded
        guard let string = String(data: data, encoding: .utf8) else {
            Logger.shared.log("processStreamedData: failed to convert data to string")
            return
        }
        
        // Split the string by newlines to process each JSON object separately
        let jsonStrings = string.components(separatedBy: "\n")
        
        for jsonString in jsonStrings {
            Logger.shared.log("Attempting to decode JSON string: \(jsonString)")
            let cleanedJsonString = jsonString.replacingOccurrences(of: "data: ", with: "")
            guard !cleanedJsonString.isEmpty,
                  let jsonData = cleanedJsonString.data(using: .utf8) else {
                Logger.shared.log("processStreamedData: JSON data is empty, or failed to convert to data")
                continue
            }
            
            do {
                let responseChunk = try JSONDecoder().decode(OpenAIStreamingResponse.self, from: jsonData)
                
                self.processIncomingMessage(responseChunk) { result in
                    switch result {
                    case .success(let chatMessage):
                        DispatchQueue.main.async {
                            chunkCompletion(.success(chatMessage))
                        }
                    case .failure(let error):
                        DispatchQueue.main.async {
                            chunkCompletion(.failure(error))
                        }
                    }
                }
                
                if let firstChoice = responseChunk.choices.first,
                   let finishReason = firstChoice.finish_reason {
                    if finishReason == "stop" {
                        DispatchQueue.main.async { streamCompletion() }
                    }
                }
            } catch {
                Logger.shared.log("processStreamedData: Failed to decode JSON")
            }
        }
    }
    
    private func processIncomingMessage(_ responseChunk: OpenAIStreamingResponse, 
                                        _ chunkCompletion: @escaping (Result<ChatMessage, Error>) -> Void) {
        Logger.shared.log("\(responseChunk)")
        guard let delta = responseChunk.choices.first?.delta else {
            return
        }
        
        let message = ChatMessage(msg: OpenAIMessage(AIContent: delta.content ?? ""))
        chunkCompletion(.success(message))
    }
}
    

class AdvisorChatAPI: ChatStreamingAPI {
    override var systemPrompt: String {
        return """
You are to act as a teacher for Korean language and grammar, for a student who speaks English as their first language.
The user will send you a transcript of them speaking Korean. They spoke it aloud, and the text you receive \
is the result of a transcription algorithm. The student's pronunciation will not be great, \
so the transcription may have issues.
Therefore, you should do your best to interpret what they are trying to say.

* If there are no problems with the Korean you receive, just respond with the original Hangul, as well as the English translation of what you received.
* If there are problems:
  * respond with the corrected word/sentence/phrase/paragraph/whatever (in Hangul)
  * give a breakdown (in English) of the corrections you made.
    * In the breakdown, list the Hangul you added, removed, or changed, with the description of why.
    * Use only the 요, not the formal 니다 form, unless the user themselves included a formal 니다 form in their transcription.
    * Not using the polite form, with 요 in the right places, counts as a mistake you should correct.
  * Finally, give the translation.
* Do not include the english pronunciation. A separate utility will pronounce the Korean you provide, using text-to-speech technology.

Make sure to put the correct hangul first, on its own line.
"""
    }
}

class ExtractorChatAPI: ChatAPI {
    override var systemPrompt: String {
        return """
Extract the Korean Hangul text from the first part of the message the user gives you. Only extract the Hangul word/phrase/sentence/paragraph/text.
Don't extract any English. Return only the Hangul you extract, with no additional text. No English whatsoever!
"""
    }
}


class TitlerChatAPI: ChatAPI {
    override var systemPrompt: String {
        return """
The user will give you a conversation about the Korean language. Return a good, succinct title for the conversation. This is \
in the context of a Korean-learning app, so don't include concepts like "learning" or "Korean" in the title.
"""
    }
}

