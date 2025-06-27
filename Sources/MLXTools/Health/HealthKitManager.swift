import Foundation
import HealthKit

@MainActor
public class HealthKitManager {
    public static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()

    public init() {}

    public enum HealthKitError: Error {
        case unavailable
        case unauthorized
        case invalidDate
    }

    public enum WorkoutDateRange {
        case day(Date)
        case week(Date)

        public var dateInterval: (start: Date, end: Date) {
            let calendar = Calendar.current
            switch self {
            case .day(let date):
                let startOfDay = calendar.startOfDay(for: date)
                let endOfDay = calendar.date(
                    byAdding: .day, value: 1, to: startOfDay)!
                return (startOfDay, endOfDay)
            case .week(let date):
                let startOfWeek = calendar.date(
                    from: calendar.dateComponents(
                        [.yearForWeekOfYear, .weekOfYear], from: date))!
                let endOfWeek = calendar.date(
                    byAdding: .day, value: 7, to: startOfWeek)!
                return (startOfWeek, endOfWeek)
            }
        }
    }

    public func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.unavailable
        }

        let workoutType = HKObjectType.workoutType()
        let authorizationStatus = healthStore.authorizationStatus(
            for: workoutType)

        if authorizationStatus != .sharingAuthorized {
            try await healthStore.requestAuthorization(
                toShare: [], read: [workoutType])
        }
    }

    public func fetchWorkouts(for dateRange: WorkoutDateRange) async throws
        -> [HKWorkout]
    {
        try await requestAuthorization()

        let workoutType = HKObjectType.workoutType()
        let interval = dateRange.dateInterval
        let predicate = HKQuery.predicateForSamples(
            withStart: interval.start,
            end: interval.end,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let workouts = samples as? [HKWorkout] {
                    continuation.resume(returning: workouts)
                } else {
                    continuation.resume(returning: [])
                }
            }
            healthStore.execute(query)
        }
    }

    public func getWorkoutMetrics(_ workout: HKWorkout) -> WorkoutMetrics {
        let activeEnergyBurnedType = HKQuantityType(.activeEnergyBurned)
        let calories: Double
        if let statistics = workout.statistics(for: activeEnergyBurnedType),
            let sum = statistics.sumQuantity()
        {
            calories = sum.doubleValue(for: .kilocalorie())
        } else {
            calories = 0
        }

        let distance = workout.totalDistance?.doubleValue(for: .meter()) ?? 0

        return WorkoutMetrics(
            duration: workout.duration,
            calories: calories,
            distance: distance
        )
    }

    public struct WorkoutMetrics {
        public let duration: TimeInterval
        public let calories: Double
        public let distance: Double
        
        public init(duration: TimeInterval, calories: Double, distance: Double) {
            self.duration = duration
            self.calories = calories
            self.distance = distance
        }
    }
}