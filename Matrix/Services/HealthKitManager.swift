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
    private var allHealthKitTypes: Set<HKSampleType> {
        var types = Set<HKSampleType>()
        
        // Quantity types
        let quantityTypes: [HKQuantityTypeIdentifier] = [
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
            .waistCircumference
        ]
        
        for identifier in quantityTypes {
            if let type = HKQuantityType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
        }
        
        // Category types
        let categoryTypes: [HKCategoryTypeIdentifier] = [
            .sleepAnalysis,
            .appleStandHour,
            .mindfulSession,
            .highHeartRateEvent,
            .lowHeartRateEvent,
            .irregularHeartRhythmEvent,
            .audioExposureEvent,
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
        
        healthStore.requestAuthorization(toShare: nil, read: allHealthKitTypes) { [weak self] success, error in
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
        let query = HKObserverQuery(sampleType: quantityType, predicate: nil) { [weak self] query, completionHandler, error in
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
    
    func collectAllMetrics() async throws -> [HealthMetric] {
        var metrics: [HealthMetric] = []
        
        // Try to collect fresh metrics with retry logic
        for attempt in 1...3 {
            // Collect quantity type metrics
            let quantityMetrics = await collectQuantityMetrics()
            metrics.append(contentsOf: quantityMetrics)
            
            // Collect category metrics
            let categoryMetrics = await collectCategoryMetrics()
            metrics.append(contentsOf: categoryMetrics)
            
            // Collect workout metrics
            let workoutMetrics = await collectWorkoutMetrics()
            metrics.append(contentsOf: workoutMetrics)
            
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
    
    private func collectQuantityMetrics() async -> [HealthMetric] {
        var metrics: [HealthMetric] = []
        
        let quantityTypes: [(HKQuantityTypeIdentifier, String, MetricType)] = [
            (.stepCount, "steps", .counter),
            (.distanceWalkingRunning, "distance_walking_running_meters", .counter),
            (.activeEnergyBurned, "active_energy_burned_calories", .counter),
            (.basalEnergyBurned, "basal_energy_burned_calories", .counter),
            (.heartRate, "heart_rate_bpm", .gauge),
            (.restingHeartRate, "resting_heart_rate_bpm", .gauge),
            (.oxygenSaturation, "oxygen_saturation_percent", .gauge),
            (.bodyMass, "body_weight_kg", .gauge),
            (.bodyMassIndex, "body_mass_index", .gauge),
            (.bodyFatPercentage, "body_fat_percent", .gauge),
            (.bloodPressureSystolic, "blood_pressure_systolic_mmhg", .gauge),
            (.bloodPressureDiastolic, "blood_pressure_diastolic_mmhg", .gauge),
            (.bloodGlucose, "blood_glucose_mg_dl", .gauge)
        ]
        
        for (identifier, metricName, metricType) in quantityTypes {
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { continue }
            
            if metricType == .counter {
                // Get cumulative sum for counters
                if let value = await getCumulativeSum(for: quantityType, unit: getUnit(for: identifier)) {
                    let metric = HealthMetric(
                        name: "healthkit_\(metricName)_total",
                        value: value,
                        type: metricType,
                        labels: ["instance": UIDevice.current.name],
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
                            "instance": UIDevice.current.name,
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
    
    private func collectCategoryMetrics() async -> [HealthMetric] {
        var metrics: [HealthMetric] = []
        
        // Sleep analysis
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            let sleepMinutes = await getTodaysSleepMinutes(for: sleepType)
            if sleepMinutes > 0 {
                let metric = HealthMetric(
                    name: "healthkit_sleep_minutes_total",
                    value: sleepMinutes,
                    type: .counter,
                    labels: ["instance": UIDevice.current.name],
                    unit: HKUnit.minute()
                )
                metrics.append(metric)
            }
        }
        
        return metrics
    }
    
    private func collectWorkoutMetrics() async -> [HealthMetric] {
        var metrics: [HealthMetric] = []
        
        let workoutType = HKObjectType.workoutType()
        let workouts = await getTodaysWorkouts(for: workoutType)
        
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
                    "instance": UIDevice.current.name,
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
                    "instance": UIDevice.current.name,
                    "activity": activity
                ],
                unit: HKUnit.kilocalorie()
            )
            metrics.append(metric)
        }
        
        return metrics
    }
    
    private func collectLastSyncMetric() async -> HealthMetric? {
        return await MainActor.run {
            if let lastPushTime = UserDefaults.standard.object(forKey: "lastPushTime") as? Date {
                let secondsSinceLastSync = Date().timeIntervalSince(lastPushTime)
                
                return HealthMetric(
                    name: "healthkit_last_sync_seconds",
                    value: secondsSinceLastSync,
                    type: .gauge,
                    labels: ["instance": UIDevice.current.name],
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
    
    private func getCumulativeSum(for type: HKQuantityType, unit: HKUnit) async -> Double? {
        await withCheckedContinuation { continuation in
            let calendar = Calendar.current
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
            
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
    
    private func getTodaysSleepMinutes(for type: HKCategoryType) async -> Double {
        await withCheckedContinuation { continuation in
            let calendar = Calendar.current
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
            
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
    
    private func getTodaysWorkouts(for type: HKSampleType) async -> [HKWorkout] {
        await withCheckedContinuation { continuation in
            let calendar = Calendar.current
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
            
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
        case .stepCount:
            return .count()
        case .distanceWalkingRunning, .distanceCycling:
            return .meter()
        case .activeEnergyBurned, .basalEnergyBurned:
            return .kilocalorie()
        case .heartRate, .restingHeartRate, .walkingHeartRateAverage:
            return .count().unitDivided(by: .minute())
        case .oxygenSaturation, .bodyFatPercentage:
            return .percent()
        case .bodyMass:
            return .gramUnit(with: .kilo)
        case .bodyMassIndex:
            return .count()
        case .bloodPressureSystolic, .bloodPressureDiastolic:
            return .millimeterOfMercury()
        case .bloodGlucose:
            return .gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
        default:
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
        case .functionalStrengthTraining: return "strength_training"
        case .traditionalStrengthTraining: return "strength_training"
        case .highIntensityIntervalTraining: return "hiit"
        default: return "other"
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