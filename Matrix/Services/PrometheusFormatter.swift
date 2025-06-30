import Foundation

class PrometheusFormatter {
    static func format(metrics: [HealthMetric]) -> String {
        var output = ""
        var processedMetrics = Set<String>()
        
        for metric in metrics {
            let metricKey = metric.name
            
            // Skip if we've already processed this metric type
            if processedMetrics.contains(metricKey) {
                continue
            }
            
            // Add HELP and TYPE lines only once per metric
            output += "# HELP \(metric.name) \(getHelpText(for: metric.name))\n"
            output += "# TYPE \(metric.name) \(metric.type == .counter ? "counter" : "gauge")\n"
            processedMetrics.insert(metricKey)
            
            // Find all metrics with the same name to group them
            let sameNameMetrics = metrics.filter { $0.name == metric.name }
            
            for m in sameNameMetrics {
                let labelString = formatLabels(m.labels)
                output += "\(m.name)\(labelString) \(formatValue(m.value))\n"
            }
            
            output += "\n"
        }
        
        return output
    }
    
    private static func formatLabels(_ labels: [String: String]) -> String {
        if labels.isEmpty {
            return ""
        }
        
        let formattedLabels = labels
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\"\(escapeLabelValue($0.value))\"" }
            .joined(separator: ",")
        
        return "{\(formattedLabels)}"
    }
    
    private static func escapeLabelValue(_ value: String) -> String {
        return value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
    
    private static func formatValue(_ value: Double) -> String {
        // Format numbers to avoid scientific notation for large values
        if value == Double(Int(value)) {
            return String(Int(value))
        } else {
            return String(format: "%.6f", value).trimmingCharacters(in: CharacterSet(charactersIn: "0")).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }
    }
    
    private static func getHelpText(for metricName: String) -> String {
        switch metricName {
        case "healthkit_steps_total":
            return "Total number of steps taken today"
        case "healthkit_distance_walking_running_meters_total":
            return "Total distance walked or run in meters today"
        case "healthkit_active_energy_burned_calories_total":
            return "Total active energy burned in calories today"
        case "healthkit_basal_energy_burned_calories_total":
            return "Total basal energy burned in calories today"
        case "healthkit_heart_rate_bpm":
            return "Most recent heart rate measurement in beats per minute"
        case "healthkit_resting_heart_rate_bpm":
            return "Most recent resting heart rate in beats per minute"
        case "healthkit_oxygen_saturation_percent":
            return "Most recent blood oxygen saturation percentage"
        case "healthkit_body_weight_kg":
            return "Most recent body weight measurement in kilograms"
        case "healthkit_body_mass_index":
            return "Most recent body mass index"
        case "healthkit_body_fat_percent":
            return "Most recent body fat percentage"
        case "healthkit_blood_pressure_systolic_mmhg":
            return "Most recent systolic blood pressure in mmHg"
        case "healthkit_blood_pressure_diastolic_mmhg":
            return "Most recent diastolic blood pressure in mmHg"
        case "healthkit_blood_glucose_mg_dl":
            return "Most recent blood glucose level in mg/dL"
        case "healthkit_sleep_minutes_total":
            return "Total sleep duration in minutes today"
        case "healthkit_workout_minutes_total":
            return "Total workout duration in minutes by activity type today"
        case "healthkit_workout_calories_total":
            return "Total calories burned during workouts by activity type today"
        default:
            return "Health metric from Apple HealthKit"
        }
    }
}