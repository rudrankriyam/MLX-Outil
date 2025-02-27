import Foundation

/*
 This file contains sample code demonstrating how to use the MLXArguments module in your app.
 
 // MARK: - Example Usage
 
 // 1. Create your service implementations
 class MyWeatherService: WeatherServiceProtocol {
     func fetchWeather(for location: String) async throws -> String {
         // Implement your weather fetching logic here
         return "Weather forecast for \(location): Sunny, 75°F"
     }
 }
 
 class MySearchService: SearchServiceProtocol {
     func search(query: String) async throws -> String {
         // Implement your search logic here
         return "Search results for '\(query)': [Result 1], [Result 2], [Result 3]"
     }
 }
 
 // 2. Register your tool handlers at app startup
 func setupToolHandlers() async {
     let weatherHandler = WeatherToolHandler(weatherService: MyWeatherService())
     let searchHandler = SearchToolHandler(searchService: MySearchService())
     
     await ToolRegistry.shared.register(toolType: WeatherToolType.getWeatherData, handler: weatherHandler)
     await ToolRegistry.shared.register(toolType: SearchToolType.searchDuckDuckGo, handler: searchHandler)
 }
 
 // 3. Create your custom tool call handler
 class AppToolCallHandler: BaseToolCallHandler {
     override func handleToolCall(_ jsonString: String) async throws -> String {
         guard let data = jsonString.data(using: .utf8) else {
             throw ToolCallError.invalidJSON
         }
         
         // First try to decode just the tool name
         struct ToolName: Codable {
             let name: String
         }
         
         do {
             let toolNameInfo = try JSONDecoder().decode(ToolName.self, from: data)
             
             guard let handler = await ToolRegistry.shared.handler(for: toolNameInfo.name) else {
                 throw ToolCallError.unknownTool(toolNameInfo.name)
             }
             
             return try await handler.handle(json: data)
         } catch {
             throw ToolCallError.invalidJSON
         }
     }
 }
 
 // 4. Use in your app's view model or service
 class ChatViewModel: ObservableObject {
     private let modelService: CoreModelService
     private let toolCallHandler = AppToolCallHandler()
     
     @Published var messages: [Message] = []
     @Published var currentResponse: String = ""
     
     init(modelService: CoreModelService) {
         self.modelService = modelService
     }
     
     func sendMessage(_ content: String) async {
         let userMessage = Message(role: "user", content: content)
         await MainActor.run {
             messages.append(userMessage)
         }
         
         do {
             let modelContainer = modelService.provideModelContainer()
             
             try await modelContainer.generate(
                 messages: messages.map { ["role": $0.role, "content": $0.content] },
                 tools: nil
             ) { [weak self] text in
                 Task { @MainActor in
                     do {
                         // Process tool calls
                         let processedText = try await self?.toolCallHandler.processLLMOutput(text) ?? text
                         self?.currentResponse = processedText
                     } catch {
                         print("Error processing tool call: \(error)")
                         self?.currentResponse = text
                     }
                 }
             }
             
             await MainActor.run {
                 let assistantMessage = Message(role: "assistant", content: currentResponse)
                 messages.append(assistantMessage)
                 currentResponse = ""
             }
         } catch {
             print("Error generating response: \(error)")
         }
     }
 }
 
 struct Message {
     let role: String
     let content: String
 }
*/
