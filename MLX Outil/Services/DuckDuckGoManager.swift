import Foundation

class DuckDuckGoManager {
  static let shared = DuckDuckGoManager()

  private init() {}

  func search(query: String) async throws -> String {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "api.duckduckgo.com"
    components.queryItems = [
      URLQueryItem(name: "q", value: query),
      URLQueryItem(name: "format", value: "json"),
      URLQueryItem(name: "no_html", value: "1"),
      URLQueryItem(name: "skip_disambig", value: "1"),
    ]

    guard let url = components.url else {
      throw SearchError.invalidURL
    }

    let (data, _) = try await URLSession.shared.data(from: url)
    let response = try JSONDecoder().decode(SearchResponse.self, from: data)

    return formatResponse(response)
  }

  private func formatResponse(_ response: SearchResponse) -> String {
    var result = ""

    if !response.AbstractText.isEmpty {
      result += "Abstract:\n\(response.AbstractText)\n\n"
    }

    if !response.RelatedTopics.isEmpty {
      result += "Related Topics:\n"
      for topic in response.RelatedTopics.prefix(3) {
        if !topic.Text.isEmpty {
          result += "- \(topic.Text)\n"
        }
      }
    }

    if result.isEmpty {
      return "No results found."
    }

    return result
  }
}

struct SearchResponse: Codable {
  let AbstractText: String
  let RelatedTopics: [Topic]

  struct Topic: Codable {
    let Text: String
  }
}

enum SearchError: Error {
  case invalidURL
  case noResults
}
