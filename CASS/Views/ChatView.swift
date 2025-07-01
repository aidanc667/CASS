import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @State private var isSpeaking = false
    @State private var showingPermissionAlert = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            PersonalityPickerView(selected: $viewModel.selectedPersonality, setPersonality: viewModel.setPersonality)
            
            // Add CASS title and subtitle - moved higher up
            VStack(spacing: 2) {
                Text("C.A.S.S.")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                Text("Conversational AI with Swappable Selves")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 4)
            
            // Animated head view - reduced padding and lowered slightly
            AnimatedHeadView(isSpeaking: $isSpeaking, personality: viewModel.selectedPersonality)
                .frame(width: 200, height: 200)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 25)
                .background(Color.white)
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack {
                        ForEach(viewModel.messages) { message in
                            MessageView(message: message)
                                .transition(.move(edge: .bottom))
                                .id(message.id)
                        }
                    }
                }
                .animation(.easeInOut, value: viewModel.messages)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.top, 0)
                .onChange(of: viewModel.messages) { _, newValue in
                    if let last = newValue.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .onChange(of: viewModel.messages) { oldValue, newValue in
            if !newValue.isEmpty && newValue.count > oldValue.count {
                isSpeaking = true
            } else {
                isSpeaking = false
            }
        }
        .alert("Microphone Access", isPresented: $showingPermissionAlert) {
            Button("Continue") { viewModel.requestMicrophonePermission() }
        } message: {
            Text("CASS AI needs microphone access for voice conversations. You can enable this in the next step.")
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 15) {
                // Microphone button - hides when keyboard is active
                if !isTextFieldFocused {
                    Button(action: {
                        if viewModel.microphonePermissionGranted {
                            viewModel.toggleRecording()
                        } else {
                            showingPermissionAlert = true
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 25)
                                .fill(viewModel.isRecording ? Color.red : Color.orange)
                                .frame(width: 120, height: 120)
                                .shadow(radius: 3)

                            Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 50))
                        }
                    }
                    .transition(.scale)
                }

                // Text input field
                if !viewModel.isContinuousListening {
                    HStack {
                        TextField("Type a message...", text: $inputText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($isTextFieldFocused)
                            .disabled(viewModel.isProcessing)
                            .onTapGesture {
                                isTextFieldFocused = true
                            }

                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.orange)
                                .font(.title)
                        }
                        .disabled(inputText.isEmpty || viewModel.isProcessing)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(Color.white)
            .animation(.easeInOut(duration: 0.2), value: isTextFieldFocused)
        }
        .overlay(
            // Recording indicator
            Group {
                if viewModel.isContinuousListening {
                    VStack {
                        Text("Listening...")
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.8))
                            .cornerRadius(20)
                    }
                    .padding(.bottom, 100)
                    .animation(.easeInOut, value: viewModel.isContinuousListening)
                }
            }
            , alignment: .bottom
        )
        .onAppear { viewModel.startAudioSession() }
        .onDisappear { viewModel.stopAudioSession() }
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        Task {
            await viewModel.sendMessage(inputText)
            inputText = ""
            isTextFieldFocused = true
        }
    }
}

struct MessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading) {
                Text(message.content)
                    .padding()
                    .background(message.isUser ? Color.orange : Color.gray.opacity(0.2))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(16)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

struct PersonalityPickerView: View {
    @Binding var selected: ChatViewModel.Personality
    var setPersonality: (ChatViewModel.Personality) -> Void
    var body: some View {
        HStack(spacing: 16) {
            ForEach(ChatViewModel.Personality.allCases) { personality in
                Button(action: {
                    setPersonality(personality)
                }) {
                    Text(personality.rawValue)
                        .fontWeight(selected == personality ? .bold : .regular)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(selected == personality ? Color.orange.opacity(0.2) : Color.clear)
                        .cornerRadius(10)
                        .foregroundColor(selected == personality ? .orange : .primary)
                }
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

#Preview {
    ChatView()
} 