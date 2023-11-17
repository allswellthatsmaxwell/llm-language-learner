//
//  TextToSpeechAPI.swift
//  LLMLL
//
//  Created by Maxwell Peterson on 11/16/23.
//

import Foundation

class TextToSpeechAPI: OpenAIAPI {
    private let url = "https://api.openai.com/v1/audio/speech"

    func synthesizeSpeech(from text: String, completion: @escaping (Result<Data, Error>) -> Void) {

        let requestBody: [String: Any] = [
            "model": "tts-1",
            "input": text,
            "voice": "alloy"
        ]

        makeRequest(requestBody: requestBody, completion: completion)
    }
}
