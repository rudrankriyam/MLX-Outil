//
//  ConcreteModelContainer.swift
//  Core
//
//  Created by Marlon Rugama on 2/11/25.
//

import SwiftUI
import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom

final class ConcreteModelContainer: CoreModelContainer, @unchecked Sendable {
    private var lock = NSLock()

    private(set) var onProgress: String = ""
    
    private let modelConfiguration: ModelConfiguration
    private let generateParameters: GenerateParameters
    
    init(
        modelConfiguration: ModelConfiguration,
        generateParameters: GenerateParameters
    ) {
        self.modelConfiguration = modelConfiguration
        self.generateParameters = generateParameters
    }
    
    func load() async throws -> ModelContainer {
            MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

            let modelContainer = try await LLMModelFactory.shared.loadContainer(
                configuration: modelConfiguration
            ) { [modelConfiguration] progress in
                Task { @MainActor in
                    print(
                        "Downloading \(modelConfiguration.name): \(Int(progress.fractionCompleted * 100))%"
                    )
                }
            }
            let numParams = await modelContainer.perform { context in
                context.model.numParameters()
            }

            print(
                "Loaded \(modelConfiguration.id). Weights: \(numParams / (1024*1024))M"
            )
            return modelContainer
    }
    
    func generate(
        messages: [Message],
        tools: [Tool]?,
        onProgress: @escaping OnProgress
    ) async throws -> ContainerResult {
        let modelContainer = try await load()

        MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

        return try await modelContainer.perform { context   in
            let input = try await context.processor.prepare(
                input: .init(messages: messages, tools: tools)
            )
            
            return try MLXLMCommon.generate(
                input: input,
                parameters: generateParameters,
                context: context
            ) { tokens in
                if tokens.count % 2 == 0 {
//                    self.lock.lock()
//                    defer { self.lock.unlock() }
                    let text = context.tokenizer.decode(tokens: tokens)
                    Task { @MainActor in
                        onProgress(text)
//                        print(text)
                    }
                }
                return .more
            }
        }
    }
}
