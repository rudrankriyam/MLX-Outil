import Foundation
import os

/// Protocol for handling tool calls
public protocol ToolCallHandlerProtocol {
    /// Process a raw text output from the LLM
    /// - Parameter text: The text from the LLM
    /// - Returns: The result from processing any tool calls
    func processLLMOutput(_ text: String) async throws -> String
}

/// Base implementation of a tool call handler
open class BaseToolCallHandler: ToolCallHandlerProtocol {
    private var toolCallBuffer: String = ""
    private let decoder = JSONDecoder()
    private let logger = Logger(subsystem: "com.mlx.outil", category: "ToolCallHandler")
    
    public init() {}
    
    /// Process LLM output for tool calls
    /// - Parameter text: The text output from the LLM
    /// - Returns: Result from any processed tool calls
    open func processLLMOutput(_ text: String) async throws -> String {
        logger.debug("Processing LLM output: \(text)")
        
        if text.contains("<|python_tag|>") {
            logger.debug("Detected Llama format, handling accordingly")
            return try await handleLlamaFormat(text)
        }
        
        var tokenText = text
        if tokenText.hasPrefix("<tool_call>") {
            logger.debug("Found tool_call prefix, removing it")
            tokenText = tokenText.replacingOccurrences(
                of: "<tool_call>", with: "")
        }
        
        logger.debug("Adding to buffer: \(tokenText)")
        toolCallBuffer += tokenText
        
        if toolCallBuffer.contains("</tool_call>") {
            logger.info("Complete tool call received, processing")
            toolCallBuffer = toolCallBuffer.replacingOccurrences(
                of: "</tool_call>", with: "")
            let jsonString = toolCallBuffer.trimmingCharacters(
                in: .whitespacesAndNewlines)
            
            logger.debug("Processing JSON string: \(jsonString)")
            let result = try await handleToolCall(jsonString)
            logger.debug("Tool call processed successfully with result: \(result)")
            
            toolCallBuffer = ""
            return result
        }
        
        return text
    }
    
    /// Extract tool call from Llama format
    /// - Parameter text: The text in Llama format
    open func handleLlamaFormat(_ text: String) async throws -> String {
        logger.debug("Handling Llama format for text: \(text)")
        
        guard let startRange = text.range(of: "<|python_tag|>"),
              let endRange = text.range(of: "<|eom_id|>") else {
            logger.error("Invalid Llama format: missing required tags")
            throw ToolCallError.invalidArguments
        }
        
        let startIndex = startRange.upperBound
        let endIndex = endRange.lowerBound
        
        let jsonString = String(text[startIndex..<endIndex])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        logger.debug("Extracted JSON from Llama format: '\(jsonString)'")
        
        return try await handleToolCall(jsonString)
    }
    
    /// Handle parsed JSON tool call
    /// - Parameter jsonString: The JSON string representing the tool call
    /// - Returns: Result of processing the tool call
    open func handleToolCall(_ jsonString: String) async throws -> String {
        // Override this method in subclasses to handle specific tool calls
        throw ToolCallError.notImplemented
    }
}

/// Errors that can occur during tool call processing
public enum ToolCallError: Error, Equatable {
    case invalidJSON
    case invalidArguments
    case unknownTool(String)
    case notImplemented
}
