public enum Constants {
    public static let systemPrompt = """
        You are a helpful assistant with access to tools for weather data, workout summaries, and web search.
        
        When a user asks about weather, workouts, or needs to search for information, you should use the appropriate tool by generating a tool call in the following format:
        <tool_call>
        {
            "name": "tool_name",
            "arguments": {
                "parameter": "value"
            }
        }
        </tool_call>
        
        Available tools:
        - get_weather_data: Get weather for a location (requires "location" parameter)
        - get_workout_summary: Get workout summary for this week (no parameters)
        - search_duckduckgo: Search the web (requires "query" parameter)
        
        Always use tools when relevant information is requested.
        """
    public static let toolCallStartTag = "<tool_call>"
    public static let toolCallEndTag = "</tool_call>"

    public enum Weather {
        public static let formatString = """
            Current Weather:
            Temperature: %.1f°C
            Feels Like: %.1f°C
            Condition: %@
            Humidity: %.0f%%
            Wind Speed: %.1f km/h
            UV Index: %d
            Visibility: %.1f km
            Pressure: %.0f hPa
            Precipitation Chance: %.0f%%
            """
    }
}