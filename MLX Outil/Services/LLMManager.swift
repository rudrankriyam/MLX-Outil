import HealthKit
import SwiftUI
import MLXLMCommon
import MLXLLM
import MLX
import Tokenizers

@MainActor
@Observable
class LLMManager {

    var running = false
    var output = ""
    var modelInfo = ""
    var stat = ""

    private var toolCallProcessor = ToolCallProcessor()
    private let toolManager = ToolManager.shared
    
    init() {}

    // Tool-specific properties
    private var pendingToolCalls: [ToolCall] = []

    private let modelConfiguration = LLMRegistry.qwen3_1_7b_4bit

    var availableTools: [ToolSpec] {
        toolManager.toolSchemas
    }

    func generate(prompt: String, includingTools: Bool = true) async {
        guard !running else { return }

        running = true
        self.output = ""
        self.pendingToolCalls = []
        
        // Reset the tool call processor for new generation
        let newProcessor = ToolCallProcessor()
        self.toolCallProcessor = newProcessor

        do {
            let messages: [Chat.Message] = [
                .system(Constants.systemPrompt),
                .user(prompt)
            ]

            let userInput = UserInput(
                chat: messages,
                tools: includingTools ? availableTools : []
            )

            do {
                let modelContainer = try await load()

                // each time you generate you will get something new
                MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

                try await modelContainer.perform { (context: ModelContext) -> Void in
                    let lmInput = try await context.processor.prepare(input: userInput)
                    let stream = try MLXLMCommon.generate(
                        input: lmInput, parameters: .init(), context: context)

                    for await batch in stream {
                        if let chunk = batch.chunk {
                            // Process chunk through ToolCallProcessor
                            if let processedText = await toolCallProcessor.processChunk(chunk) {
                                Task { @MainActor [processedText] in
                                    self.output += processedText
                                }
                            }
                            
                            // Check if we have any tool calls to execute
                            let currentToolCalls = await toolCallProcessor.toolCalls
                            if !currentToolCalls.isEmpty {
                                Task { @MainActor in
                                    for toolCall in currentToolCalls {
                                        if !self.pendingToolCalls.contains(toolCall) {
                                            self.pendingToolCalls.append(toolCall)
                                            
                                            // Execute the tool call
                                            do {
                                                let result = try await self.toolManager.execute(toolCall: toolCall)
                                                self.output += "\n\n<tool_result>\n" + result + "\n</tool_result>\n\n"
                                                
                                                // Continue conversation with tool result
                                                await self.continueWithToolResult(result, for: toolCall.function.name)
                                            } catch {
                                                self.output += "\n\n<tool_error>\nError executing tool: \(error)\n</tool_error>\n\n"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } catch {
                output = "Failed: \(error)"
            }

            running = false
        }
    }
    
    private func continueWithToolResult(_ result: String, for toolName: String) async {
        let context = switch toolName {
        case "get_weather_data": "weather"
        case "get_workout_summary": "workout"
        case "search_duckduckgo": "search"
        default: "data"
        }
        
        let followUpPrompt = "Based on the \(context) data above, please provide a helpful analysis and recommendations."
        
        // Create a new generation with the tool result in context
        let messages: [Chat.Message] = [
            .system(Constants.systemPrompt),
            .assistant(output + "\n<tool_result>\n" + result + "\n</tool_result>"),
            .user(followUpPrompt)
        ]
        
        let userInput = UserInput(
            chat: messages,
            tools: [] // No tools for follow-up
        )
        
        do {
            let modelContainer = try await load()
            
            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))
            
            try await modelContainer.perform { (context: ModelContext) -> Void in
                let lmInput = try await context.processor.prepare(input: userInput)
                let stream = try MLXLMCommon.generate(
                    input: lmInput, parameters: .init(), context: context)
                
                for await batch in stream {
                    if let chunk = batch.chunk {
                        Task { @MainActor [chunk] in
                            self.output += chunk
                        }
                    }
                }
            }
        } catch {
            Task { @MainActor in
                self.output += "\n\nError in follow-up: \(error)\n"
            }
        }
    }

    
    func load() async throws -> ModelContainer {
        let modelContainer = try await LLMModelFactory.shared.loadContainer(
            configuration: modelConfiguration) { _ in }
        
        return modelContainer
    }
}

