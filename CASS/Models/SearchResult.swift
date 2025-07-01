import Foundation

struct SearchResult: Identifiable, Codable {
    let title: String
    let url: String
    let content: String
    let score: Double?
    
    var id: String { url }
} 