//
//  OpenAIAPI.swift
//  LLMLL
//
//  Created by Maxwell Peterson on 11/16/23.
//

import Foundation

class OpenAIAPI {
    private let apiKey: String
    private let session = URLSession.shared
    var url: String {
        fatalError("Subclasses need to provide their own URL.")
    }
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func constructRequest(url: String) -> URLRequest? {
        guard let apiUrl = URL(string: url) else {
            print("Invalid URL")
            return nil
        }

        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
    
    func makeRequest(requestBody: [String: Any], completion: @escaping (Result<Data, Error>) -> Void) {

        guard var request = constructRequest(url: url) else { return }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
        } catch {
            completion(.failure(error))
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "TextToSpeechAPIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
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

        let requestBody: [String: Any] = [
            "model": "tts-1",
            "input": text,
            "voice": "alloy"
        ]

        makeRequest(requestBody: requestBody, completion: completion)
    }
}
