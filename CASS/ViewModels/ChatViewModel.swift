import SwiftUI
import AVFoundation
import Network
import Speech

final class ChatViewModel: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var messages: [ChatMessage] = []
    @Published var isProcessing = false
    @Published var microphonePermissionGranted = false
    @Published var isRecording = false
    @Published var isContinuousListening = false
    @Published var followUpQuestions: [FollowUpQuestion] = []
    @Published var selectedPersonality: Personality = .friend
    @Published var userHasProvidedLocation = false
    
    private let synthesizer = AVSpeechSynthesizer()
    private let geminiApiKey = "AIzaSyD1C2kWvWGkrTdsr9nQlsJguY21_APiZdA"
    private let monitor = NWPathMonitor()
    private var isConnected = false
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var lastProcessedText = ""
    private var lastRecognizedText = ""
    
    // System prompts for each personality
    private var personalityPrompts: [Personality: String] = [
        .friend: "Your name is CASS. Respond in a warm, encouraging, expressive, and positive tone. Be a real friend who listens, jokes, and uplifts. Use casual, friendly language and show genuine interest in the user's feelings and life.",
        .mentor: "Your name is CASS. Respond with wisdom and clarity. Offer guidance, advice, and insight in a thoughtful, direct, and helpful way. Be like a trusted mentor.",
        .debator: "Your name is CASS. Take the opposite stance of the user, challenge their assumptions, and argue the contrary position, but remain respectful and logical."
    ]
    
    // Initial welcome messages for each personality
    private var personalityWelcomeMessages: [Personality: String] = [
        .friend: "Hey buddy! What's on your mind?",
        .mentor: "How can I help you today? Do you have any questions about your career, relationships, personal life, etc.?",
        .debator: "What topic would you like to debate today?"
    ]
    
    // Store the last user query and AI response for context
    private var lastUserQuery: String? = nil
    private var lastAIResponse: String? = nil
    
    // Tavily API key for real-time search
    private let tavilyApiKey = "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"
    
    private let locationKeywords = ["near me", "location", "where", "closest", "weather", "find", "restaurant", "gas station", "hotel", "store"]
    
    override init() {
        super.init()
        synthesizer.delegate = self
        // Set up network monitoring
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                print("Network status: \(path.status == .satisfied ? "Connected" : "Disconnected")")
            }
        }
        monitor.start(queue: DispatchQueue.global())
        // Add welcome message for default personality
        let welcome = personalityWelcomeMessages[.friend] ?? "Hey! What's on your mind?"
        let welcomeMessage = ChatMessage(content: welcome, isUser: false)
        messages.append(welcomeMessage)
        // Pre-warm audio session for faster mic start
        #if os(iOS)
        DispatchQueue.global().async {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .defaultToSpeaker])
                try audioSession.setActive(true)
            } catch {
                print("Failed to pre-warm audio session: \(error)")
            }
        }
        #endif
    }
    
    func requestMicrophonePermission() {
        #if os(iOS)
        // First request speech recognition authorization
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                    // Then request microphone permission using new API
                    if #available(iOS 17.0, *) {
                        let granted = await AVAudioApplication.requestRecordPermission()
                        self?.microphonePermissionGranted = granted
                        if granted {
                            print("Microphone access granted")
                        } else {
                            print("Microphone access denied")
                        }
                    } else {
                        // Fallback for older iOS versions
                        AVAudioSession.sharedInstance().requestRecordPermission { granted in
                            Task { @MainActor in
                                self?.microphonePermissionGranted = granted
                                if granted {
                                    print("Microphone access granted")
                                } else {
                                    print("Microphone access denied")
                                }
                            }
                        }
                    }
                case .denied:
                    print("Speech recognition permission denied")
                    self?.microphonePermissionGranted = false
                case .restricted:
                    print("Speech recognition permission restricted")
                    self?.microphonePermissionGranted = false
                case .notDetermined:
                    print("Speech recognition permission not determined")
                    self?.microphonePermissionGranted = false
                @unknown default:
                    print("Speech recognition permission unknown")
                    self?.microphonePermissionGranted = false
                }
            }
        }
        #endif
    }
    
    func toggleRecording() {
        #if os(iOS)
        if isRecording {
            stopRecording()
            isRecording = false
            // Process the recognized text when stopping
            if !lastProcessedText.isEmpty {
                Task {
                    await self.sendMessage(lastProcessedText)
                    lastProcessedText = ""
                }
            }
        } else {
            startRecording()
            isRecording = true
        }
        #endif
    }
    
    private func startRecording() {
        #if os(iOS)
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("Speech recognition not available")
            return
        }
        // Clean up any previous session
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        // Configure audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set up audio session: \(error)")
            return
        }
        // Create new recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            print("Failed to create recognition request")
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let result {
                    let fullText = result.bestTranscription.formattedString
                    if !fullText.isEmpty && fullText != self.lastProcessedText {
                        print("Recognized text: \(fullText)")
                        self.lastProcessedText = fullText
                    }
                }
                if let error = error {
                    print("Recognition error: \(error)")
                }
            }
        }
        let recordingFormat = inputNode.inputFormat(forBus: 0)
        print("Using hardware format: \(recordingFormat.description)")
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            print("Started recording")
        } catch {
            print("Failed to start audio engine: \(error)")
            stopRecording()
            return
        }
        #endif
    }
    
    private func pauseRecording() {
        #if os(iOS)
        audioEngine.pause()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
        #endif
    }
    
    private func stopRecording() {
        #if os(iOS)
        DispatchQueue.main.async {
            self.isRecording = false // Ensure this is set immediately for UI update
        }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
        print("Stopped recording")
        #endif
    }
    
    @MainActor
    func sendMessage(_ text: String) async {
        guard !text.isEmpty else { return }
        print("Processing query: \(text)")
        isProcessing = true
        let userMessage = ChatMessage(content: text, isUser: true)
        messages.append(userMessage)
        lastUserQuery = text // Store for follow-up context
        if isLocationQuery(text) && !userHasProvidedLocation {
            addSystemMessage("What location are you talking about?")
            isProcessing = false // Ensure input is re-enabled
            return
        }
        do {
            let response: String
            if shouldUseSearch(for: text) {
                response = try await tavilySearch(query: text)
            } else {
                let contextPrompt = buildConversationPromptFromMessages()
                response = try await geminiChatCompletion(prompt: contextPrompt + "\nUser: " + text + "\nCASS:")
            }
            addSystemMessage(response)
            lastAIResponse = response // Store for follow-up context
        } catch {
            print("Error processing message: \(error)")
            print("Last user query: \(lastUserQuery ?? "<none>")")
            print("Prompt/context: \(buildConversationPromptFromMessages())")
            addSystemMessage("I encountered an issue processing that. Please check your network connection or try again later.")
        }
        isProcessing = false
    }
    
    /// Builds a prompt string from the full conversation history, including all user and assistant messages.
    private func buildConversationPromptFromMessages() -> String {
        // Add a concise, identity-specific instruction to the prompt
        let identityInstruction: String
        switch selectedPersonality {
        case .friend:
            identityInstruction = "Answer as a supportive, enthusiastic, and casual male friend. Be warm, expressive, and positive. Use friendly language, show genuine interest, and respond as a real friend would. Remember our previous conversation and build on it naturally. Limit your answer to no more than 2 sentences. Never say you will search, check, or get back to the user. Always provide a direct answer, or say you don't know. Do not promise to follow up later. Always attempt to answer the user's question as best you can, using your knowledge and any available context. Only say you don't know if you truly cannot provide any answer."
        case .mentor:
            identityInstruction = "Answer as a wise mentor. Be concise, clear, and insightful. Remember our previous conversation and provide guidance that builds on earlier discussions. Limit your answer to no more than 2 sentences. Never say you will search, check, or get back to the user. Always provide a direct answer, or say you don't know. Do not promise to follow up later. Always attempt to answer the user's question as best you can, using your knowledge and any available context. Only say you don't know if you truly cannot provide any answer."
        case .debator:
            identityInstruction = "Answer as a logical debater. Be concise, clear, and challenging. Remember our previous conversation and continue the debate with context from earlier exchanges. Limit your answer to no more than 2 sentences. Never say you will search, check, or get back to the user. Always provide a direct answer, or say you don't know. Do not promise to follow up later. Always attempt to answer the user's question as best you can, using your knowledge and any available context. Only say you don't know if you truly cannot provide any answer."
        }
        
        let cassPrompt = (personalityPrompts[selectedPersonality] ?? "You are C.A.S.S., an AI assistant.")
        var prompt = identityInstruction + "\n" + cassPrompt + "\n\n"
        
        // Include conversation history with better context management
        let maxMessages = 4 // Reduced from 6 to further lower token costs
        let recentMessages = Array(messages.suffix(maxMessages))
        
        // If we have a very long conversation, create a summary of earlier parts
        if messages.count > maxMessages + 10 {
            let earlierMessages = Array(messages.dropLast(maxMessages))
            let summary = createConversationSummary(from: earlierMessages)
            prompt += "Earlier conversation summary: \(summary)\n\n"
        }
        
        // Add conversation context
        if recentMessages.count > 2 {
            prompt += "Previous conversation context:\n"
            for message in recentMessages.dropLast(2) { // Include all but the last 2 messages as context
                if message.isUser {
                    prompt += "User: \(message.content)\n"
                } else {
                    prompt += "CASS: \(message.content)\n"
                }
            }
            prompt += "\n"
        }
        
        // Add the current exchange
        if let lastUserMessage = messages.last(where: { $0.isUser }) {
            prompt += "User: \(lastUserMessage.content)\n"
        }
        
        prompt += "CASS:"
        return prompt
    }
    
    /// Creates a summary of earlier conversation messages to maintain context
    private func createConversationSummary(from messages: [ChatMessage]) -> String {
        let userMessages = messages.filter { $0.isUser }.map { $0.content }
        let aiMessages = messages.filter { !$0.isUser }.map { $0.content }
        
        var summary = "User has discussed: "
        if userMessages.count > 0 {
            let topics = userMessages.prefix(3).joined(separator: ", ")
            summary += topics
            if userMessages.count > 3 {
                summary += " and other topics"
            }
        }
        
        summary += ". CASS has provided responses about: "
        if aiMessages.count > 0 {
            let responses = aiMessages.prefix(2).joined(separator: ", ")
            summary += responses
            if aiMessages.count > 2 {
                summary += " and other guidance"
            }
        }
        
        return summary
    }
    
    private func geminiChatCompletion(prompt: String, retryCount: Int = 0) async throws -> String {
        guard isConnected else {
            print("Network Error: No connection available")
            throw NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No network connection"])
        }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(geminiApiKey)") else {
            print("Gemini: Invalid URL")
            throw NSError(domain: "URLError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini API URL"])
        }
        print("Setting up Gemini API request...")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "maxOutputTokens": 80,
                "temperature": 0.6
            ]
        ]
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            request.httpBody = jsonData
            print("Request body prepared for Gemini")
        } catch {
            print("JSON Serialization Error: \(error)")
            throw error
        }
        print("Sending request to Gemini API...")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Response Error: Not an HTTP response")
                throw NSError(domain: "HTTPError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
            }
            print("Gemini response status code: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                let responseString = String(data: data, encoding: .utf8) ?? "<no data>"
                print("Gemini error response: \(responseString)")
                throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Gemini API request failed with status \(httpResponse.statusCode) - see console for details"])
            }
            // Print the raw response for debugging
            print("Raw response: \(String(data: data, encoding: .utf8) ?? "<non-utf8 data>")")
            // Parse Gemini response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let first = candidates.first,
               let content = first["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                return formatResponse(text)
            }
            print("Gemini: Could not parse response JSON: \(String(data: data, encoding: .utf8) ?? "<no data>")")
            return "Sorry, I couldn't understand the response from Gemini."
        } catch {
            // Retry on network error
            if error is URLError, retryCount < 2 {
                print("Gemini API network error, retrying (", retryCount+1, ")...")
                return try await geminiChatCompletion(prompt: prompt, retryCount: retryCount + 1)
            }
            print("Gemini API Request Error: \(error)")
            throw error
        }
    }
    
    private func formatResponse(_ text: String) -> String {
        var response = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove bullet points and extra formatting
        response = response.replacingOccurrences(of: "\n- ", with: " ")
        response = response.replacingOccurrences(of: "\n• ", with: " ")
        response = response.replacingOccurrences(of: "\n* ", with: " ")
        response = response.replacingOccurrences(of: "\n", with: " ")
        // Remove asterisks
        response = response.replacingOccurrences(of: "*", with: "")
        // Remove emojis (by removing all characters in the unicode emoji range)
        response = response.filter { !$0.isEmoji }
        // Remove common filler phrases
        let fillers = ["Sure! ", "Of course! ", "Absolutely! ", "Here's what I found: ", "Let me explain: ", "Let me help you with that. ", "Here's the answer: ", "Here's what you need to know: "]
        for filler in fillers {
            if response.hasPrefix(filler) {
                response = String(response.dropFirst(filler.count))
            }
        }
        // Remove any leading or trailing punctuation or whitespace
        response = response.trimmingCharacters(in: .whitespacesAndNewlines)
        // Post-processing filter for vague promises
        let forbiddenPhrases = [
            "let me do a quick search",
            "let me get back to you",
            "let me check",
            "let me get you a list",
            "i'll get back to you"
        ]
        for phrase in forbiddenPhrases {
            if response.lowercased().contains(phrase) {
                response = "I don't have that information right now, but I can help with something else!"
                break
            }
        }
        // Keep only the first two sentences
        let sentenceEndings = CharacterSet(charactersIn: ".!?")
        var sentences: [String] = []
        var currentSentence = ""
        for char in response {
            currentSentence.append(char)
            if sentenceEndings.contains(char.unicodeScalars.first!) {
                sentences.append(currentSentence.trimmingCharacters(in: .whitespacesAndNewlines))
                currentSentence = ""
                if sentences.count == 2 { break }
            }
        }
        if !currentSentence.isEmpty && sentences.count < 2 {
            sentences.append(currentSentence.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        response = sentences.joined(separator: " ")
        if !response.isEmpty && !response.hasSuffix(".") && !response.hasSuffix("!") && !response.hasSuffix("?") {
            response += "."
        }
        if response.isEmpty {
            response = "I'm sorry, I don't have an answer for that."
        }
        return response
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // No automatic restart for press-to-talk model
    }
    
    @MainActor
    private func addSystemMessage(_ content: String) {
        let message = ChatMessage(content: content, isUser: false)
        messages.append(message)
        speakResponse(content)
    }
    
    // Call this when the chat view appears
    func startAudioSession() {
        #if os(iOS)
        DispatchQueue.global().async {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .defaultToSpeaker])
                try audioSession.setActive(true)
            } catch {
                print("Failed to start audio session: \(error)")
            }
        }
        #endif
    }

    // Call this when the chat view disappears
    func stopAudioSession() {
        #if os(iOS)
        DispatchQueue.global().async {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("Failed to stop audio session: \(error)")
            }
        }
        #endif
    }

    private func speakResponse(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        switch selectedPersonality {
        case .friend:
            // Default Apple voice (en-US)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.48
            utterance.pitchMultiplier = 0.98
        case .mentor:
            // British English male, deep and wise (Daniel)
            if let daniel = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Daniel-compact") {
                utterance.voice = daniel
            } else {
                utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
            }
            utterance.rate = 0.44
            utterance.pitchMultiplier = 0.88
        case .debator:
            // US English male, deep and friendly (Tom)
            if let tom = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Tom-compact") {
                utterance.voice = tom
            } else {
                utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            }
            utterance.rate = 0.48
            utterance.pitchMultiplier = 0.98
        }
        synthesizer.speak(utterance)
    }
    
    // Helper to detect if a query should use search
    private func shouldUseSearch(for text: String) -> Bool {
        let keywords = [
            "find", "search", "address", "current", "news", "who is", "where is", "when is", "what is", "what time", "when", "time", "today", "latest", "open now", "hours", "weather", "price", "cost", "stock", "definition", "meaning", "location", "directions", "review", "restaurant", "hotel", "flight", "event", "score", "result", "headline", "update", "game", "sports", "schedule"
        ]
        let lowercased = text.lowercased()
        return keywords.contains { lowercased.contains($0) }
    }
    
    // Tavily search function
    private func tavilySearch(query: String, retryCount: Int = 0) async throws -> String {
        guard isConnected else {
            print("Network Error: No connection available")
            throw NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No network connection"])
        }
        guard let url = URL(string: "https://api.tavily.com/search") else {
            print("URL Error: Invalid Tavily API URL")
            throw NSError(domain: "URLError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid Tavily API URL"])
        }
        print("Setting up Tavily API request...")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(tavilyApiKey)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "query": query,
            "search_depth": "advanced",
            "max_results": 5,
            "include_answer": true
        ]
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            request.httpBody = jsonData
            print("Request body prepared for Tavily")
        } catch {
            print("JSON Serialization Error: \(error)")
            throw error
        }
        print("Sending request to Tavily API...")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Response Error: Not an HTTP response")
                throw NSError(domain: "HTTPError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
            }
            print("Tavily response status code: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Tavily error response: \(responseString)")
                }
                throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Tavily API request failed with status \(httpResponse.statusCode) - see console for details"])
            }
            // Parse Tavily response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let answer = json["answer"] as? String {
                return formatResponse(answer)
            }
            print("Tavily: Could not parse response JSON: \(String(data: data, encoding: .utf8) ?? "<no data>")")
            return "Sorry, I couldn't understand the response from Tavily."
        } catch {
            // Retry on network error
            if error is URLError, retryCount < 2 {
                print("Tavily API network error, retrying (", retryCount+1, ")...")
                return try await tavilySearch(query: query, retryCount: retryCount + 1)
            }
            print("Tavily API Request Error: \(error)")
            throw error
        }
    }
    
    func setPersonality(_ personality: Personality) {
        // Stop any ongoing speech immediately when switching identity
        synthesizer.stopSpeaking(at: .immediate)
        DispatchQueue.main.async {
            self.selectedPersonality = personality
            // Clear chat history and add a new welcome message for the new personality
            self.messages.removeAll()
            let welcome = self.personalityWelcomeMessages[personality] ?? "Hey! What's on your mind?"
            let welcomeMessage = ChatMessage(content: welcome, isUser: false)
            self.messages.append(welcomeMessage)
        }
    }
    
    enum Personality: String, CaseIterable, Identifiable {
        case friend = "Friend 🧑‍🤝‍🧑"
        case mentor = "Mentor 🧑‍🏫"
        case debator = "Debator 🤺"
        var id: String { rawValue }
    }
    
    private func isLocationQuery(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return locationKeywords.contains { lowercased.contains($0) }
    }
}

struct FollowUpQuestion: Identifiable {
    let id = UUID()
    let text: String
}

extension Character {
    var isEmoji: Bool {
        unicodeScalars.contains { $0.properties.isEmoji && ($0.value > 0x238C || $0.value == 0x00A9 || $0.value == 0x00AE || $0.value == 0x203C || $0.value == 0x2049 || $0.value == 0x2122 || $0.value == 0x2139 || ($0.value >= 0x2194 && $0.value <= 0x21FF) || ($0.value >= 0x2300 && $0.value <= 0x23FF) || ($0.value >= 0x25A0 && $0.value <= 0x27BF) || ($0.value >= 0x2B05 && $0.value <= 0x2BFF) || ($0.value >= 0x2934 && $0.value <= 0x2935) || ($0.value >= 0x3297 && $0.value <= 0x3299)) }
    }
} 
