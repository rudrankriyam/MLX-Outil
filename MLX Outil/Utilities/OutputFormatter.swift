import Foundation
import HealthKit

final class OutputFormatter {
    static func formatWeatherData(_ weather: WeatherKitManager.WeatherData)
        -> String
    {
        String(
            format: Constants.Weather.formatString,
            weather.temperature,
            weather.feelsLike,
            weather.condition,
            weather.humidity * 100,
            weather.windSpeed,
            weather.uvIndex,
            weather.visibility / 1000,
            weather.pressure,
            weather.precipitationChance * 100)
    }

    static func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "N/A"
    }

    static func formatDistance(_ distance: Double) -> String {
        let kilometers = distance / 1000
        return String(format: "%.2f km", kilometers)
    }

    static func formatWeeklyWorkoutSummary(
        _ workouts: [HKWorkout], using healthManager: HealthKitManager
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE"

        var workoutsByDay: [String: [HKWorkout]] = [:]
        for workout in workouts {
            let dayName = dateFormatter.string(from: workout.startDate)
            workoutsByDay[dayName, default: []].append(workout)
        }

        let calendar = Calendar.current
        let sortedDays = workoutsByDay.keys.sorted { day1, day2 in
            let index1 = calendar.component(
                .weekday, from: dateFormatter.date(from: day1) ?? Date())
            let index2 = calendar.component(
                .weekday, from: dateFormatter.date(from: day2) ?? Date())
            return index1 < index2
        }

        var summary = "Workout Summary for this week:"
        for day in sortedDays {
            summary += "\n\n📅 \(day):"
            for workout in workoutsByDay[day] ?? [] {
                let metrics = healthManager.getWorkoutMetrics(workout)
                summary +=
                    "\n- \(formatDuration(metrics.duration)), \(Int(metrics.calories)) kcal, \(formatDistance(metrics.distance))"
            }
        }

        return summary
    }
}
