//
//  TextToSpeechAPI.swift
//  LLMLL
//
//  Created by Maxwell Peterson on 11/16/23.
//

import Foundation

class TextToSpeechAPI {
    private let apiKey: String
    private let session = URLSession.shared
    private let apiUrl = URL(string: "https://api.openai.com/v1/audio/speech")!

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func synthesizeSpeech(from text: String, completion: @escaping (Result<Data, Error>) -> Void) {
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "model": "tts-1",
            "input": text,
            "voice": "alloy"
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            print("URL: \(apiUrl.absoluteString)")
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

func fetchFromHttpBin() {
    // URL for httpbin.org GET endpoint
    guard let url = URL(string: "https://httpbin.org/get") else {
        print("Invalid URL")
        return
    }

    // Create a URLSession data task
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        // Check for errors
        if let error = error {
            print("Error: \(error.localizedDescription)")
            return
        }

        // Check if the response data is non-nil
        guard let data = data else {
            print("No data received")
            return
        }

        // Attempt to convert the data to a String and print it
        if let stringResponse = String(data: data, encoding: .utf8) {
            print("Response: \(stringResponse)")
        }
    }

    // Start the network task
    task.resume()
}
