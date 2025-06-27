import Foundation
import os.log

@MainActor
public class DuckDuckGoManager {
    public static let shared = DuckDuckGoManager()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MLXTools",
        category: "DuckDuckGo")

    public init() {
        logger.info("DuckDuckGoManager initialized")
    }

    public func search(query: String) async throws -> String {
        logger.debug("Starting search with query: \(query)")

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.duckduckgo.com"
        components.path = "/"
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "no_html", value: "1"),
            URLQueryItem(name: "skip_disambig", value: "1"),
            URLQueryItem(name: "t", value: "MLXTools"),
            URLQueryItem(name: "pretty", value: "1"),  // Adding pretty parameter
        ]

        guard let url = components.url else {
            logger.error("Failed to construct URL for query: \(query)")
            throw SearchError.invalidURL
        }

        logger.debug("Fetching data from URL: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.setValue("MLXTools/1.0", forHTTPHeaderField: "User-Agent")  // Adding a User-Agent header

        do {
            let (data, response) = try await URLSession.shared.data(
                for: request)

            if let httpResponse = response as? HTTPURLResponse {
                logger.debug(
                    "Received response with status code: \(httpResponse.statusCode)"
                )

                if httpResponse.statusCode != 200 {
                    throw SearchError.apiError(
                        statusCode: httpResponse.statusCode)
                }
            }

            if let jsonString = String(data: data, encoding: .utf8) {
                logger.debug("Raw response: \(jsonString)")
            }

            let searchResponse = try JSONDecoder().decode(
                SearchResponse.self, from: data)

            // Check if we got any meaningful content
            if searchResponse.AbstractText.isEmpty
                && searchResponse.RelatedTopics.isEmpty
            {
                logger.warning("Empty response received from API")
                throw SearchError.noResults
            }

            logger.debug(
                "Decoded response - Abstract: '\(searchResponse.AbstractText)', Topics count: \(searchResponse.RelatedTopics.count)"
            )
            return formatResponse(searchResponse)
        } catch let decodingError as DecodingError {
            logger.error("Decoding failed: \(decodingError)")
            throw decodingError
        } catch {
            logger.error("Search request failed: \(error.localizedDescription)")
            throw error
        }
    }

    private func formatResponse(_ response: SearchResponse) -> String {
        logger.debug(
            "Formatting response with abstract length: \(response.AbstractText.count) and \(response.RelatedTopics.count) related topics"
        )

        var result = ""

        if !response.AbstractText.isEmpty {
            result += "Abstract:\n\(response.AbstractText)\n\n"
        } else {
            logger.info("No abstract text in response")
        }

        if !response.RelatedTopics.isEmpty {
            result += "Related Topics:\n"
            for (index, topic) in response.RelatedTopics.prefix(3).enumerated()
            {
                logger.debug("Processing topic \(index + 1): '\(topic.Text)'")
                if !topic.Text.isEmpty {
                    result += "- \(topic.Text)\n"
                } else {
                    logger.info(
                        "Empty topic text encountered for topic \(index + 1)")
                }
            }
        } else {
            logger.info("No related topics in response")
        }

        if result.isEmpty {
            logger.warning("No content found in search response")
            return "No results found."
        }

        return result
    }
}

public struct SearchResponse: Codable {
    public let AbstractText: String
    public let RelatedTopics: [Topic]

    public struct Topic: Codable {
        public let Text: String
    }
}

public enum SearchError: Error {
    case invalidURL
    case noResults
    case apiError(statusCode: Int)
}