import Foundation

struct TavilyResponse: Codable {
    let answer: String?
    let results: [SearchResult]
} 