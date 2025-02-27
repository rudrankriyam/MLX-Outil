import Foundation

/// Registry for tool types and their argument handlers
public class ToolRegistry {
    /// Shared instance of the registry
    public static let shared = ToolRegistry()
    
    /// Dictionary mapping tool type identifiers to their handlers
    private var handlers: [String: any ToolHandlerProtocol] = [:]
    
    private init() {}
    
    /// Register a handler for a specific tool type
    /// - Parameters:
    ///   - toolType: The tool type to handle
    ///   - handler: The handler for the tool
    public func register<T: ToolCallTypeProtocol>(
        toolType: T,
        handler: any ToolHandlerProtocol
    ) {
        handlers[toolType.rawValue] = handler
    }
    
    /// Get the handler for a specific tool type
    /// - Parameter identifier: The identifier of the tool
    /// - Returns: The handler for the tool, if registered
    public func handler(for identifier: String) -> (any ToolHandlerProtocol)? {
        return handlers[identifier]
    }
    
    /// Protocol for tool handlers
    public protocol ToolHandlerProtocol {
        /// Handle a tool call with arguments
        /// - Parameter json: The JSON representing the arguments
        /// - Returns: The result of handling the tool call
        func handle(json: Data) async throws -> String
    }
}
