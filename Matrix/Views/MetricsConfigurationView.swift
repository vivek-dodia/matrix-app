import SwiftUI

struct MetricsConfigurationView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedMetrics: Set<String> = []
    
    private let availableMetrics = [
        // Core activity metrics
        ("healthkit_steps_total", "steps"),
        ("healthkit_distance_walking_running_meters_total", "distance"),
        ("healthkit_flights_climbed_total", "flights climbed"),
        ("healthkit_active_energy_burned_calories_total", "active energy"),
        ("healthkit_basal_energy_burned_calories_total", "basal energy"),
        ("healthkit_apple_exercise_time_minutes_total", "exercise time"),
        ("healthkit_apple_stand_time_minutes_total", "stand time"),
        
        // Heart health metrics
        ("healthkit_heart_rate_bpm", "heart rate"),
        ("healthkit_resting_heart_rate_bpm", "resting hr"),
        ("healthkit_walking_heart_rate_average_bpm", "walking hr avg"),
        ("healthkit_heart_rate_variability_sdnn_ms", "hrv (sdnn)"),
        ("healthkit_respiratory_rate_bpm", "respiratory rate"),
        ("healthkit_vo2_max_ml_min_kg", "vo2 max"),
        
        // Body metrics
        ("healthkit_body_weight_kg", "weight"),
        ("healthkit_body_mass_index", "BMI"),
        ("healthkit_body_fat_percent", "body fat %"),
        ("healthkit_oxygen_saturation_percent", "oxygen saturation"),
        ("healthkit_blood_pressure_systolic_mmhg", "blood pressure sys"),
        ("healthkit_blood_pressure_diastolic_mmhg", "blood pressure dia"),
        ("healthkit_blood_glucose_mg_dl", "blood glucose"),
        
        // Walking & mobility metrics
        ("healthkit_walking_speed_mph", "walking speed"),
        ("healthkit_walking_step_length_inches", "step length"),
        ("healthkit_walking_double_support_percent", "double support %"),
        ("healthkit_walking_asymmetry_percent", "walking asymmetry"),
        ("healthkit_apple_walking_steadiness_percent", "walking steadiness"),
        ("healthkit_stair_ascent_speed_fps", "stair ascent speed"),
        ("healthkit_stair_descent_speed_fps", "stair descent speed"),
        ("healthkit_six_minute_walk_distance_meters", "6min walk distance"),
        
        // Audio health metrics
        ("healthkit_environmental_audio_exposure_db", "environmental audio"),
        ("healthkit_headphone_audio_exposure_db", "headphone audio"),
        ("healthkit_environmental_sound_reduction_db", "sound reduction"),
        
        // Physical effort
        ("healthkit_physical_effort_kcal_hr_kg", "physical effort"),
        
        // Sleep & wellness
        ("healthkit_sleep_minutes_total", "sleep"),
        
        // Category metrics
        ("healthkit_apple_stand_hours_total", "stand hours"),
        ("healthkit_environmental_audio_exposure_events_total", "audio events"),
        ("healthkit_headphone_audio_exposure_events_total", "headphone events"),
        
        // Activity summary metrics
        ("healthkit_apple_move_time_minutes", "move time"),
        ("healthkit_apple_move_time_goal_minutes", "move time goal"),
        ("healthkit_activity_summary_active_energy_burned_calories", "summary: active energy"),
        ("healthkit_activity_summary_active_energy_burned_goal_calories", "summary: energy goal"),
        ("healthkit_activity_summary_exercise_time_minutes", "summary: exercise time"),
        ("healthkit_activity_summary_exercise_time_goal_minutes", "summary: exercise goal"),
        ("healthkit_activity_summary_stand_hours", "summary: stand hours"),
        ("healthkit_activity_summary_stand_hours_goal", "summary: stand goal"),
        
        // Workout metrics (dynamic based on activity type)
        ("healthkit_workout_minutes_total", "workout duration"),
        ("healthkit_workout_calories_total", "workout calories"),
        
        // System metrics
        ("healthkit_last_sync_seconds", "last sync")
    ]
    
    var body: some View {
        ZStack {
            Color.matrixBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                // Description
                descriptionSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                // Select All / Deselect All buttons
                selectionButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(availableMetrics, id: \.0) { metric in
                            metricSelectionRow(metric.0, metric.1)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100)
                }
                
                Spacer()
                
                // Done button
                doneButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            loadSelectedMetrics()
        }
    }
    
    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                    Text("metric settings")
                        .monospacedFont(size: 18)
                }
                .foregroundColor(.matrixPrimaryText)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 60)
        .padding(.bottom, 32)
    }
    
    private var descriptionSection: some View {
        VStack(spacing: 8) {
            Text("select metrics to display")
                .monospacedFont(size: 16)
                .foregroundColor(.matrixPrimaryText)
            
            Text("\(selectedMetrics.count) of \(availableMetrics.count) selected")
                .monospacedFont(size: 14)
                .foregroundColor(.matrixSecondaryText)
        }
    }
    
    private func metricSelectionRow(_ metricKey: String, _ displayName: String) -> some View {
        Button(action: {
            toggleMetric(metricKey)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        // Checkbox
                        RoundedRectangle(cornerRadius: 2)
                            .fill(selectedMetrics.contains(metricKey) ? Color.matrixAccent : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(selectedMetrics.contains(metricKey) ? Color.matrixAccent : Color.matrixSecondaryText, lineWidth: 2)
                            )
                            .frame(width: 16, height: 16)
                        
                        Text(displayName)
                            .monospacedFont(size: 14)
                            .foregroundColor(.matrixPrimaryText)
                        
                        Spacer()
                        
                        Text(getPercentageChange(for: metricKey))
                            .monospacedFont(size: 12)
                            .foregroundColor(.matrixAccent)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var selectionButtons: some View {
        HStack(spacing: 12) {
            Button(action: selectAll) {
                Text("select all")
                    .monospacedFont(size: 12)
                    .foregroundColor(.matrixPrimaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(
                        Rectangle()
                            .stroke(Color.matrixSecondaryText, lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: deselectAll) {
                Text("deselect all")
                    .monospacedFont(size: 12)
                    .foregroundColor(.matrixPrimaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(
                        Rectangle()
                            .stroke(Color.matrixSecondaryText, lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var doneButton: some View {
        Button(action: saveAndDismiss) {
            Text("Done")
                .monospacedFont(size: 14, weight: .medium)
                .foregroundColor(.matrixBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.matrixAccent)
                .cornerRadius(8)
        }
    }

    private func selectAll() {
        selectedMetrics = Set(availableMetrics.map { $0.0 })
    }

    private func deselectAll() {
        selectedMetrics.removeAll()
    }

    private func toggleMetric(_ metricKey: String) {
        if selectedMetrics.contains(metricKey) {
            selectedMetrics.remove(metricKey)
        } else {
            selectedMetrics.insert(metricKey)
        }
    }
    
    private func loadSelectedMetrics() {
        let defaults = UserDefaults.standard
        let saved = defaults.array(forKey: "selectedMetrics") as? [String] ?? [
            "healthkit_steps_total",
            "healthkit_heart_rate_bpm",
            "healthkit_sleep_analysis",
            "healthkit_basal_energy_burned_calories_total",
            "healthkit_distance_walking_running_meters_total",
            "healthkit_active_energy_burned_calories_total",
            "healthkit_stand_hours",
            "healthkit_exercise_time"
        ]
        selectedMetrics = Set(saved)
    }
    
    private func saveAndDismiss() {
        UserDefaults.standard.set(Array(selectedMetrics), forKey: "selectedMetrics")
        dismiss()
    }
    
    private func getPercentageChange(for metricKey: String) -> String {
        // Mock percentage changes matching the design
        let changes: [String: String] = [
            "healthkit_steps_total": "+15%",
            "healthkit_heart_rate_bpm": "-4%",
            "healthkit_sleep_analysis": "-2%",
            "healthkit_active_energy_burned_calories_total": "+3%",
            "healthkit_distance_walking_running_meters_total": "+12%",
            "healthkit_basal_energy_burned_calories_total": "+5%",
            "healthkit_stand_hours": "0%",
            "healthkit_exercise_time": "-13%",
            "healthkit_flights_climbed": "+9%",
            "healthkit_walking_speed": "+5%",
            "healthkit_vo2_max": "0%",
            "healthkit_resting_heart_rate_bpm": "-6%"
        ]
        return changes[metricKey] ?? "0%"
    }
    
}