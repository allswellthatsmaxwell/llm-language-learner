//
//  Logger.swift
//  LLMLL
//
//  Created by Maxwell Peterson on 11/17/23.
//

import Foundation


class Logger {
    static let shared = Logger()
    private var logFileURL: URL

    private init() {
        let fileManager = FileManager.default
        let docsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        logFileURL = docsDirectory.appendingPathComponent("appLog.txt")

        if !fileManager.fileExists(atPath: logFileURL.path) {
            fileManager.createFile(atPath: logFileURL.path, contents: nil)
        }
    }

    func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .long)
        let logMessage = "\(timestamp): \(message)\n"
        
        // Append to the log file
        if let fileHandle = FileHandle(forWritingAtPath: logFileURL.path) {
            fileHandle.seekToEndOfFile()
            if let data = logMessage.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } else {
            print("Failed to open file handle")
        }
    }
}


func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}
