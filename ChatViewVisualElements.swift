//
//  ChatViewVisualElements.swift
//  LLMLL
//
//  Created by Maxwell Peterson on 11/22/23.
//

import Foundation
import SwiftUI


struct CircleIconButton: View {
    let iconName: String
    let action: () -> Void
    let size: CGFloat
    @State private var isHovering = false
    @Environment(\.colorScheme) var colorScheme    
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundColor(isHovering ? (colorScheme == .dark ? Color.white : Color.black) : Color.gray)
        }
        .buttonStyle(PlainButtonStyle())
        .padding([.top, .bottom], 12)
        .padding([.leading, .trailing], 8)
        .onHover { hovering in isHovering = hovering }
    }
}

struct AudioCircleIconButton: View {
    @ObservedObject var audioRecorder: AudioRecorder
    let action: () -> Void
    let size: CGFloat

    var body: some View {
        CircleIconButton(
            iconName: audioRecorder.isRecording ? "stop.circle.fill" : "mic.circle",
            action: action,
            size: size
        )
    }
}

struct NewConversationButtonView: View {
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus.bubble")
                .font(.system(size: 56))
                .contentShape(Circle())
                .foregroundColor(isHovering ? (colorScheme == .dark ? Color.white : Color.black) : Color.gray)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity, alignment: .center)
        .padding([.top], 14)
        .onHover { hovering in isHovering = hovering }
        Divider()
            .background(Color.gray.opacity(0.15))
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let action: ( @escaping () -> Void ) -> Void
    let fontSize: CGFloat
    private let listenButtonSize = CGFloat(30)
    @State private var isLoading = false
    @Environment(\.colorScheme) var colorScheme
    
    private func getBackgroundColor() -> some View {
        if self.message.isUser {
            return Color.blue.brightness(0.0)
        } else {
            return colorScheme == .dark ? Color.gray.brightness(0.0) : Color.gray.brightness(0.4)
        }
    }
    
    private func getForegroundColor() -> Color {
        if self.message.isUser {
            return Color.white
        } else {
            return colorScheme == .dark ? Color.white : Color.black
        }
    }
    
    var body: some View {
        HStack {
            if self.message.isUser { Spacer() } // Right-align user messages
            
            Text(self.message.content)
                .padding()
                .background(self.getBackgroundColor())
                .cornerRadius(10)
                .font(.system(size: self.fontSize))
                .foregroundColor(self.getForegroundColor())
                .textSelection(.enabled)
            
            if !self.message.isUser { Spacer() } // Left-align AI messages
            if self.isLoading {
                // Display a loading indicator or alternative icon
                ProgressView()
                    .frame(width: self.listenButtonSize, height: self.listenButtonSize)
            } else {
                CircleIconButton(
                    iconName: "speaker.circle",
                    action: {
                        action {
                            self.isLoading.toggle()  // Only set to true when needed
                        }
                    },
                    size: self.listenButtonSize
                )
            }
        }
    }
}

struct CustomTextEditor: View {
    @Binding var text: String
    var placeholder: String
    var fontSize: CGFloat
    var onReturn: () -> Void
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.gray)
                    .padding(.leading, 4)
                    .padding(.top, 8)
            }
            TextEditor(text: $text)
                .frame(minHeight: fontSize, maxHeight: 60)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .onSubmit {
                    onReturn()
                }
        }
        .font(.system(size: fontSize))
    }
}



struct ConversationsListView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(self.viewModel.conversationOrder, id: \.self) { conversationId in
                VStack(spacing: 0) {
                    Text(self.viewModel.titleStore.titles[conversationId, default: defaultChatTitle])
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding([.leading, .trailing], 16)
                        .padding([.top, .bottom], 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            self.viewModel.activeConversationId = conversationId
                        }
                    Divider()
                        .background(Color.gray.opacity(0.15))
                }
                .background(getConversationEntryColor(conversationId))
            }
        }
    }
    
    private func isActiveConversation(_ conversationId: UUID) -> Bool {
        return conversationId == self.viewModel.activeConversationId
    }
    
    private func getConversationEntryColor(_ conversationId: UUID) -> some View {
        let isActive = self.isActiveConversation(conversationId)
        if self.colorScheme == .dark {
            return isActive ? Color.gray.brightness(-0.3) : Color.clear.brightness(0.0)
        } else {
            return isActive ? Color.gray.brightness(0.2) : Color.clear.brightness(0.0)
        }
    }
}


struct DividerLine: View {
    @Environment(\.colorScheme) var colorScheme
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    
    var body: some View {
        let lineColor = colorScheme == .dark ? Color.white : Color.black
        
        Rectangle()
            .fill(lineColor)
            .frame(width: width, height: height)
            .padding(0)
    }
}
