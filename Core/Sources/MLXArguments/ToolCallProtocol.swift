import Foundation
import os

/// Protocol to define a tool call type
public protocol ToolCallTypeProtocol: RawRepresentable, Codable, Hashable, CaseIterable where RawValue == String {
    /// Get a user-friendly name for this tool type
    var displayName: String { get }
    
    /// Get a description of what this tool does
    var description: String { get }
}

/// Protocol that any argument for a tool must conform to
public protocol ArgumentProtocol: Codable, Sendable {
    /// The tool type that can use this argument
    associatedtype ToolType: ToolCallTypeProtocol
    
    /// The tool type that this argument is for
    var toolType: ToolType { get }
}

/// Generic tool call that can be used with any argument type
public struct ToolCall<T: ArgumentProtocol>: Codable {
    /// The name/type of the tool
    public let name: T.ToolType
    
    /// The arguments for the tool
    public let arguments: T
    
    public init(name: T.ToolType, arguments: T) {
        self.name = name
        self.arguments = arguments
    }
}
