import SwiftUI
import HealthKit

struct MetricsOverviewView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showConfiguration = false
    @State private var metrics: [HealthMetric] = []
    @State private var improvingCount = 0
    @State private var trackedCount = 0
    @State private var lastSyncTime: Date?
    @State private var showAllMetrics = false

    private let healthKitManager = HealthKitManager.shared
    
    var body: some View {
        ZStack {
            Color.matrixBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Overview section
                        overviewSection
                            .padding(.horizontal, 24)
                            .padding(.bottom, 32)
                        
                        // Metrics list
                        metricsSection
                            .padding(.horizontal, 24)
                    }
                }
                
                Spacer()
                
                // Footer
                footer
            }
        }
        .sheet(isPresented: $showConfiguration) {
            MetricsConfigurationView()
                .onDisappear {
                    loadMetrics()
                }
        }
        .onAppear {
            loadMetrics()
        }
    }
    
    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                    Text("metrics")
                        .monospacedFont(size: 18)
                }
                .foregroundColor(.matrixPrimaryText)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: { showAllMetrics.toggle() }) {
                    Text(showAllMetrics ? "selected" : "all")
                        .monospacedFont(size: 12)
                        .foregroundColor(.matrixAccent)
                }

                Button(action: { showConfiguration = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18))
                        .foregroundColor(.matrixPrimaryText)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 60)
        .padding(.bottom, 32)
    }
    
    private var currentTime: some View {
        Text(formatCurrentTime())
            .monospacedFont(size: 14)
            .foregroundColor(.matrixAccent)
            .padding(.horizontal, 24)
    }
    
    private var overviewSection: some View {
        VStack(spacing: 16) {
            currentTime
            
            Text("today's overview")
                .monospacedFont(size: 16)
                .foregroundColor(.matrixPrimaryText)
            
            HStack(spacing: 8) {
                Text("\(improvingCount)")
                    .monospacedFont(size: 28, weight: .medium)
                    .foregroundColor(.matrixAccent)
                
                Text("improving")
                    .monospacedFont(size: 16)
                    .foregroundColor(.matrixPrimaryText)
                
                Text("•")
                    .monospacedFont(size: 16)
                    .foregroundColor(.matrixSecondaryText)
                
                Text("\(trackedCount)")
                    .monospacedFont(size: 28, weight: .medium)
                    .foregroundColor(.matrixAccent)
                
                Text("tracked")
                    .monospacedFont(size: 16)
                    .foregroundColor(.matrixPrimaryText)
            }
            
            if let lastSync = lastSyncTime {
                Text("last sync: \(formatTimeAgo(lastSync))")
                    .monospacedFont(size: 12)
                    .foregroundColor(.matrixSecondaryText)
            }
        }
    }
    
    private var metricsSection: some View {
        VStack(spacing: 24) {
            let selectedMetrics = getSelectedMetrics()

            if selectedMetrics.isEmpty {
                VStack(spacing: 16) {
                    Text("No metrics available yet")
                        .monospacedFont(size: 14)
                        .foregroundColor(.matrixSecondaryText)

                    Text("Debug: \(metrics.count) total metrics collected")
                        .monospacedFont(size: 12)
                        .foregroundColor(.matrixSecondaryText.opacity(0.7))

                    Button(action: {
                        loadMetrics()
                    }) {
                        Text("Refresh Metrics")
                            .monospacedFont(size: 12)
                            .foregroundColor(.matrixAccent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.matrixAccent, lineWidth: 1)
                            )
                    }
                }
                .padding(.vertical, 40)
            } else {
                ForEach(selectedMetrics, id: \.name) { metric in
                    metricRow(metric)
                }
            }
        }
    }
    
    private func metricRow(_ metric: HealthMetric) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.matrixAccent)
                        .frame(width: 8, height: 8)
                    
                    Text(getMetricDisplayName(metric.name))
                        .monospacedFont(size: 14)
                        .foregroundColor(.matrixPrimaryText)
                    
                    Spacer()
                    
                    Text(getPercentageChange(for: metric))
                        .monospacedFont(size: 12)
                        .foregroundColor(.matrixAccent)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatMetricValue(metric))
                            .monospacedFont(size: 20, weight: .medium)
                            .foregroundColor(.matrixPrimaryText)

                        Text(formatTimeAgo(Date()))
                            .monospacedFont(size: 10)
                            .foregroundColor(.matrixSecondaryText)
                    }

                    Spacer()
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.matrixAccent)
                    .frame(width: 12, height: 12)
                
                Text("\(trackedCount)")
                    .monospacedFont(size: 14)
                    .foregroundColor(.matrixPrimaryText)
            }
            
            Spacer()
            
            Text("healthkit sync")
                .monospacedFont(size: 12)
                .foregroundColor(.matrixSecondaryText)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
    
    private func loadMetrics() {
        Logger.shared.log("MetricsOverviewView: Loading metrics...", level: .info)

        // First try to load from cache immediately
        if let cachedMetrics = MetricCache.shared.getCachedMetrics() {
            let healthMetrics = cachedMetrics.map { $0.metric }
            Logger.shared.log("MetricsOverviewView: Loaded \(healthMetrics.count) cached metrics", level: .info)
            self.metrics = healthMetrics
            self.trackedCount = getSelectedMetrics().count
            self.improvingCount = calculateImprovingCount()
            self.lastSyncTime = cachedMetrics.first?.timestamp
        }

        // Then fetch fresh data in background
        Task {
            do {
                // Check if HealthKit is authorized
                guard healthKitManager.authorizationStatus() == "Authorized" else {
                    Logger.shared.log("MetricsOverviewView: HealthKit not authorized", level: .warning)
                    return
                }

                let todayMetrics = try await healthKitManager.collectAllMetrics()
                Logger.shared.log("MetricsOverviewView: Collected \(todayMetrics.count) fresh metrics", level: .info)

                await MainActor.run {
                    self.metrics = todayMetrics
                    self.trackedCount = getSelectedMetrics().count
                    self.improvingCount = calculateImprovingCount()
                    self.lastSyncTime = Date()
                }
            } catch {
                Logger.shared.log("MetricsOverviewView: Failed to load metrics: \(error)", level: .error)

                await MainActor.run {
                    // Keep cached metrics if fresh fetch fails
                    if self.metrics.isEmpty {
                        self.trackedCount = 0
                        self.improvingCount = 0
                    }
                }
            }
        }
    }
    
    private func getSelectedMetrics() -> [HealthMetric] {
        if showAllMetrics {
            return metrics
        }
        let selectedMetricNames = getSelectedMetricNames()
        return metrics.filter { selectedMetricNames.contains($0.name) }
    }
    
    private func getSelectedMetricNames() -> Set<String> {
        let defaults = UserDefaults.standard
        let selectedMetrics = defaults.array(forKey: "selectedMetrics") as? [String] ?? [
            "healthkit_steps_total",
            "healthkit_heart_rate_bpm", 
            "healthkit_resting_heart_rate_bpm",
            "healthkit_sleep_minutes_total",
            "healthkit_basal_energy_burned_calories_total",
            "healthkit_distance_walking_running_meters_total",
            "healthkit_active_energy_burned_calories_total",
            "healthkit_oxygen_saturation_percent",
            "healthkit_body_weight_kg",
            "healthkit_body_mass_index",
            "healthkit_last_sync_seconds"
        ]
        return Set(selectedMetrics)
    }
    
    private func calculateImprovingCount() -> Int {
        // Simplified logic - count metrics with positive percentage
        return getSelectedMetrics().filter { metric in
            let percentage = getPercentageChange(for: metric)
            return percentage.contains("+")
        }.count
    }
    
    private func getMetricDisplayName(_ name: String) -> String {
        switch name {
        case "healthkit_steps_total": return "steps"
        case "healthkit_heart_rate_bpm": return "heart rate"
        case "healthkit_resting_heart_rate_bpm": return "resting hr"
        case "healthkit_sleep_minutes_total": return "sleep"
        case "healthkit_active_energy_burned_calories_total": return "active energy"
        case "healthkit_distance_walking_running_meters_total": return "distance"
        case "healthkit_basal_energy_burned_calories_total": return "basal energy"
        case "healthkit_oxygen_saturation_percent": return "oxygen saturation"
        case "healthkit_body_weight_kg": return "weight"
        case "healthkit_body_mass_index": return "BMI"
        case "healthkit_body_fat_percent": return "body fat %"
        case "healthkit_blood_pressure_systolic_mmhg": return "blood pressure sys"
        case "healthkit_blood_pressure_diastolic_mmhg": return "blood pressure dia"
        case "healthkit_blood_glucose_mg_dl": return "blood glucose"
        case "healthkit_walking_speed_ms": return "walking speed"
        case "healthkit_walking_step_length_meters": return "step length"
        case "healthkit_walking_double_support_percent": return "double support %"
        case "healthkit_walking_asymmetry_percent": return "walking asymmetry"
        case "healthkit_stair_ascent_speed_ms": return "stair ascent speed"
        case "healthkit_stair_descent_speed_ms": return "stair descent speed"
        case "healthkit_six_minute_walk_distance_meters": return "6min walk distance"
        case "healthkit_last_sync_seconds": return "last sync"
        default: return name.replacingOccurrences(of: "healthkit_", with: "").replacingOccurrences(of: "_", with: " ")
        }
    }
    
    private func formatMetricValue(_ metric: HealthMetric) -> String {
        switch metric.name {
        // Core activity metrics
        case "healthkit_steps_total":
            return String(format: "%.0f", metric.value)
        case "healthkit_flights_climbed_total":
            return String(format: "%.0f", metric.value)
        case "healthkit_distance_walking_running_meters_total", "healthkit_six_minute_walk_distance_meters":
            return String(format: "%.1f km", metric.value / 1000)
        case "healthkit_active_energy_burned_calories_total", "healthkit_basal_energy_burned_calories_total":
            return String(format: "%.0f kcal", metric.value)
        case "healthkit_apple_exercise_time_minutes_total", "healthkit_apple_stand_time_minutes_total":
            let hours = Int(metric.value / 60)
            let minutes = Int(metric.value.truncatingRemainder(dividingBy: 60))
            return "\(hours)h \(minutes)m"
            
        // Heart health metrics
        case "healthkit_heart_rate_bpm", "healthkit_resting_heart_rate_bpm", "healthkit_walking_heart_rate_average_bpm", "healthkit_respiratory_rate_bpm":
            return "\(Int(metric.value)) bpm"
        case "healthkit_heart_rate_variability_sdnn_ms":
            return String(format: "%.1f ms", metric.value)
        case "healthkit_vo2_max_ml_min_kg":
            return String(format: "%.1f mL/kg/min", metric.value)
            
        // Body metrics
        case "healthkit_body_weight_kg":
            return String(format: "%.1f kg", metric.value)
        case "healthkit_body_mass_index":
            return String(format: "%.1f", metric.value)
        case "healthkit_oxygen_saturation_percent", "healthkit_body_fat_percent", 
             "healthkit_walking_double_support_percent", "healthkit_walking_asymmetry_percent", 
             "healthkit_apple_walking_steadiness_percent":
            return String(format: "%.1f%%", metric.value * 100)
        case "healthkit_blood_pressure_systolic_mmhg", "healthkit_blood_pressure_diastolic_mmhg":
            return String(format: "%.0f mmHg", metric.value)
        case "healthkit_blood_glucose_mg_dl":
            return String(format: "%.0f mg/dL", metric.value)
            
        // Walking & mobility metrics
        case "healthkit_walking_speed_mph":
            return String(format: "%.1f mph", metric.value)
        case "healthkit_walking_step_length_inches":
            return String(format: "%.1f in", metric.value)
        case "healthkit_stair_ascent_speed_fps", "healthkit_stair_descent_speed_fps":
            return String(format: "%.2f ft/s", metric.value)
            
        // Audio health metrics
        case "healthkit_environmental_audio_exposure_db", "healthkit_headphone_audio_exposure_db", 
             "healthkit_environmental_sound_reduction_db":
            return String(format: "%.1f dB", metric.value)
            
        // Physical effort
        case "healthkit_physical_effort_kcal_hr_kg":
            return String(format: "%.1f", metric.value)
            
        // Sleep
        case "healthkit_sleep_minutes_total":
            let hours = Int(metric.value / 60)
            let minutes = Int(metric.value.truncatingRemainder(dividingBy: 60))
            return "\(hours)h \(minutes)m"
            
        // Category metrics (counts)
        case "healthkit_apple_stand_hours_total", "healthkit_environmental_audio_exposure_events_total", 
             "healthkit_headphone_audio_exposure_events_total":
            return String(format: "%.0f", metric.value)
            
        // Activity summary metrics
        case "healthkit_apple_move_time_minutes", "healthkit_apple_move_time_goal_minutes",
             "healthkit_activity_summary_exercise_time_minutes", "healthkit_activity_summary_exercise_time_goal_minutes":
            let hours = Int(metric.value / 60)
            let minutes = Int(metric.value.truncatingRemainder(dividingBy: 60))
            return "\(hours)h \(minutes)m"
        case "healthkit_activity_summary_active_energy_burned_calories", "healthkit_activity_summary_active_energy_burned_goal_calories":
            return String(format: "%.0f kcal", metric.value)
        case "healthkit_activity_summary_stand_hours", "healthkit_activity_summary_stand_hours_goal":
            return String(format: "%.0f hrs", metric.value)
            
        // Workout metrics
        case "healthkit_workout_minutes_total":
            let hours = Int(metric.value / 60)
            let minutes = Int(metric.value.truncatingRemainder(dividingBy: 60))
            return "\(hours)h \(minutes)m"
        case "healthkit_workout_calories_total":
            return String(format: "%.0f kcal", metric.value)
            
        // System metrics
        case "healthkit_last_sync_seconds":
            let seconds = Int(metric.value)
            if seconds < 60 {
                return "\(seconds)s"
            } else if seconds < 3600 {
                return "\(seconds / 60)m"
            } else if seconds < 86400 {
                return "\(seconds / 3600)h"
            } else {
                return "\(seconds / 86400)d"
            }
            
        default:
            return String(format: "%.1f", metric.value)
        }
    }
    
    private func getMetricUnit(_ name: String) -> String {
        switch name {
        case "healthkit_steps_total": return "steps"
        case "healthkit_heart_rate_bpm", "healthkit_resting_heart_rate_bpm": return "bpm"
        case "healthkit_sleep_minutes_total": return "hours"
        case "healthkit_active_energy_burned_calories_total", "healthkit_basal_energy_burned_calories_total": return "kcal"
        case "healthkit_distance_walking_running_meters_total", "healthkit_six_minute_walk_distance_meters": return "km"
        case "healthkit_oxygen_saturation_percent", "healthkit_body_fat_percent", "healthkit_walking_double_support_percent", "healthkit_walking_asymmetry_percent": return "%"
        case "healthkit_body_weight_kg": return "kg"
        case "healthkit_body_mass_index": return ""
        case "healthkit_blood_pressure_systolic_mmhg", "healthkit_blood_pressure_diastolic_mmhg": return "mmHg"
        case "healthkit_blood_glucose_mg_dl": return "mg/dL"
        case "healthkit_walking_speed_ms", "healthkit_stair_ascent_speed_ms", "healthkit_stair_descent_speed_ms": return "m/s"
        case "healthkit_walking_step_length_meters": return "cm"
        case "healthkit_last_sync_seconds": return "ago"
        default: return ""
        }
    }
    
    private func getPercentageChange(for metric: HealthMetric) -> String {
        // Mock percentage changes for demo
        let changes = ["+15%", "-4%", "-2%", "+3%", "+12%", "+5%", "0%", "-13%"]
        let index = abs(metric.name.hashValue) % changes.count
        return changes[index]
    }
    
    private func formatCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: Date()).lowercased()
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "\(seconds)s ago"
        } else if seconds < 3600 {
            return "\(seconds / 60)m ago"
        } else {
            return "\(seconds / 3600)h ago"
        }
    }
}