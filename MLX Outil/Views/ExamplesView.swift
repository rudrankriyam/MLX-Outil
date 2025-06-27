import MarkdownUI
import SwiftUI

struct ExamplesView: View {
    @Environment(LLMManager.self) private var llm
    @State private var selectedExample: ExampleType?
    @State private var isRunning = false

#if os(macOS)
    private let backgroundColor = Color(NSColor.windowBackgroundColor)
    private let secondaryBackground = Color(NSColor.controlBackgroundColor)
#else
    private let backgroundColor = Color(.systemBackground)
    private let secondaryBackground = Color(.secondarySystemBackground)
#endif
    private let accentColor = Color.accentColor

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerView
                    exampleButtonsView
                    outputView
                }
                .padding()
            }
            .navigationTitle("Examples")
            .background(backgroundColor)
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MLX Outil")
                .font(.title2)
                .fontWeight(.bold)

            Text("Explore different tools working together")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var exampleButtonsView: some View {
        LazyVGrid(columns: adaptiveColumns, spacing: 16) {
            ForEach(ExampleType.allCases, id: \.self) { example in
                ExampleButton(
                    example: example,
                    isSelected: selectedExample == example,
                    isRunning: isRunning && selectedExample == example
                ) {
                    executeExample(example)
                }
            }
        }
    }

    private var adaptiveColumns: [GridItem] {
        #if os(macOS)
        return [GridItem(.adaptive(minimum: 280), spacing: 12)]
        #else
        return [
            GridItem(.flexible(minimum: 140), spacing: 12),
            GridItem(.flexible(minimum: 140), spacing: 12)
        ]
        #endif
    }

    private var outputView: some View {
        Group {
            if llm.running || !llm.output.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Output")
                            .font(.headline)
                        Spacer()
                        if llm.running {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }

                    ScrollView {
                        Markdown(llm.output)
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(secondaryBackground)
                            .cornerRadius(12)
                            .markdownTextStyle(\.code) {
                                FontFamilyVariant(.monospaced)
                                BackgroundColor(Color.blue.opacity(0.1))
                                ForegroundColor(.blue)
                            }
                    }
                    .frame(maxHeight: 400)
                }
            }
        }
    }

    private func executeExample(_ example: ExampleType) {
        selectedExample = example
        isRunning = true

        Task {
            await llm.generate(prompt: example.prompt)
            isRunning = false
        }
    }
}

// MARK: - Example Button Component

struct ExampleButton: View {
    let example: ExampleType
    let isSelected: Bool
    let isRunning: Bool
    let action: () -> Void

#if os(macOS)
    private let selectedColor = Color.accentColor.opacity(0.2)
    private let defaultColor = Color(NSColor.controlBackgroundColor)
#else
    private let selectedColor = Color.accentColor.opacity(0.2)
    private let defaultColor = Color(.secondarySystemBackground)
#endif

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: example.icon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? .white : .accentColor)
                        .frame(width: 24, height: 24)

                    Spacer()

                    if isRunning {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(isSelected ? Color.white.opacity(0.7) : Color.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(example.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(example.subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(
                ZStack {
                    // Glass-like background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? selectedColor : defaultColor)
                        .opacity(0.8)

                    // Subtle gradient overlay
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(isSelected ? 0.05 : 0.02),
                                    Color.clear,
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05),
                                Color.clear,
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isRunning)
    }
}

// MARK: - Example Type Enum

enum ExampleType: String, CaseIterable {
    case dailyBrief = "daily_brief"
    case travelPlanning = "travel_planning"
    case healthDashboard = "health_dashboard"
    case productivityAssistant = "productivity_assistant"
    case eventPlanning = "event_planning"
    case researchAssistant = "research_assistant"

    var title: String {
        switch self {
        case .dailyBrief:
            return "Daily Brief"
        case .travelPlanning:
            return "Travel Planning"
        case .healthDashboard:
            return "Health Dashboard"
        case .productivityAssistant:
            return "Productivity Assistant"
        case .eventPlanning:
            return "Event Planning"
        case .researchAssistant:
            return "Research Assistant"
        }
    }

    var subtitle: String {
        switch self {
        case .dailyBrief:
            return "Weather, calendar, and reminders"
        case .travelPlanning:
            return "Location, weather, and calendar"
        case .healthDashboard:
            return "Health reminders and wellness goals"
        case .productivityAssistant:
            return "Tasks, calendar, and focus music"
        case .eventPlanning:
            return "Calendar, contacts, and location"
        case .researchAssistant:
            return "Web search and organized notes"
        }
    }

    var icon: String {
        switch self {
        case .dailyBrief:
            return "sun.horizon"
        case .travelPlanning:
            return "airplane"
        case .healthDashboard:
            return "heart.text.square"
        case .productivityAssistant:
            return "checkmark.square"
        case .eventPlanning:
            return "calendar.badge.plus"
        case .researchAssistant:
            return "magnifyingglass.circle"
        }
    }

    var prompt: String {
        switch self {
        case .dailyBrief:
            return
            "Give me my daily brief: What's the weather today in New Delhi, Delhi? What events do I have on my calendar? What reminders do I have?"
        case .travelPlanning:
            return
            "I'm planning to visit San Francisco next week. What's the weather forecast? Find the location of Golden Gate Bridge and calculate the distance from downtown. Also check my calendar for availability."
        case .healthDashboard:
            return
            "Show me my health dashboard: any health-related reminders I have and suggestions for staying healthy."
        case .productivityAssistant:
            return
            "Help me be productive: Show my incomplete reminders, today's calendar events, and suggest some focus music to play."
        case .eventPlanning:
            return
            "I want to plan a team meeting next Tuesday at 2 PM. Check my calendar availability, find contacts named 'team', and suggest a good meeting location."
        case .researchAssistant:
            return
            "Research Swift concurrency for me. Search for the latest information and create a reminder to review the findings later."
        }
    }
}

#Preview {
    ExamplesView()
        .environment(LLMManager())
}
