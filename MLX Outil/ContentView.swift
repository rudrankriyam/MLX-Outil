//
//  ContentView.swift
//  MLX Outil
//
//  Created by Rudrank Riyam on 12/1/24.
//

import MLX
import MLXLLM
import MLXRandom
import SwiftUI

struct ContentView: View {
  @State private var prompt = ""
  @State private var output = ""
  @State private var isGenerating = false
  @State private var generatedText = ""

  var body: some View {
    VStack {
      ScrollView {
        Text(isGenerating ? generatedText : output)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      HStack {
        TextField("Enter prompt", text: $prompt)
          .textFieldStyle(.roundedBorder)
          .disabled(isGenerating)

        Button(isGenerating ? "Stop" : "Generate") {
          if isGenerating {
            isGenerating = false
          } else {
            generate()
          }
        }
      }
    }
    .padding()
  }

  private func generate() {
    Task {
      isGenerating = true
      generatedText = ""

      do {
        let config = ModelConfiguration.llama3_2_3B_4bit
        let modelContainer = try await MLXLLM.loadModelContainer(configuration: config) {
          progress in
          print("Loading progress: \(progress)")
        }

        let messages = [["role": "user", "content": prompt]]

        let promptTokens = try await modelContainer.perform { _, tokenizer in
          try tokenizer.applyChatTemplate(messages: messages)
        }

        MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

        let result = await modelContainer.perform { model, tokenizer in
          MLXLLM.generate(
            promptTokens: promptTokens,
            parameters: GenerateParameters(temperature: 1.0),
            model: model,
            tokenizer: tokenizer
          ) { tokens in
            let text = tokenizer.decode(tokens: tokens)

            Task { @MainActor in
              generatedText = text
            }
            return .more
          }
        }

        if isGenerating {
          output = result.output
        }
      } catch {
        output = "Error: \(error.localizedDescription)"
      }

      isGenerating = false
    }
  }
}
