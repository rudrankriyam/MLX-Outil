import Foundation

/// Represents the current state of parsing tool calls in the LLM response
enum ToolCallParsingState {

    /// No tool call is currently being parsed
    case idle

    /// Currently buffering text that may contain a partial tool call JSON
    case buffering(String)
}
