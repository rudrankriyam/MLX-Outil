// Copyright 2024 Apple Inc.

import HealthKit
import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import Metal
import SwiftUI
import Tokenizers

enum ToolCallParsingState {
    case idle  // No tool call currently being parsed.
    case buffering(String)  // Buffering text (partial tool call JSON).
}

struct ContentView: View {
    @State var llm = LLMEvaluator()
    @State var prompt = "What's the current weather in Paris?"

    enum displayStyle: String, CaseIterable, Identifiable {
        case plain, markdown
        var id: Self { self }
    }

    @State private var selectedDisplayStyle = displayStyle.markdown

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                // show the model output
                ScrollView(.vertical) {
                    ScrollViewReader { sp in
                        Group {
                            Text(llm.output)
                                .textSelection(.enabled)
                        }
                        .onChange(of: llm.output) { _, _ in
                            sp.scrollTo("bottom")
                        }

                        Spacer()
                            .frame(width: 1, height: 1)
                            .id("bottom")
                    }
                }

                HStack {
                    TextField(
                        "Ask something about your health data...",
                        text: $prompt
                    )
                    .lineLimit(2, reservesSpace: true)
                    .textFieldStyle(.plain)
                    .onSubmit(generate)
                    .disabled(llm.running)
                    #if os(visionOS)
                        .textFieldStyle(.roundedBorder)
                    #endif

                    Button(action: generate) {
                        Image(systemName: "arrow.up.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.blue)
                    }
                    .disabled(llm.running)
                }
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal)
            }
            #if os(visionOS)
                .padding(40)
            #else
                .padding()
            #endif
            .navigationTitle("HealthSeek")
            .task {
                self.prompt =
                    "Summary of my workouts this week, and how I did in them."
                _ = try? await llm.load()
            }
        }
    }

    private func generate() {
        Task {
            await llm.generate(prompt: prompt)
        }
    }
    private func copyToClipboard(_ string: String) {
        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
        #else
            UIPasteboard.general.string = string
        #endif
    }
}

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
    let modelConfiguration = ModelRegistry.qwen2_5_1_5b

    let generateParameters = GenerateParameters(temperature: 0.5)

    enum LoadState {
        case idle
        case loaded(ModelContainer)
    }

    var loadState = LoadState.idle

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

    let healthStore = HKHealthStore()

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
        guard HKHealthStore.isHealthDataAvailable() else {
            return "HealthKit is not available on this device."
        }

        let workoutType = HKObjectType.workoutType()

        let authorizationStatus = healthStore.authorizationStatus(
            for: workoutType
        )
        if authorizationStatus != .sharingAuthorized {
            do {
                try await healthStore
                    .requestAuthorization(toShare: [], read: [workoutType])
            } catch {
                return
                    "Failed to get HealthKit authorization: \(error.localizedDescription)"
            }
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        guard let queryDate = dateFormatter.date(from: date) else {
            return "Invalid date format. Please use YYYY-MM-DD format."
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: queryDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )

        let workouts = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<[HKWorkout], Error>) in
            let query = HKSampleQuery(
                sampleType: workoutType, predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let workouts = samples as? [HKWorkout] {
                    continuation.resume(returning: workouts)
                } else {
                    continuation.resume(returning: [])
                }
            }
            healthStore.execute(query)
        }

        if workouts.isEmpty {
            return "No workouts found for \(date)."
        }

        var summary = "Workout Summary for \(date):\n"
        var totalDuration = TimeInterval(0)
        var totalCalories = Double(0)
        var totalDistance = Double(0)

        for workout in workouts {
            let duration = workout.duration

            let activeEnergyBurnedType = HKQuantityType(.activeEnergyBurned)
            let calories: Double
            if let statistics = workout.statistics(for: activeEnergyBurnedType),
                let sum = statistics.sumQuantity()
            {
                calories = sum.doubleValue(for: .kilocalorie())
            } else {
                calories = 0
            }

            let distance =
                workout.totalDistance?.doubleValue(
                    for: .meter()
                ) ?? 0

            totalDuration += duration
            totalCalories += calories
            totalDistance += distance

            summary +=
                "\n- \(formatDuration(duration)), \(Int(calories)) kcal, \(formatDistance(distance))"
        }

        summary +=
            "\n\nTotal: \(formatDuration(totalDuration)), \(Int(totalCalories)) kcal, \(formatDistance(totalDistance))"
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
        guard HKHealthStore.isHealthDataAvailable() else {
            return "HealthKit is not available on this device."
        }

        let workoutType = HKObjectType.workoutType()

        let authorizationStatus = healthStore.authorizationStatus(
            for: workoutType
        )
        if authorizationStatus != .sharingAuthorized {
            do {
                try await healthStore
                    .requestAuthorization(toShare: [], read: [workoutType])
            } catch {
                return
                    "Failed to get HealthKit authorization: \(error.localizedDescription)"
            }
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(
            from:
                calendar
                .dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let endOfWeek = calendar.date(
            byAdding: .day,
            value: 7,
            to: startOfWeek
        )!

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfWeek,
            end: endOfWeek,
            options: .strictStartDate
        )

        let workouts = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<[HKWorkout], Error>) in
            let query = HKSampleQuery(
                sampleType: workoutType, predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let workouts = samples as? [HKWorkout] {
                    continuation.resume(returning: workouts)
                } else {
                    continuation.resume(returning: [])
                }
            }
            healthStore.execute(query)
        }

        if workouts.isEmpty {
            return "No workouts found for this week."
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE"  // Day name (e.g., "Monday")

        var workoutsByDay: [String: [HKWorkout]] = [:]
        var summary = "Workout Summary for this week:\n"

        for workout in workouts {
            let dayName = dateFormatter.string(from: workout.startDate)
            if workoutsByDay[dayName] == nil {
                workoutsByDay[dayName] = []
            }
            workoutsByDay[dayName]?.append(workout)
        }

        let sortedDays = workoutsByDay.keys.sorted { day1, day2 in
            let index1 = calendar.component(
                .weekday, from: dateFormatter.date(from: day1) ?? Date())
            let index2 = calendar.component(
                .weekday, from: dateFormatter.date(from: day2) ?? Date())
            return index1 < index2
        }

        for day in sortedDays {
            summary += "\n\n📅 \(day):"
            for workout in workoutsByDay[day] ?? [] {
                let duration = workout.duration

                let activeEnergyBurnedType = HKQuantityType(.activeEnergyBurned)
                let calories: Double
                if let statistics = workout.statistics(
                    for: activeEnergyBurnedType),
                    let sum = statistics.sumQuantity()
                {
                    calories = sum.doubleValue(for: .kilocalorie())
                } else {
                    calories = 0
                }

                let distance =
                    workout.totalDistance?.doubleValue(
                        for: .meter()
                    ) ?? 0

                summary +=
                    "\n- \(formatDuration(duration)), \(Int(calories)) kcal, \(formatDistance(distance))"
            }
        }

        return summary
    }

    /// Call this function when generation is complete to flush any remaining buffer.
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
