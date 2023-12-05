//
//  ErrorStatusManager.swift
//  LLMLL
//
//  Created by Maxwell Peterson on 12/4/23.
//

import Foundation


enum ConnectionError: Error {
    case offline
    case connectionLost
    case badDataFromServer
}

enum NetworkError: Error {
    case serverSeemsDown
}

func isInternetError(_ err: Error) -> Bool {
    let errstr = "\(err)"
    return errstr.contains("offline") || (errstr.contains("connection") && errstr.contains("lost"))
}

class ErrorStatusManager: ObservableObject {
    @Published var isOffline = false
    @Published var serverDown = false
    
    func somethingWrong() -> Bool {
        return self.isOffline || self.serverDown
    }
    
    func setHappyState() {
        self.isOffline = false
        self.serverDown = false
    }
    
    func setNetworkErrorStatus(_ error: Error) {
        Logger.shared.log("\(#function)")
        if case ConnectionError.offline = error {
            Logger.shared.log("\(#function): offline")
            self.isOffline = true
        } else if case NetworkError.serverSeemsDown = error {
            Logger.shared.log("\(#function): server seems down")
            self.serverDown = true
        }
    }
}

