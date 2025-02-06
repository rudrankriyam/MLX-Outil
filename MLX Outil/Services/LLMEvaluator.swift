// Copyright 2024 Apple Inc.

import Foundation
import HealthKit
import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import Metal
import Tokenizers

@Observable
@MainActor
class LLMEvaluator {

    var running = false

    var includeWeatherTool = false
    var includeHealthTool = false

    var output = ""
    var modelInfo = ""
    var stat = ""

    var toolCallState: ToolCallParsingState = .idle
    var loadState = LoadState.idle

    let modelConfiguration = ModelRegistry.qwen2_5_1_5b

    let generateParameters = GenerateParameters(temperature: 0.5)

    enum LoadState {
        case idle
        case loaded(ModelContainer)
    }

    let healthToolSpec: [String: any Sendable] =
        [
            "type": "function",
            "function": [
                "name": "get_workout_summary",
                "description": "Get a summary of workouts for this week",
                "parameters": [
                    "type": "object",
                    "properties": [],
                    "required": [],
                ] as [String: any Sendable],
            ] as [String: any Sendable],
        ] as [String: any Sendable]

    private let healthManager = HealthKitManager.shared

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

    func fetchHealthData(date: String) async throws -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        guard let queryDate = dateFormatter.date(from: date) else {
            return "Invalid date format. Please use YYYY-MM-DD format."
        }

        let workouts = try await healthManager.fetchWorkouts(
            for: .day(queryDate))
        if workouts.isEmpty {
            return "No workouts found for \(date)."
        }

        return formatWorkoutSummary(
            workouts, title: "Workout Summary for \(date):")
    }

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
                    print(
                        "Processing buffered JSON: \(jsonString)"
                    )  // Debug print
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

    /// Clean up and parse the tool call JSON.
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
                if name == "get_workout_summary" {
                    let workoutSummary = try await fetchWorkoutData()
                    await continueConversation(with: workoutSummary)
                }
            }
        } catch {
            print("Error parsing tool call JSON: \(error)")
            self.output +=
                "\nError parsing tool call: \(error.localizedDescription)\n"
        }
    }

    func fetchWorkoutData() async throws -> String {
        let workouts = try await healthManager.fetchWorkouts(for: .week(Date()))
        if workouts.isEmpty {
            return "No workouts found for this week."
        }

        return formatWeeklyWorkoutSummary(workouts)
    }

    func generationDidComplete() async {
        if case .buffering(let currentBuffer) = toolCallState {
            print("Generation complete with remaining buffer: \(currentBuffer)")
            let trimmedBuffer = currentBuffer.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if !trimmedBuffer.isEmpty {
                await handleToolCall(trimmedBuffer)
            }
            toolCallState = .idle
        }
    }

    func continueConversation(with healthData: String) async {
        let followUpPrompt =
            "The health data is: \(healthData). Now you are a fitness coach. Please explain the data"
        running = false

        await generateFinal(prompt: followUpPrompt)
    }

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
                                    "You are a helpful assistant with access to health data.",
                            ],
                            ["role": "user", "content": prompt],
                        ], tools: [healthToolSpec]))

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
                                    "You are a helpful assistant with access to health data.",
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

// MARK: - Supporting Types

private struct ToolCall: Codable {
    let name: String
    let arguments: String
}

extension HKWorkoutActivityType {
    fileprivate var name: String {
        switch self {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .hiking: return "Hiking"
        case .crossTraining: return "Cross Training"
        default: return "Other"
        }
    }
}

extension LLMEvaluator {
    fileprivate func formatWorkoutSummary(
        _ workouts: [HKWorkout], title: String
    ) -> String {
        var summary = title + "\n"
        var totalDuration = TimeInterval(0)
        var totalCalories = Double(0)
        var totalDistance = Double(0)

        for workout in workouts {
            let metrics = healthManager.getWorkoutMetrics(workout)
            totalDuration += metrics.duration
            totalCalories += metrics.calories
            totalDistance += metrics.distance

            summary +=
                "\n- \(formatDuration(metrics.duration)), \(Int(metrics.calories)) kcal, \(formatDistance(metrics.distance))"
        }

        summary +=
            "\n\nTotal: \(formatDuration(totalDuration)), \(Int(totalCalories)) kcal, \(formatDistance(totalDistance))"
        return summary
    }

    fileprivate func formatWeeklyWorkoutSummary(_ workouts: [HKWorkout])
        -> String
    {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE"

        var workoutsByDay: [String: [HKWorkout]] = [:]
        for workout in workouts {
            let dayName = dateFormatter.string(from: workout.startDate)
            workoutsByDay[dayName, default: []].append(workout)
        }

        let calendar = Calendar.current
        let sortedDays = workoutsByDay.keys.sorted { day1, day2 in
            let index1 = calendar.component(
                .weekday, from: dateFormatter.date(from: day1) ?? Date())
            let index2 = calendar.component(
                .weekday, from: dateFormatter.date(from: day2) ?? Date())
            return index1 < index2
        }

        var summary = "Workout Summary for this week:"
        for day in sortedDays {
            summary += "\n\n📅 \(day):"
            for workout in workoutsByDay[day] ?? [] {
                let metrics = healthManager.getWorkoutMetrics(workout)
                summary +=
                    "\n- \(formatDuration(metrics.duration)), \(Int(metrics.calories)) kcal, \(formatDistance(metrics.distance))"
            }
        }

        return summary
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "N/A"
    }

    func formatDistance(_ distance: Double) -> String {
        let kilometers = distance / 1000
        return String(format: "%.2f km", kilometers)
    }
}
