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
        self.addContentType(&request)
        return request
    }
    
    func submitRequest(request: URLRequest, completion: @escaping (Result<Data, Error>) -> Void) {
        self.session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(isInternetError(error) ? .failure(ConnectionError.offline) : .failure(NetworkError.serverSeemsDown))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            let datastr = String(data: data, encoding: .utf8)
            completion(.success(data))
        }.resume()
    }
}


class TextToSpeechAPI: OpenAIAPI {
    override var url: String {
        // return "https://api.openai.com/v1/audio/speech"
        return "http://127.0.0.1:5000/synthesize_speech"
    }
    
    func synthesizeSpeech(from text: String, voice: String = "onyx", completion: @escaping (Result<Data, Error>) -> Void) {
        guard var request = self.constructRequest(url: url) else { return }

        // Set the Content-Type to application/json
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {            
            let payload = [
                "text": text,
                "voice": voice
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(error))
            return
        }

        self.submitRequest(request: request, completion: completion)
    }
}

class TranscriptionAPI: OpenAIAPI {
    override var url: String {
        // return "https://api.openai.com/v1/audio/transcriptions"
        return "http://127.0.0.1:5000/transcribe"
    }
    private let boundary = "Boundary-\(UUID().uuidString)"
    
    override func addContentType(_ request: inout URLRequest) {
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    }

    func transcribe(fileURL: URL, completion: @escaping (Result<Data, Error>) -> Void) {
        guard var request = self.constructRequest(url: url) else { return }

        // Set the content type to the appropriate type of your file, or application/octet-stream for generic binary data
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        do {
            // Directly set the httpBody to the data of the file
            let fileData = try Data(contentsOf: fileURL)
            request.httpBody = fileData
        } catch {
            completion(.failure(error))
            return
        }

        self.submitRequest(request: request, completion: completion)
    }
    
    
//    private func convertFileData(fieldName: String,
//                                 fileName: String,
//                                 mimeType: String,
//                                 fileURL: URL,
//                                 using boundary: String) -> Data {
//        let data = NSMutableData()
//        data.appendString("--\(boundary)\r\n")
//        data.appendString("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
//        data.appendString("Content-Type: \(mimeType)\r\n\r\n")
//        data.append(try! Data(contentsOf: fileURL))
//        data.appendString("\r\n")
//        return data as Data
//    }
    
    //    func transcribe(fileURL: URL, completion: @escaping (Result<Data, Error>) -> Void) {
    //        guard var request = self.constructRequest(url: url) else { return }
    //
    //        let httpBody = NSMutableData()
    //
    //        // Append file data
    //        httpBody.append(self.convertFileData(fieldName: "file",
    //                                             fileName: fileURL.lastPathComponent,
    //                                             mimeType: "audio/m4a",
    //                                             fileURL: fileURL,
    //                                             using: boundary))
    //
    //        // Append model parameter
    //        httpBody.appendString("--\(boundary)\r\n")
    //        httpBody.appendString("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
    //        httpBody.appendString("whisper-1\r\n")
    //
    //        // End of the multipart data
    //        httpBody.appendString("--\(boundary)--\r\n")
    //
    //        request.httpBody = httpBody as Data
    //
    //        self.submitRequest(request: request, completion: completion)
    //    }
    
}


private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
