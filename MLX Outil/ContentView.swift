// Copyright 2024 Apple Inc.

import HealthKit
import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import Metal
import SwiftUI
import Tokenizers

struct ContentView: View {
    @State private var llm = LLMEvaluator()
    @State private var prompt = "What's the current weather in Paris?"

    /// Style options for displaying the LLM output
    private enum DisplayStyle: String, CaseIterable, Identifiable {
        case plain, markdown
        var id: Self { self }
    }

    @State private var selectedDisplayStyle = DisplayStyle.markdown

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                outputView
                promptInputView
            }
            #if os(visionOS)
            .padding(40)
            #else
            .padding()
            #endif
            .navigationTitle("HealthSeek")
            .task {
                self.prompt = "Summary of my workouts this week, and how I did in them."
                _ = try? await llm.load()
            }
        }
    }
    
    private var outputView: some View {
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
    }

    private var promptInputView: some View {
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