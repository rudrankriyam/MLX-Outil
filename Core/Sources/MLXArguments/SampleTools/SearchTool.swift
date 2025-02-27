import Foundation

/// Search tool type
public enum SearchToolType: String, ToolCallTypeProtocol {
    case searchDuckDuckGo = "search_duckduckgo"
    
    public var displayName: String {
        switch self {
        case .searchDuckDuckGo:
            return "Search DuckDuckGo"
        }
    }
    
    public var description: String {
        switch self {
        case .searchDuckDuckGo:
            return "Searches the web using DuckDuckGo"
        }
    }
}

/// Arguments for search tools
public struct SearchArguments: ArgumentProtocol {
    public typealias ToolType = SearchToolType
    
    public let toolType: SearchToolType
    public let query: String
    
    public init(toolType: SearchToolType = .searchDuckDuckGo, query: String) {
        self.toolType = toolType
        self.query = query
    }
}

/// Search tool handler
public class SearchToolHandler: ToolRegistry.ToolHandlerProtocol {
    private let searchService: SearchServiceProtocol
    
    public init(searchService: SearchServiceProtocol) {
        self.searchService = searchService
    }
    
    public func handle(json: Data) async throws -> String {
        let decoder = JSONDecoder()
        let arguments = try decoder.decode(SearchArguments.self, from: json)
        
        return try await searchService.search(query: arguments.query)
    }
}

/// Protocol for search services
public protocol SearchServiceProtocol {
    func search(query: String) async throws -> String
}
