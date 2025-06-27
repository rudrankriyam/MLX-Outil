import HealthKit
import MLXTools
import MLX
import MLXLLM
import MLXLMCommon
import SwiftUI
import Tokenizers
import os

@MainActor
@Observable
class LLMManager {

    var running = false
    var output = ""
    var modelInfo = ""
    var stat = ""

    // Conversation history
    private var chatHistory: [Chat.Message] = [.system(Constants.systemPrompt)]

    private let toolManager = ToolManager.shared
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MLXOutil", category: "LLMManager")

    init() {
        logger.info("LLMManager initialized")
    }

    private let modelConfiguration = LLMRegistry.qwen3_1_7b_4bit
    private let generateParameters = GenerateParameters(maxTokens: 4097, temperature: 0.6)

    var availableTools: [ToolSpec] {
        let schemas = toolManager.toolSchemas
        logger.debug("LLMManager availableTools called, returning \(schemas.count) schemas")
        return schemas
    }

    func generate(prompt: String, includingTools: Bool = true) async {
        guard !running else {
            logger.warning("Generate called while already running")
            return
        }

        // Add user message to history
        chatHistory.append(.user(prompt))

        await performGeneration(
            prompt: prompt, toolResult: nil, includingTools: includingTools, isNewUserMessage: true)
    }

    private func performGeneration(
        prompt: String, toolResult: String?, includingTools: Bool, isNewUserMessage: Bool = false
    ) async {
        logger.info(
            "Starting generation with prompt: \(prompt), toolResult: \(toolResult != nil ? "present" : "nil"), includingTools: \(includingTools)"
        )

        running = true

        // Only clear output for new user messages
        if isNewUserMessage {
            self.output = ""
        }

        do {
            var messages = chatHistory

            if let toolResult = toolResult {
                messages.append(.tool(toolResult))
            }

            let tools = includingTools ? availableTools : []
            logger.info("Available tools count: \(tools.count)")
            for tool in tools {
                logger.debug("Tool: \(tool)")
            }

            let userInput = UserInput(
                chat: messages,
                tools: tools
            )

            logger.info("Loading model container")
            let modelContainer = try await load()
            logger.info("Model container loaded successfully")

            // each time you generate you will get something new
            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

            try await modelContainer.perform { (context: ModelContext) -> Void in
                let lmInput = try await context.processor.prepare(input: userInput)
                let stream = try MLXLMCommon.generate(
                    input: lmInput, parameters: generateParameters, context: context)

                // generate and output
                for await generation in stream {
                    if let chunk = generation.chunk {
                        await Task { @MainActor [chunk] in
                            self.logger.debug("Adding output chunk: '\(chunk)'")
                            self.output += chunk
                        }.value
                    }

                    if let info = generation.info {
                        await Task { @MainActor in
                            self.stat = "\(info.tokensPerSecond) tokens/s"
                        }.value
                    }

                    if let toolCall = generation.toolCall {
                        await Task { @MainActor in
                            self.logger.info("Tool call detected: \(toolCall.function.name)")
                            self.logger.debug("Tool call arguments: \(toolCall.function.arguments)")

                            // Save current output to history before tool call
                            if !self.output.isEmpty {
                                self.chatHistory.append(.assistant(self.output))
                            }

                            // Show tool call in output
                            self.output += "\n\n`Calling tool: \(toolCall.function.name)`\n"
                        }.value

                        // Handle the tool call
                        try await handleToolCall(toolCall, prompt: prompt)
                        // Exit this generation as we'll start a new one with the tool result
                        return
                    }
                }

                await Task { @MainActor in
                    // Save assistant response to history
                    self.chatHistory.append(.assistant(self.output))
                    self.logger.info("Generation completed without tool calls")
                    self.logger.info("Final output length: \(self.output.count)")
                    self.logger.info("Chat history length: \(self.chatHistory.count)")
                }.value
            }
        } catch {
            logger.error("Generation failed: \(error)")
            output = "Failed: \(error)"
        }

        running = false
    }

    private func handleToolCall(_ toolCall: ToolCall, prompt: String) async throws {
        logger.info("Handling tool call: \(toolCall.function.name)")

        do {
            let result = try await toolManager.execute(toolCall: toolCall)
            logger.info("Tool execution successful, result: \(result)")

            // Show tool result in output
            await Task { @MainActor in
                self.output += "\n`Tool result received`\n\n---\n\n"
            }.value

            // Continue conversation with tool result
            await performGeneration(
                prompt: prompt, toolResult: result, includingTools: false, isNewUserMessage: false)
        } catch {
            logger.error("Tool execution failed: \(error)")
            await performGeneration(
                prompt: prompt,
                toolResult: "Tool execution failed: \(error.localizedDescription)",
                includingTools: false,
                isNewUserMessage: false
            )
        }
    }

    func load() async throws -> ModelContainer {
        let modelContainer = try await LLMModelFactory.shared.loadContainer(
            configuration: modelConfiguration
        ) { _ in }

        return modelContainer
    }

    // Clear conversation history
    func clearHistory() {
        chatHistory = [.system(Constants.systemPrompt)]
        output = ""
        logger.info("Conversation history cleared")
    }
}
