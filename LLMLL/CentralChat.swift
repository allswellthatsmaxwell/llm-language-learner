//
//  CentralChat.swift
//  LLMLL
//
//  Created by Maxwell Peterson on 11/18/23.
//

import Foundation
import SwiftUI
import SwiftData

struct ChatMessage: Identifiable {
    let id = UUID()
    var openAIMessage: OpenAIMessage
    var isUser: Bool // True for user messages, false for bot messages
    let content: String
    
    init(msg: OpenAIMessage) {
        self.openAIMessage = msg
        self.isUser = msg.isUser
        self.content = msg.content
    }
}

struct ChatView: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    private var chatAPI: ChatAPI = ChatAPI()

    var body: some View {
        VStack {
            // Messages List
            List(messages) { message in
                HStack {
                    if message.isUser {
                        Spacer() // Push user messages to the right
                    }
                    Text(message.openAIMessage.content)
                        .padding()
                        .background(message.isUser ? Color.blue : Color.gray)
                        .cornerRadius(10)
                    if !message.isUser {
                        Spacer() // Push bot messages to the left
                    }
                }
            }

            // Message Input
            HStack {
                TextField("Type a message", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                Button("Send") {
                    sendMessage()
                }
                .padding()
            }
        }
    }

    private func sendMessage() {
        let msg = OpenAIMessage(userContent: inputText)
        let newMessage = ChatMessage(msg: msg)
        messages.append(newMessage)
        self.chatAPI.sendChat(messages: [msg]) {
            result in switch result {
                case .success(let completion):
                if let completionString = String(data: completion, encoding: .utf8) {
                    Logger.shared.log(completionString)
                } else {
                    Logger.shared.log("Failed to convert chat completion data to string")
                }
                
            case .failure(let error):
                Logger.shared.log("Failed to get chat completion: \(error.localizedDescription)")
            }
        }

        
    }
}


struct CentralChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
    }
}
