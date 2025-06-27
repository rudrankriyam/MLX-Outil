import SwiftUI
import MLXTools

struct ToolsGridView: View {
    @Environment(LLMManager.self) private var llm
    @State private var selectedTool: ToolExample?
    @State private var isRunning = false
    @State private var result = ""
    @State private var errorMessage: String?
    @State private var toolInput = ""
    
    #if os(macOS)
    private let backgroundColor = Color(NSColor.windowBackgroundColor)
    private let secondaryBackground = Color(NSColor.controlBackgroundColor)
    #else
    private let backgroundColor = Color(.systemBackground)
    private let secondaryBackground = Color(.secondarySystemBackground)
    #endif
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    toolGridView
                    
                    if selectedTool != nil {
                        inputView
                        resultView
                    }
                }
                .padding()
            }
            .navigationTitle("Tools")
            .background(backgroundColor)
        }
    }
    
    private var toolGridView: some View {
        LazyVGrid(columns: adaptiveColumns, spacing: 16) {
            ForEach(ToolExample.allCases, id: \.self) { tool in
                ToolButton(
                    tool: tool,
                    isSelected: selectedTool == tool,
                    isRunning: isRunning && selectedTool == tool
                ) {
                    selectedTool = tool
                    toolInput = tool.defaultInput
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
    
    private var inputView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tool Input")
                .font(.headline)
            
            TextField("Enter input for \(selectedTool?.displayName ?? "tool")...", text: $toolInput, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
                .disabled(isRunning)
            
            Button(action: executeTool) {
                HStack {
                    if isRunning {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "play.circle.fill")
                    }
                    Text(isRunning ? "Running..." : "Execute Tool")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning || toolInput.isEmpty)
        }
        .padding()
        .background(secondaryBackground)
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var resultView: some View {
        if !result.isEmpty || errorMessage != nil {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Result")
                        .font(.headline)
                    Spacer()
                    Button("Clear") {
                        result = ""
                        errorMessage = nil
                    }
                    .font(.caption)
                }
                
                if let error = errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                if !result.isEmpty {
                    ScrollView {
                        Text(result)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(secondaryBackground)
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 300)
                }
            }
        }
    }
    
    private func executeTool() {
        guard let tool = selectedTool else { return }
        
        Task {
            await performToolExecution(tool: tool)
        }
    }
    
    @MainActor
    private func performToolExecution(tool: ToolExample) async {
        isRunning = true
        errorMessage = nil
        result = ""
        
        let prompt = tool.generatePrompt(with: toolInput)
        await llm.generate(prompt: prompt)
        
        // The result will be in llm.output
        result = llm.output
        isRunning = false
    }
}

// MARK: - Tool Button Component

struct ToolButton: View {
    let tool: ToolExample
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
            VStack(spacing: 12) {
                ZStack {
                    Image(systemName: tool.icon)
                        .font(.system(size: 28))
                        .foregroundColor(isSelected ? .white : .accentColor)
                        .opacity(isRunning ? 0 : 1)
                    
                    if isRunning {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    }
                }
                .frame(width: 50, height: 50)
                
                VStack(spacing: 4) {
                    Text(tool.displayName)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                        .multilineTextAlignment(.center)
                    
                    Text(tool.shortDescription)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 140)
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
                                    Color.clear
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
                                Color.clear
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

// MARK: - Tool Example Enum

enum ToolExample: String, CaseIterable {
    case weather
    case workout
    case search
    case calendar
    case reminders
    case contacts
    case location
    case music
    
    var displayName: String {
        switch self {
        case .weather: return "Weather"
        case .workout: return "Workouts"
        case .search: return "Web Search"
        case .calendar: return "Calendar"
        case .reminders: return "Reminders"
        case .contacts: return "Contacts"
        case .location: return "Location"
        case .music: return "Music"
        }
    }
    
    var icon: String {
        switch self {
        case .weather: return "cloud.sun"
        case .workout: return "figure.run"
        case .search: return "magnifyingglass"
        case .calendar: return "calendar"
        case .reminders: return "checklist"
        case .contacts: return "person.2"
        case .location: return "location"
        case .music: return "music.note"
        }
    }
    
    var shortDescription: String {
        switch self {
        case .weather: return "Get weather info"
        case .workout: return "Track workouts"
        case .search: return "Search the web"
        case .calendar: return "Manage events"
        case .reminders: return "Manage tasks"
        case .contacts: return "Find contacts"
        case .location: return "Get location"
        case .music: return "Play music"
        }
    }
    
    var defaultInput: String {
        switch self {
        case .weather: return "What's the weather like in New York?"
        case .workout: return "Show me my workout summary for this week"
        case .search: return "Search for information about Swift programming"
        case .calendar: return "What events do I have today?"
        case .reminders: return "Show me my incomplete reminders"
        case .contacts: return "Search for contacts named John"
        case .location: return "What's my current location?"
        case .music: return "Search for songs by Taylor Swift"
        }
    }
    
    func generatePrompt(with input: String) -> String {
        switch self {
        case .weather:
            return input.isEmpty ? defaultInput : input
        case .workout:
            return input.isEmpty ? defaultInput : input
        case .search:
            return input.isEmpty ? defaultInput : input
        case .calendar:
            return input.isEmpty ? defaultInput : input
        case .reminders:
            return input.isEmpty ? defaultInput : input
        case .contacts:
            return input.isEmpty ? defaultInput : input
        case .location:
            return input.isEmpty ? defaultInput : input
        case .music:
            return input.isEmpty ? defaultInput : input
        }
    }
}

#Preview {
    ToolsGridView()
        .environment(LLMManager())
}