import HealthKit
import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import Metal
import SwiftUI
import Tokenizers

struct WorkoutView: View {
    @State private var llm = LLMEvaluator()
    @State private var prompt =
        "Summary of my workouts this week, and how I did in them."

    // Add system colors and constants
    private let backgroundColor = Color(.systemBackground)
    private let secondaryBackground = Color(.secondarySystemBackground)
    private let accentColor = Color.accentColor

    /// Style options for displaying the LLM output
    private enum DisplayStyle: String, CaseIterable, Identifiable {
        case plain, markdown
        var id: Self { self }
    }

    @State private var selectedDisplayStyle = DisplayStyle.markdown

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                outputView
                promptInputView
            }
            #if os(visionOS)
                .padding(40)
            #else
                .padding()
            #endif
            .navigationTitle("HealthSeek")
            .background(backgroundColor)
            .task {
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
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(secondaryBackground)
                        .cornerRadius(12)
                }
                .onChange(of: llm.output) { _, _ in
                    sp.scrollTo("bottom")
                }

                Spacer()
                    .frame(width: 1, height: 1)
                    .id("bottom")
            }
        }
        .background(backgroundColor)
    }

    private var promptInputView: some View {
        HStack(spacing: 12) {
            TextField(
                "Ask something about your health data...",
                text: $prompt,
                axis: .vertical
            )
            .lineLimit(1...4)
            .textFieldStyle(.plain)
            .onSubmit(generate)
            .disabled(llm.running)
            #if os(visionOS)
                .textFieldStyle(.roundedBorder)
            #endif

            Button(action: generate) {
                Image(
                    systemName: llm.running
                        ? "stop.circle.fill" : "arrow.up.circle.fill"
                )
                .resizable()
                .frame(width: 30, height: 30)
                .foregroundColor(llm.running ? .red : accentColor)
            }
            .disabled(
                prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .animation(.easeInOut, value: llm.running)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(secondaryBackground)
        .cornerRadius(16)
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
