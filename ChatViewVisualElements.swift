//
//  ChatViewVisualElements.swift
//  LLMLL
//
//  Created by Maxwell Peterson on 11/22/23.
//

import Foundation
import SwiftUI


private var circleButtonTopBottomPadding = CGFloat(12)
private var circleButtonLeadingTrailingPadding = CGFloat(8)

struct SpeakerButton: View {
    let iconName: String
    let action: () -> Void
    let longPressAction: () -> Void
    let size: CGFloat
    @State private var pressTimer: Timer? = nil
    @State private var isHovering = false
    @Environment(\.colorScheme) var colorScheme
    
    init(iconName: String, action: @escaping () -> Void, longPressAction: @escaping () -> Void = {}, size: CGFloat = 30) {
        self.iconName = iconName
        self.action = action
        self.longPressAction = longPressAction
        self.size = size
    }
    
    var body: some View {
        Image(systemName: iconName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .foregroundColor(isHovering ? (colorScheme == .dark ? Color.white : Color.black) : Color.gray)
        
            .buttonStyle(PlainButtonStyle())
            .padding([.top, .bottom], circleButtonTopBottomPadding)
            .padding([.leading, .trailing], circleButtonLeadingTrailingPadding)
            .onHover { hovering in isHovering = hovering }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        pressTimer?.invalidate()
                        pressTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                            longPressAction()
                            pressTimer = nil
                        }
                    }
                    .onEnded { _ in
                        pressTimer?.invalidate()
                        pressTimer = nil
                        action()
                    }
            )
    }
}

struct CircleIconButton: View {
    let iconName: String
    let action: () -> Void
    let size: CGFloat
    var topBottomPadding = CGFloat(12)
    var leadingTrailingPadding = CGFloat(8)
    @State private var isHovering = false
    @Environment(\.colorScheme) var colorScheme
    
    init(iconName: String, action: @escaping () -> Void, size: CGFloat, topBottomPadding: CGFloat? = nil, leadingTrailingPadding: CGFloat? = nil) {
        self.iconName = iconName
        self.action = action
        self.size = size
        self.topBottomPadding = topBottomPadding ?? circleButtonTopBottomPadding
        self.leadingTrailingPadding = leadingTrailingPadding ?? circleButtonLeadingTrailingPadding
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundColor(isHovering ? (colorScheme == .dark ? Color.white : Color.black) : Color.gray)
        }
        .buttonStyle(PlainButtonStyle())
        .padding([.top, .bottom], self.topBottomPadding)
        .padding([.leading, .trailing], self.leadingTrailingPadding)
        .onHover { hovering in isHovering = hovering }
    }
}

struct AudioCircleIconButton: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var audioRecorder: AudioRecorder
    let action: () -> Void
    let size: CGFloat

    var body: some View {
        Group {
            if self.viewModel.isTranscribing {
                ProgressView()
                    .frame(width: size, height: size)
                    .scaleEffect(1.5)
                    // .aspectRatio(1, contentMode: .fit)
                    .padding([.top, .bottom], circleButtonTopBottomPadding)
                    .padding([.leading, .trailing], circleButtonLeadingTrailingPadding)
                    .cornerRadius(10)
            } else {
                CircleIconButton(
                    iconName: self.audioRecorder.isRecording ? "stop.circle.fill" : "mic.circle",
                    action: action,
                    size: size
                )
            }
        }
    }
}

struct SlowModeButtonView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        CircleIconButton(
            iconName: self.viewModel.slowMode ? "tortoise.circle.fill" : "tortoise.circle",
            action: { self.viewModel.toggleSlowMode() },
            size: 30,
            topBottomPadding: 0,
            leadingTrailingPadding: 0
        )
    }
}


struct LanguageSelectorView: View {
    @State private var selectedLanguage = "Korean"
    @ObservedObject var viewModel: ChatViewModel
    @State private var isHovering = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Menu {
            ForEach(languageOptions, id: \.self) { language in
                Button(language) {
                    do {
                        try self.viewModel.setLanguage(language)
                        self.selectedLanguage = language
                    } catch {
                        Logger.shared.log("Language not supported: \(language)")
                    }
                }
            }
        } label: {
            HStack {
                Text(self.selectedLanguage)
                    .foregroundColor(isHovering ? (colorScheme == .dark ? Color.white : Color.black) : Color.gray)
            }
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .menuStyle(.borderlessButton)
        .fixedSize()
        .onHover { hovering in isHovering = hovering }
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
        .frame(alignment: .trailing)
        .padding([.top], 14)
        .onHover { hovering in isHovering = hovering }
        Divider()
            .background(Color.gray.opacity(0.15))
    }
}

struct OfflineIndicatorView: View {
    @StateObject var errorStatusManager: ErrorStatusManager
    
    private func getUserFacingErrorMessage() -> String {
        if self.errorStatusManager.isOffline {
            return "Network error?! Please confirm you are connected to the internet."
        } else if self.errorStatusManager.serverDown {
            return "It looks like our server is down. I'm sorry ;-;"
        } else {
            return "Something is wrong, but I'm not sure what..."
        }
        
    }
    
    var body: some View {
        Text(self.getUserFacingErrorMessage())
            .font(.system(size: 10))
            .foregroundColor(.red)
            // .frame(width: 100, height: 80, alignment: .center)
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let action: ( @escaping () -> Void ) -> Void
    let fontSize: CGFloat
    var viewModel: ChatViewModel
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
            
            if self.message.content.isEmpty {
                if self.viewModel.errorStatusManager.isOffline {
                    Text("")
                } else {
                    ProgressView()
                        .frame(width: 30, height: 30)
                        .padding()
                        .background(self.getBackgroundColor())
                        .cornerRadius(10)
                }
            } else {
                Text(self.message.content)
                    .padding()
                    .background(self.getBackgroundColor())
                    .cornerRadius(10)
                    .font(.system(size: self.fontSize))
                    .foregroundColor(self.getForegroundColor())
                    .textSelection(.enabled)
            }
            if !self.message.isUser { Spacer() } // Left-align AI messages
            
            if self.isLoading {
                ProgressView()
                    .frame(width: self.listenButtonSize, height: self.listenButtonSize)
                    .padding([.top, .bottom], circleButtonTopBottomPadding)
                    .padding([.leading, .trailing], circleButtonLeadingTrailingPadding)
            } else {
                SpeakerButton(
                    iconName: "speaker.circle",
                    action: {
                        self.viewModel.hearButtonTapped(for: self.message, completion: { self.isLoading.toggle() })
                    },
                    longPressAction: {
                        self.viewModel.processAndSynthesizeAudio(self.message,
                                                                 audioFilePath: self.viewModel.getAudioFile(self.message),
                                                                 toggleLoadingState: { self.isLoading.toggle() })
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
