import Foundation
import HealthKit
import UIKit

// Make HealthMetric Codable
extension HealthMetric: Codable {
    enum CodingKeys: String, CodingKey {
        case name, value, type, labels, unit
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        value = try container.decode(Double.self, forKey: .value)
        type = try container.decode(MetricType.self, forKey: .type)
        labels = try container.decode([String: String].self, forKey: .labels)
        
        // HKUnit is not directly codable, so we store unit as string
        let unitString = try container.decode(String.self, forKey: .unit)
        unit = HKUnit(from: unitString)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(value, forKey: .value)
        try container.encode(type, forKey: .type)
        try container.encode(labels, forKey: .labels)
        try container.encode(unit.unitString, forKey: .unit)
    }
}

extension MetricType: Codable {}

extension HKUnit {
    var unitString: String {
        return self.description
    }
}

class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    
    private init() {}
    
    // All available HealthKit types we want to read
    private var allHealthKitObjectTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()

        // Add all sample types
        types.formUnion(allHealthKitTypes)

        // Add Activity Summary type (for Activity Rings)
        types.insert(HKObjectType.activitySummaryType())

        return types
    }

    private var allHealthKitTypes: Set<HKSampleType> {
        var types = Set<HKSampleType>()
        
        // Quantity types - ALL metrics from healthkit_types.json
        var quantityTypes: [HKQuantityTypeIdentifier] = [
            // Core metrics (existing)
            .stepCount,
            .distanceWalkingRunning,
            .distanceCycling,
            .basalEnergyBurned,
            .activeEnergyBurned,
            .flightsClimbed,
            .heartRate,
            .restingHeartRate,
            .walkingHeartRateAverage,
            .heartRateVariabilitySDNN,
            .oxygenSaturation,
            .respiratoryRate,
            .bodyTemperature,
            .bloodPressureSystolic,
            .bloodPressureDiastolic,
            .bloodGlucose,
            .bodyMass,
            .bodyMassIndex,
            .bodyFatPercentage,
            .height,
            .vo2Max,
            .waistCircumference,
            .walkingSpeed,
            .walkingStepLength,
            .walkingDoubleSupportPercentage,
            .walkingAsymmetryPercentage,
            .stairAscentSpeed,
            .stairDescentSpeed,
            .sixMinuteWalkTestDistance,
            // Additional metrics from healthkit_types.json
            .appleExerciseTime,
            .appleStandTime,
            .environmentalAudioExposure,
            .headphoneAudioExposure,
            .appleWalkingSteadiness,
            .environmentalSoundReduction
        ]
        
        // iOS 17.0+ only metrics
        if #available(iOS 17.0, *) {
            quantityTypes.append(.physicalEffort)
        }
        
        for identifier in quantityTypes {
            if let type = HKQuantityType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
        }
        
        // Category types - ALL from healthkit_types.json
        let categoryTypes: [HKCategoryTypeIdentifier] = [
            .sleepAnalysis,
            .appleStandHour,
            .mindfulSession,
            .highHeartRateEvent,
            .lowHeartRateEvent,
            .irregularHeartRhythmEvent,
            .environmentalAudioExposureEvent,
            .headphoneAudioExposureEvent,
            .toothbrushingEvent
        ]
        
        for identifier in categoryTypes {
            if let type = HKCategoryType.categoryType(forIdentifier: identifier) {
                types.insert(type)
            }
        }
        
        // Workout type
        types.insert(HKObjectType.workoutType())

        return types
    }

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, NSError(domain: "HealthKit", code: 0, userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available on this device"]))
            return
        }

        healthStore.requestAuthorization(toShare: nil, read: allHealthKitObjectTypes) { [weak self] success, error in
            if success {
                // Enable background delivery for key metrics
                self?.enableBackgroundDelivery()
            }
            completion(success, error)
        }
    }
    
    private func enableBackgroundDelivery() {
        // Enable background delivery for key metric types
        let keyTypes: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .heartRate,
            .activeEnergyBurned,
            .distanceWalkingRunning
        ]
        
        for identifier in keyTypes {
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { continue }
            
            healthStore.enableBackgroundDelivery(for: quantityType, frequency: .immediate) { [weak self] success, error in
                if success {
                    Logger.shared.log("Background delivery enabled for \(identifier.rawValue)", level: .info)
                    self?.setupObserverQuery(for: quantityType)
                } else if let error = error {
                    Logger.shared.log("Failed to enable background delivery for \(identifier.rawValue): \(error)", level: .error)
                }
            }
        }
    }
    
    private func setupObserverQuery(for quantityType: HKQuantityType) {
        let query = HKObserverQuery(sampleType: quantityType, predicate: nil) { query, completionHandler, error in
            if let error = error {
                Logger.shared.log("Observer query error for \(quantityType.identifier): \(error)", level: .error)
                completionHandler()
                return
            }
            
            Logger.shared.log("HealthKit data changed for \(quantityType.identifier), triggering push", level: .info)
            
            // Trigger a metric push when data changes
            Task {
                do {
                    try await PrometheussPushService.shared.pushMetricsOnce()
                } catch {
                    Logger.shared.log("Failed to push metrics after HealthKit update: \(error)", level: .error)
                }
            }
            
            completionHandler()
        }
        
        healthStore.execute(query)
        Logger.shared.log("Observer query started for \(quantityType.identifier)", level: .info)
    }
    
    func authorizationStatus() -> String {
        guard HKHealthStore.isHealthDataAvailable() else {
            return "Not Available"
        }
        
        // Check a sample type to determine general authorization
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let status = healthStore.authorizationStatus(for: stepType)
            switch status {
            case .notDetermined:
                return "Not Determined"
            case .sharingDenied:
                return "Denied"
            case .sharingAuthorized:
                return "Authorized"
            @unknown default:
                return "Unknown"
            }
        }
        
        return "Unknown"
    }
    
    // New function for Babble - returns daily time-series data
    func collectDailyMetrics(days: Int = 30) async throws -> String {
        Logger.shared.log("Starting collectDailyMetrics for \(days) days", level: .info)

        let calendar = Calendar.current
        let now = Date()

        var dailyData: [String] = []

        // Get daily stats for key metrics
        let metricsToTrack: [(HKQuantityTypeIdentifier, String, HKUnit, Bool)] = [
            (.stepCount, "steps", .count(), true), // cumulative
            (.activeEnergyBurned, "active_calories", .kilocalorie(), true), // cumulative
            (.distanceWalkingRunning, "distance_km", .meter(), true), // cumulative
            (.heartRate, "heart_rate_bpm", HKUnit.count().unitDivided(by: .minute()), false), // average
            (.restingHeartRate, "resting_hr_bpm", HKUnit.count().unitDivided(by: .minute()), false) // average
        ]

        for dayOffset in 0..<days {
            guard let dayStart = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let dayStartOfDay = calendar.startOfDay(for: dayStart)

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            let dateStr = dateFormatter.string(from: dayStartOfDay)

            var dayMetrics: [String] = []

            for (identifier, name, unit, isCumulative) in metricsToTrack {
                guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { continue }

                do {
                    if let value = await getDailyValue(for: type, unit: unit, date: dayStartOfDay, isCumulative: isCumulative) {
                        var formattedValue = value

                        // Convert distance from meters to km
                        if identifier == .distanceWalkingRunning {
                            formattedValue = value / 1000.0
                        }

                        dayMetrics.append("\(name)=\(String(format: "%.0f", formattedValue))")
                    }
                } catch {
                    Logger.shared.log("Error getting \(name) for \(dateStr): \(error)", level: .error)
                }
            }

            // Get sleep data for this day
            if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
                let sleepMinutes = await getSleepForDate(type: sleepType, date: dayStartOfDay)
                if sleepMinutes > 0 {
                    let hours = sleepMinutes / 60.0
                    dayMetrics.append(String(format: "sleep_hours=%.1f", hours))
                }
            }

            if !dayMetrics.isEmpty {
                dailyData.append("\(dateStr): \(dayMetrics.joined(separator: ", "))")
            }
        }

        Logger.shared.log("Collected daily metrics for \(dailyData.count) days", level: .info)
        return dailyData.reversed().joined(separator: "\n")
    }

    private func getDailyValue(for type: HKQuantityType, unit: HKUnit, date: Date, isCumulative: Bool) async -> Double? {
        await withCheckedContinuation { continuation in
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                continuation.resume(returning: nil)
                return
            }

            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

            // Use appropriate query option based on metric type
            let options: HKStatisticsOptions = isCumulative ? .cumulativeSum : .discreteAverage

            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: options) { _, statistics, error in
                if let error = error {
                    Logger.shared.log("HealthKit query error: \(error.localizedDescription)", level: .error)
                    continuation.resume(returning: nil)
                    return
                }

                if isCumulative {
                    if let sum = statistics?.sumQuantity() {
                        continuation.resume(returning: sum.doubleValue(for: unit))
                    } else {
                        continuation.resume(returning: nil)
                    }
                } else {
                    if let avg = statistics?.averageQuantity() {
                        continuation.resume(returning: avg.doubleValue(for: unit))
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }

            healthStore.execute(query)
        }
    }

    private func getSleepForDate(type: HKCategoryType, date: Date) async -> Double {
        await withCheckedContinuation { continuation in
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                continuation.resume(returning: 0)
                return
            }

            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }

                var totalMinutes = 0.0
                for sample in samples {
                    if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                        let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60.0
                        totalMinutes += duration
                    }
                }

                continuation.resume(returning: totalMinutes)
            }

            healthStore.execute(query)
        }
    }

    func collectAllMetrics(days: Int = 1) async throws -> [HealthMetric] {
        var metrics: [HealthMetric] = []

        // Try to collect fresh metrics with retry logic
        for attempt in 1...3 {
            // Collect quantity type metrics
            let quantityMetrics = await collectQuantityMetrics(days: days)
            metrics.append(contentsOf: quantityMetrics)

            // Collect category metrics
            let categoryMetrics = await collectCategoryMetrics(days: days)
            metrics.append(contentsOf: categoryMetrics)

            // Collect workout metrics
            let workoutMetrics = await collectWorkoutMetrics(days: days)
            metrics.append(contentsOf: workoutMetrics)

            // Collect activity summary metrics
            let activitySummaryMetrics = await collectActivitySummaryMetrics()
            metrics.append(contentsOf: activitySummaryMetrics)
            
            // Add last sync metric
            let lastSyncMetric = await collectLastSyncMetric()
            if let lastSync = lastSyncMetric {
                metrics.append(lastSync)
            }
            
            if !metrics.isEmpty {
                // Successfully collected metrics, cache them
                MetricCache.shared.saveMetrics(metrics)
                return metrics
            }
            
            // If no metrics collected and not the last attempt, wait and retry
            if attempt < 3 {
                Logger.shared.log("No metrics collected on attempt \(attempt), retrying...", level: .warning)
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                metrics.removeAll() // Clear any partial results
            }
        }
        
        // If all attempts failed, try to use cached metrics
        if let cachedMetrics = MetricCache.shared.getCachedMetrics() {
            Logger.shared.log("Using cached metrics as fallback", level: .info)
            
            // Convert cached metrics to current format with age labels
            return cachedMetrics.map { cached in
                var labels = cached.metric.labels
                labels["data_age_minutes"] = String(cached.ageInMinutes)
                labels["cached"] = "true"
                
                return HealthMetric(
                    name: cached.metric.name,
                    value: cached.metric.value,
                    type: cached.metric.type,
                    labels: labels,
                    unit: cached.metric.unit
                )
            }
        }
        
        Logger.shared.log("No metrics available (fresh or cached)", level: .error)
        return []
    }
    
    private func collectQuantityMetrics(days: Int = 1) async -> [HealthMetric] {
        var metrics: [HealthMetric] = []
        let deviceName = await UIDevice.current.name
        
        var quantityTypes: [(HKQuantityTypeIdentifier, String, MetricType)] = [
            // Counter metrics - cumulative over time
            (.stepCount, "steps", .counter),
            (.distanceWalkingRunning, "distance_walking_running_meters", .counter),
            (.activeEnergyBurned, "active_energy_burned_calories", .counter),
            (.basalEnergyBurned, "basal_energy_burned_calories", .counter),
            (.flightsClimbed, "flights_climbed", .counter),
            (.appleExerciseTime, "apple_exercise_time_minutes", .counter),
            (.appleStandTime, "apple_stand_time_minutes", .counter),
            
            // Gauge metrics - point-in-time values
            (.heartRate, "heart_rate_bpm", .gauge),
            (.restingHeartRate, "resting_heart_rate_bpm", .gauge),
            (.walkingHeartRateAverage, "walking_heart_rate_average_bpm", .gauge),
            (.heartRateVariabilitySDNN, "heart_rate_variability_sdnn_ms", .gauge),
            (.respiratoryRate, "respiratory_rate_bpm", .gauge),
            (.vo2Max, "vo2_max_ml_min_kg", .gauge),
            (.oxygenSaturation, "oxygen_saturation_percent", .gauge),
            (.bodyMass, "body_weight_kg", .gauge),
            (.bodyMassIndex, "body_mass_index", .gauge),
            (.bodyFatPercentage, "body_fat_percent", .gauge),
            (.bloodPressureSystolic, "blood_pressure_systolic_mmhg", .gauge),
            (.bloodPressureDiastolic, "blood_pressure_diastolic_mmhg", .gauge),
            (.bloodGlucose, "blood_glucose_mg_dl", .gauge),
            
            // Walking and mobility metrics
            (.walkingSpeed, "walking_speed_mph", .gauge),
            (.walkingStepLength, "walking_step_length_inches", .gauge),
            (.walkingDoubleSupportPercentage, "walking_double_support_percent", .gauge),
            (.walkingAsymmetryPercentage, "walking_asymmetry_percent", .gauge),
            (.stairAscentSpeed, "stair_ascent_speed_fps", .gauge),
            (.stairDescentSpeed, "stair_descent_speed_fps", .gauge),
            (.sixMinuteWalkTestDistance, "six_minute_walk_distance_meters", .gauge),
            (.appleWalkingSteadiness, "apple_walking_steadiness_percent", .gauge),
            
            // Audio exposure metrics
            (.environmentalAudioExposure, "environmental_audio_exposure_db", .gauge),
            (.headphoneAudioExposure, "headphone_audio_exposure_db", .gauge),
            (.environmentalSoundReduction, "environmental_sound_reduction_db", .gauge)
        ]
        
        // iOS 17.0+ only metrics
        if #available(iOS 17.0, *) {
            quantityTypes.append((.physicalEffort, "physical_effort_kcal_hr_kg", .gauge))
        }
        
        for (identifier, metricName, metricType) in quantityTypes {
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { continue }
            
            if metricType == .counter {
                // Get cumulative sum for counters
                if let value = await getCumulativeSum(for: quantityType, unit: getUnit(for: identifier), days: days) {
                    let metric = HealthMetric(
                        name: "healthkit_\(metricName)_total",
                        value: value,
                        type: metricType,
                        labels: ["instance": deviceName],
                        unit: getUnit(for: identifier)
                    )
                    metrics.append(metric)
                }
            } else {
                // Get most recent value for gauges
                if let sample = await getMostRecentSample(for: quantityType) {
                    let value = sample.quantity.doubleValue(for: getUnit(for: identifier))
                    let metric = HealthMetric(
                        name: "healthkit_\(metricName)",
                        value: value,
                        type: metricType,
                        labels: [
                            "instance": deviceName,
                            "source": sample.sourceRevision.source.name
                        ],
                        unit: getUnit(for: identifier)
                    )
                    metrics.append(metric)
                }
            }
        }
        
        return metrics
    }
    
    private func collectCategoryMetrics(days: Int = 1) async -> [HealthMetric] {
        var metrics: [HealthMetric] = []
        let deviceName = await UIDevice.current.name

        // Sleep analysis
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            let sleepMinutes = await getTodaysSleepMinutes(for: sleepType, days: days)
            if sleepMinutes > 0 {
                let metric = HealthMetric(
                    name: "healthkit_sleep_minutes_total",
                    value: sleepMinutes,
                    type: .counter,
                    labels: ["instance": deviceName],
                    unit: HKUnit.minute()
                )
                metrics.append(metric)
            }
        }
        
        // Apple Stand Hour - count of hours user stood
        if let standHourType = HKCategoryType.categoryType(forIdentifier: .appleStandHour) {
            let standHours = await getCategoryCount(for: standHourType, value: HKCategoryValueAppleStandHour.stood.rawValue, days: days)
            let metric = HealthMetric(
                name: "healthkit_apple_stand_hours_total",
                value: Double(standHours),
                type: .counter,
                labels: ["instance": deviceName],
                unit: HKUnit.count()
            )
            metrics.append(metric)
        }

        // Audio Exposure Events - environmental limit breaches
        if let audioEventType = HKCategoryType.categoryType(forIdentifier: .environmentalAudioExposureEvent) {
            let audioEvents = await getCategoryCount(for: audioEventType, value: HKCategoryValueEnvironmentalAudioExposureEvent.momentaryLimit.rawValue, days: days)
            let metric = HealthMetric(
                name: "healthkit_environmental_audio_exposure_events_total",
                value: Double(audioEvents),
                type: .counter,
                labels: ["instance": deviceName],
                unit: HKUnit.count()
            )
            metrics.append(metric)
        }

        // Headphone Audio Exposure Events - 7-day limit breaches
        if let headphoneEventType = HKCategoryType.categoryType(forIdentifier: .headphoneAudioExposureEvent) {
            let headphoneEvents = await getCategoryCount(for: headphoneEventType, value: HKCategoryValueHeadphoneAudioExposureEvent.sevenDayLimit.rawValue, days: days)
            let metric = HealthMetric(
                name: "healthkit_headphone_audio_exposure_events_total",
                value: Double(headphoneEvents),
                type: .counter,
                labels: ["instance": deviceName],
                unit: HKUnit.count()
            )
            metrics.append(metric)
        }
        
        return metrics
    }
    
    private func collectWorkoutMetrics(days: Int = 1) async -> [HealthMetric] {
        var metrics: [HealthMetric] = []
        let deviceName = await UIDevice.current.name

        let workoutType = HKObjectType.workoutType()
        let workouts = await getTodaysWorkouts(for: workoutType, days: days)
        
        // Total workout minutes by activity type
        var workoutMinutesByType: [String: Double] = [:]
        var workoutCaloriesByType: [String: Double] = [:]
        
        for workout in workouts {
            let activityName = getWorkoutActivityName(workout.workoutActivityType)
            let duration = workout.duration / 60.0 // Convert to minutes
            
            workoutMinutesByType[activityName, default: 0] += duration
            
            if let energy = workout.totalEnergyBurned {
                let calories = energy.doubleValue(for: .kilocalorie())
                workoutCaloriesByType[activityName, default: 0] += calories
            }
        }
        
        // Create metrics for each workout type
        for (activity, minutes) in workoutMinutesByType {
            let metric = HealthMetric(
                name: "healthkit_workout_minutes_total",
                value: minutes,
                type: .counter,
                labels: [
                    "instance": deviceName,
                    "activity": activity
                ],
                unit: HKUnit.minute()
            )
            metrics.append(metric)
        }

        for (activity, calories) in workoutCaloriesByType {
            let metric = HealthMetric(
                name: "healthkit_workout_calories_total",
                value: calories,
                type: .counter,
                labels: [
                    "instance": deviceName,
                    "activity": activity
                ],
                unit: HKUnit.kilocalorie()
            )
            metrics.append(metric)
        }
        
        return metrics
    }
    
    private func collectActivitySummaryMetrics() async -> [HealthMetric] {
        var metrics: [HealthMetric] = []
        let deviceName = await UIDevice.current.name
        
        return await withCheckedContinuation { continuation in
            let calendar = Calendar.current
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)

            var dateComponents = calendar.dateComponents([.year, .month, .day], from: startOfDay)
            dateComponents.calendar = calendar  // IMPORTANT: Set calendar property
            let predicate = HKQuery.predicate(forActivitySummariesBetweenStart: dateComponents, end: dateComponents)
            
            let query = HKActivitySummaryQuery(predicate: predicate) { _, activitySummaries, error in
                if let error = error {
                    Logger.shared.log("Error querying activity summary: \(error)", level: .error)
                    continuation.resume(returning: [])
                    return
                }
                
                guard let summaries = activitySummaries, let todaysSummary = summaries.first else {
                    continuation.resume(returning: [])
                    return
                }
                
                // Move time (active energy) - in minutes (iOS 16.0+ only)
                if #available(iOS 16.0, *) {
                    let moveTime = todaysSummary.appleMoveTime
                    if moveTime.doubleValue(for: .minute()) > 0 {
                        let metric = HealthMetric(
                            name: "healthkit_apple_move_time_minutes",
                            value: moveTime.doubleValue(for: .minute()),
                            type: .gauge,
                            labels: ["instance": deviceName],
                            unit: .minute()
                        )
                        metrics.append(metric)
                    }
                    
                    let moveTimeGoal = todaysSummary.appleMoveTimeGoal
                    if moveTimeGoal.doubleValue(for: .minute()) > 0 {
                        let metric = HealthMetric(
                            name: "healthkit_apple_move_time_goal_minutes",
                            value: moveTimeGoal.doubleValue(for: .minute()),
                            type: .gauge,
                            labels: ["instance": deviceName],
                            unit: .minute()
                        )
                        metrics.append(metric)
                    }
                }
                
                // Active energy burned - in calories
                let activeCalories = todaysSummary.activeEnergyBurned.doubleValue(for: .kilocalorie())
                let activeCaloriesMetric = HealthMetric(
                    name: "healthkit_activity_summary_active_energy_burned_calories",
                    value: activeCalories,
                    type: .gauge,
                    labels: ["instance": deviceName],
                    unit: .kilocalorie()
                )
                metrics.append(activeCaloriesMetric)
                
                let activeCaloriesGoal = todaysSummary.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie())
                let activeCaloriesGoalMetric = HealthMetric(
                    name: "healthkit_activity_summary_active_energy_burned_goal_calories",
                    value: activeCaloriesGoal,
                    type: .gauge,
                    labels: ["instance": deviceName],
                    unit: .kilocalorie()
                )
                metrics.append(activeCaloriesGoalMetric)
                
                // Exercise time - in minutes
                let exerciseTime = todaysSummary.appleExerciseTime.doubleValue(for: .minute())
                let exerciseTimeMetric = HealthMetric(
                    name: "healthkit_activity_summary_exercise_time_minutes",
                    value: exerciseTime,
                    type: .gauge,
                    labels: ["instance": deviceName],
                    unit: .minute()
                )
                metrics.append(exerciseTimeMetric)
                
                let exerciseTimeGoal = todaysSummary.appleExerciseTimeGoal.doubleValue(for: .minute())
                let exerciseTimeGoalMetric = HealthMetric(
                    name: "healthkit_activity_summary_exercise_time_goal_minutes",
                    value: exerciseTimeGoal,
                    type: .gauge,
                    labels: ["instance": deviceName],
                    unit: .minute()
                )
                metrics.append(exerciseTimeGoalMetric)
                
                // Stand hours - in hours
                let standHours = todaysSummary.appleStandHours.doubleValue(for: .count())
                let standHoursMetric = HealthMetric(
                    name: "healthkit_activity_summary_stand_hours",
                    value: standHours,
                    type: .gauge,
                    labels: ["instance": deviceName],
                    unit: .count()
                )
                metrics.append(standHoursMetric)
                
                let standHoursGoal = todaysSummary.appleStandHoursGoal.doubleValue(for: .count())
                let standHoursGoalMetric = HealthMetric(
                    name: "healthkit_activity_summary_stand_hours_goal",
                    value: standHoursGoal,
                    type: .gauge,
                    labels: ["instance": deviceName],
                    unit: .count()
                )
                metrics.append(standHoursGoalMetric)
                
                continuation.resume(returning: metrics)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func collectLastSyncMetric() async -> HealthMetric? {
        let deviceName = await UIDevice.current.name
        return await MainActor.run {
            if let lastPushTime = UserDefaults.standard.object(forKey: "lastPushTime") as? Date {
                let secondsSinceLastSync = Date().timeIntervalSince(lastPushTime)
                
                return HealthMetric(
                    name: "healthkit_last_sync_seconds",
                    value: secondsSinceLastSync,
                    type: .gauge,
                    labels: ["instance": deviceName],
                    unit: HKUnit.second()
                )
            }
            return nil
        }
    }
    
    // Helper methods for data retrieval
    private func getMostRecentSample(for type: HKQuantityType) async -> HKQuantitySample? {
        await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let sample = samples?.first as? HKQuantitySample {
                    continuation.resume(returning: sample)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func getCumulativeSum(for type: HKQuantityType, unit: HKUnit, days: Int = 1) async -> Double? {
        await withCheckedContinuation { continuation in
            let calendar = Calendar.current
            let now = Date()
            let startDate = days == 1 ? calendar.startOfDay(for: now) : calendar.date(byAdding: .day, value: -days, to: now) ?? now
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
            
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let sum = statistics?.sumQuantity() {
                    continuation.resume(returning: sum.doubleValue(for: unit))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func getTodaysSleepMinutes(for type: HKCategoryType, days: Int = 1) async -> Double {
        await withCheckedContinuation { continuation in
            let calendar = Calendar.current
            let now = Date()
            let startDate = days == 1 ? calendar.startOfDay(for: now) : calendar.date(byAdding: .day, value: -days, to: now) ?? now
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
            
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }
                
                var totalMinutes: Double = 0
                for sample in samples {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60.0
                    totalMinutes += duration
                }
                
                continuation.resume(returning: totalMinutes)
            }
            healthStore.execute(query)
        }
    }
    
    private func getTodaysWorkouts(for type: HKSampleType, days: Int = 1) async -> [HKWorkout] {
        await withCheckedContinuation { continuation in
            let calendar = Calendar.current
            let now = Date()
            let startDate = days == 1 ? calendar.startOfDay(for: now) : calendar.date(byAdding: .day, value: -days, to: now) ?? now
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
            
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let workouts = samples as? [HKWorkout] {
                    continuation.resume(returning: workouts)
                } else {
                    continuation.resume(returning: [])
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func getUnit(for identifier: HKQuantityTypeIdentifier) -> HKUnit {
        switch identifier {
        // Count-based metrics
        case .stepCount, .flightsClimbed:
            return .count()
            
        // Distance metrics
        case .distanceWalkingRunning, .distanceCycling, .sixMinuteWalkTestDistance:
            return .meter()
        case .walkingStepLength:
            return .inch() // From JSON: "in"
            
        // Energy metrics  
        case .activeEnergyBurned, .basalEnergyBurned:
            return .kilocalorie()
            
        // Heart rate metrics (count/min)
        case .heartRate, .restingHeartRate, .walkingHeartRateAverage, .respiratoryRate:
            return .count().unitDivided(by: .minute())
            
        // Time-based metrics (minutes)
        case .appleExerciseTime, .appleStandTime:
            return .minute()
            
        // Percentage metrics
        case .oxygenSaturation, .bodyFatPercentage, .walkingDoubleSupportPercentage, .walkingAsymmetryPercentage, .appleWalkingSteadiness:
            return .percent()
            
        // Weight/mass metrics
        case .bodyMass:
            return .gramUnit(with: .kilo)
        case .bodyMassIndex:
            return .count() // BMI is unitless
            
        // Blood pressure (mmHg)
        case .bloodPressureSystolic, .bloodPressureDiastolic:
            return .millimeterOfMercury()
            
        // Blood glucose (mg/dL)
        case .bloodGlucose:
            return .gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
            
        // Speed metrics
        case .walkingSpeed:
            return .mile().unitDivided(by: .hour()) // From JSON: "mi/hr"
        case .stairAscentSpeed, .stairDescentSpeed:
            return .foot().unitDivided(by: .second()) // From JSON: "ft/s"
            
        // VO2 Max (mL/min·kg)
        case .vo2Max:
            return HKUnit.literUnit(with: .milli).unitDivided(by: .minute()).unitDivided(by: .gramUnit(with: .kilo))
            
        // Heart Rate Variability (ms)
        case .heartRateVariabilitySDNN:
            return .secondUnit(with: .milli)
            
        // Audio exposure (dBASPL)
        case .environmentalAudioExposure, .headphoneAudioExposure, .environmentalSoundReduction:
            return .decibelAWeightedSoundPressureLevel()
            
        default:
            // Physical effort (kcal/hr·kg) - iOS 17.0+ only
            if #available(iOS 17.0, *), identifier == .physicalEffort {
                return .kilocalorie().unitDivided(by: .hour()).unitDivided(by: .gramUnit(with: .kilo))
            }
            return .count()
        }
    }
    
    private func getWorkoutActivityName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "running"
        case .walking: return "walking"
        case .cycling: return "cycling"
        case .swimming: return "swimming"
        case .yoga: return "yoga"
        // Specific types from healthkit_types.json
        case .functionalStrengthTraining: return "functional_strength_training"
        case .traditionalStrengthTraining: return "traditional_strength_training"
        case .highIntensityIntervalTraining: return "hiit"
        default: return "other"
        }
    }
    
    private func getCategoryCount(for categoryType: HKCategoryType, value: Int, days: Int = 1) async -> Int {
        return await withCheckedContinuation { continuation in
            let calendar = Calendar.current
            let now = Date()
            let startDate = days == 1 ? calendar.startOfDay(for: now) : calendar.date(byAdding: .day, value: -days, to: now) ?? now

            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
            
            let query = HKSampleQuery(sampleType: categoryType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    Logger.shared.log("Error querying \(categoryType.identifier): \(error)", level: .error)
                    continuation.resume(returning: 0)
                    return
                }
                
                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }
                
                let count = categorySamples.filter { $0.value == value }.count
                continuation.resume(returning: count)
            }
            
            healthStore.execute(query)
        }
    }
}

struct HealthMetric {
    let name: String
    let value: Double
    let type: MetricType
    let labels: [String: String]
    let unit: HKUnit
}

enum MetricType {
    case gauge
    case counter
}