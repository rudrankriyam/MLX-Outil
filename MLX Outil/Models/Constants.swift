//
//  Constants.swift
//  MLX Outil
//
//  Created by Rudrank Riyam on 2/9/25.
//

enum Constants {
    static let systemPrompt = "You are a helpful assistant with access to health and weather data."
    static let toolCallStartTag = "<tool_call>"
    static let toolCallEndTag = "</tool_call>"

    enum Weather {
        static let formatString = """
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
