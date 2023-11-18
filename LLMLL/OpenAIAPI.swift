//
//  OpenAIAPI.swift
//  LLMLL
//
//  Created by Maxwell Peterson on 11/16/23.
//

import Foundation

private func readApiKey() -> String? {
    if let path = Bundle.main.path(forResource: "keys", ofType: "plist"),
       let config = NSDictionary(contentsOfFile: path) as? [String: Any] {
        let apiKey = config["OPENAI_API_KEY"] as? String
        return apiKey
    }
    return nil
}


class OpenAIAPI {
    private let apiKey: String
    private let session = URLSession.shared
    var url: String {
        fatalError("Subclasses need to provide their own URL.")
    }
    
    init() {
        if let apiKeyLocal = readApiKey() {
            self.apiKey = apiKeyLocal
        } else {
            Logger.shared.log("Failed to find OPENAI_API_KEY")
            self.apiKey = "MissingAPIKey"
        }
    }
    
    open func addContentType(_ request: inout URLRequest) {
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    
    func constructRequest(url: String) -> URLRequest? {
        guard let apiUrl = URL(string: url) else {
            Logger.shared.log("Invalid URL")
            return nil
        }
        
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        addContentType(&request)
        return request
    }
    
    func submitRequest(request: URLRequest, completion: @escaping (Result<Data, Error>) -> Void) {
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            completion(.success(data))
        }.resume()
    }
}


class TextToSpeechAPI: OpenAIAPI {
    override var url: String {
        return "https://api.openai.com/v1/audio/speech"
    }
    
    func synthesizeSpeech(from text: String, completion: @escaping (Result<Data, Error>) -> Void) {
        guard var request = constructRequest(url: url) else { return }
        
        do {
            request.httpBody = try JSONSerialization.data(
                withJSONObject: [
                    "model": "tts-1",
                    "input": text,
                    "voice": "alloy"
                ])
        } catch {
            completion(.failure(error))
            return
        }
        
        submitRequest(request: request, completion: completion)
    }
}

class TranscriptionAPI: OpenAIAPI {
    override var url: String {
        return "https://api.openai.com/v1/audio/transcriptions"
    }
    private let boundary = "Boundary-\(UUID().uuidString)"
    
    override func addContentType(_ request: inout URLRequest) {
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    }
    
    private func convertFileData(fieldName: String,
                                 fileName: String,
                                 mimeType: String,
                                 fileURL: URL,
                                 using boundary: String) -> Data {
        let data = NSMutableData()
        data.appendString("--\(boundary)\r\n")
        data.appendString("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
        data.appendString("Content-Type: \(mimeType)\r\n\r\n")
        data.append(try! Data(contentsOf: fileURL))
        data.appendString("\r\n")
        return data as Data
    }
    
    func transcribe(fileURL: URL, completion: @escaping (Result<Data, Error>) -> Void) {
        guard var request = constructRequest(url: url) else { return }
        
        let httpBody = NSMutableData()
        
        // Append file data
        httpBody.append(convertFileData(fieldName: "file",
                                        fileName: fileURL.lastPathComponent,
                                        mimeType: "audio/x-m4a",
                                        fileURL: fileURL,
                                        using: boundary))
        
        // Append model parameter
        httpBody.appendString("--\(boundary)\r\n")
        httpBody.appendString("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        httpBody.appendString("whisper-1\r\n")
        
        // End of the multipart data
        httpBody.appendString("--\(boundary)--\r\n")
        
        request.httpBody = httpBody as Data
        
        submitRequest(request: request, completion: completion)
    }
}

extension NSMutableData {
    func appendString(_ string: String) {
        let data = string.data(using: String.Encoding.utf8, allowLossyConversion: false)
        append(data!)
    }
}



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
}


class ChatAPI: OpenAIAPI {
    override var url: String {
        return "https://api.openai.com/v1/chat/completions"
    }
    
    func sendChat(messages: [OpenAIMessage], completion: @escaping (Result<Data, Error>) -> Void) {
        guard var request = constructRequest(url: url) else { return }
        
        let messageDicts = messages.map { ["role": $0.role, "content": $0.content] }
        
        do {
            let requestBody: [String: Any] = [
                "model": "gpt-3.5-turbo",
                "messages": messageDicts
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        submitRequest(request: request, completion: completion)
    }
}
