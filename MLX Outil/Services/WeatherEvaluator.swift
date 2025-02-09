// Copyright 2024 Apple Inc.

import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import Metal
import Tokenizers
import WeatherKit
import CoreLocation

@Observable
@MainActor
class WeatherEvaluator {
    // Your properties
    var running = false
    var output = ""
    var modelInfo = ""
    var stat = ""

    var toolCallState: ToolCallParsingState = .idle
    var loadState = LoadState.idle

    let modelConfiguration = ModelRegistry.qwen2_5_1_5b
    let generateParameters = GenerateParameters(temperature: 0.5)

    // Weather-specific properties
    private let weatherManager = WeatherKitManager.shared

    enum LoadState {
        case idle
        case loaded(ModelContainer)
    }

    let weatherToolSpec: [String: any Sendable] =
        [
            "type": "function",
            "function": [
                "name": "get_weather_data",
                "description": "Get current weather data for a specific city",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "city": [
                            "type": "string",
                            "description": "The name of the city"
                        ]
                    ],
                    "required": ["city"],
                ] as [String: any Sendable],
            ] as [String: any Sendable],
        ] as [String: any Sendable]

    // Load function remains similar to LLMEvaluator
    func load() async throws -> ModelContainer {
        switch loadState {
        case .idle:
            MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

            let modelContainer = try await LLMModelFactory.shared.loadContainer(
                configuration: modelConfiguration
            ) {
                [modelConfiguration] progress in
                Task { @MainActor in
                    self.modelInfo =
                        "Downloading \(modelConfiguration.name): \(Int(progress.fractionCompleted * 100))%"
                }
            }
            let numParams = await modelContainer.perform { context in
                context.model.numParameters()
            }

            print(
                "Loaded \(modelConfiguration.id).  Weights: \(numParams / (1024*1024))M"
            )
            loadState = .loaded(modelContainer)
            return modelContainer

        case .loaded(let modelContainer):
            return modelContainer
        }
    }

    // Weather-specific functions
    func fetchWeatherData(for city: String) async throws -> String {
        do {
            let weather = try await weatherManager.fetchWeather(forCity: city)
            return formatWeatherData(weather)
        } catch {
            return "Unable to fetch weather data for \(city). Please try again."
        }
    }

    private func formatWeatherData(_ weather: WeatherKitManager.WeatherData) -> String {
        return """
        Current Weather:
        Temperature: \(String(format: "%.1f°C", weather.temperature))
        Condition: \(weather.condition)
        Humidity: \(String(format: "%.0f%%", weather.humidity * 100))
        Wind Speed: \(String(format: "%.1f km/h", weather.windSpeed))
        """
    }

    // Process LLM output similar to LLMEvaluator
    func processLLMOutput(_ text: String) async {
        if text.contains("<tool_call>") {
            switch toolCallState {
            case .idle:
                if let startRange = text.range(of: "<tool_call>") {
                    let afterStart = text[startRange.upperBound...]
                    if let endRange = afterStart.range(of: "</tool_call>") {
                        let jsonString = String(
                            afterStart[..<endRange.lowerBound]
                        )
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "{{", with: "{")
                        .replacingOccurrences(of: "}}", with: "}")
                        .replacingOccurrences(of: "}", with: "}}")
                        .replacingOccurrences(of: "}}}}", with: "}}")
                        print("Processing JSON: \(jsonString)")
                        await handleToolCall(jsonString)
                        toolCallState = .idle
                    } else {
                        toolCallState = .buffering(String(afterStart))
                    }
                }
            case .buffering(let currentBuffer):
                if let endRange = text.range(of: "</tool_call>") {
                    let jsonString =
                        (currentBuffer + String(text[..<endRange.lowerBound]))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "{{", with: "{")
                        .replacingOccurrences(of: "}}", with: "}")
                        .replacingOccurrences(of: "<tool_call>", with: "")
                        .replacingOccurrences(of: "}", with: "}}")
                        .replacingOccurrences(of: "}}}}", with: "}}")
                    print("Processing buffered JSON: \(jsonString)")
                    await handleToolCall(jsonString)
                    toolCallState = .idle
                } else {
                    toolCallState = .buffering(currentBuffer + text)
                }
            }
        } else {
            self.output += text
        }
    }

    @MainActor
    func handleToolCall(_ rawBlock: String) async {
        let cleanedJSON =
            rawBlock
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "<tool_call>", with: "")
            .replacingOccurrences(of: "</tool_call>", with: "")

        if !cleanedJSON.hasPrefix("{") || !cleanedJSON.hasSuffix("}") {
            print("Invalid JSON format: \(cleanedJSON)")
            return
        }

        guard let data = cleanedJSON.data(using: .utf8) else {
            print("Failed to create data from JSON string")
            return
        }

        do {
            if let toolCall = try JSONSerialization.jsonObject(with: data)
                as? [String: Any],
                let name = toolCall["name"] as? String
            {
                print("Successfully parsed tool call with name: \(name)")
                if name == "get_weather_data",
                   let arguments = toolCall["arguments"] as? [String: Any],
                   let city = arguments["city"] as? String {
                    let weatherData = try await fetchWeatherData(for: city)
                    await continueConversation(with: weatherData, for: city)
                }
            }
        } catch {
            print("Error parsing tool call JSON: \(error)")
            self.output +=
                "\nError parsing tool call: \(error.localizedDescription)\n"
        }
    }

    func continueConversation(with weatherData: String, for city: String) async {
        let followUpPrompt =
            "The weather data for \(city) is: \(weatherData). Now you are a weather expert. Please explain the weather conditions and provide recommendations based on this data."
        running = false

        await generateFinal(prompt: followUpPrompt)
    }

    // Generation functions remain similar to LLMEvaluator
    func generate(prompt: String) async {
        guard !running else { return }

        running = true
        self.output = ""

        print("Generating with prompt: \(prompt)")

        do {
            let modelContainer = try await load()

            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

            let result = try await modelContainer.perform { context in
                let input = try await context.processor.prepare(
                    input: .init(
                        messages: [
                            [
                                "role": "system",
                                "content":
                                    "You are a helpful assistant with access to weather data.",
                            ],
                            ["role": "user", "content": prompt],
                        ], tools: [weatherToolSpec]))

                return try MLXLMCommon.generate(
                    input: input, parameters: generateParameters,
                    context: context
                ) { tokens in
                    if tokens.count % 2 == 0 {
                        let text = context.tokenizer.decode(tokens: tokens)
                        Task { @MainActor in
                            print("Text: \(text)")
                        }
                    }
                    return .more
                }
            }
            print("Generated: \(result.output)")
            await processLLMOutput(result.output)
        } catch {
            output = "Failed: \(error)"
        }

        running = false
    }

    func generateFinal(prompt: String) async {
        guard !running else { return }

        running = true
        self.output = ""

        print("Generating with prompt: \(prompt)")

        do {
            let modelContainer = try await load()

            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

            let result = try await modelContainer.perform { context in
                let input = try await context.processor.prepare(
                    input: .init(
                        messages: [
                            [
                                "role": "system",
                                "content":
                                    "You are a helpful assistant with access to weather data.",
                            ],
                            ["role": "user", "content": prompt],
                        ]))
                return try MLXLMCommon.generate(
                    input: input, parameters: generateParameters,
                    context: context
                ) { tokens in
                    if tokens.count % 2 == 0 {
                        let text = context.tokenizer.decode(tokens: tokens)
                        Task { @MainActor in
                            self.output = text
                        }
                    }

                    return .more
                }
            }
            print("Generated: \(result.output)")
        } catch {
            output = "Failed: \(error)"
        }

        running = false
    }
}
