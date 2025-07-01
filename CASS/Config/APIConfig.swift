import Foundation

enum APIConfig {
    static let tavilyAPIKey = "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"
    
    // For development/testing only
    static let isDevelopment = true
    
    static var tavilyKey: String {
        return tavilyAPIKey
    }
} 