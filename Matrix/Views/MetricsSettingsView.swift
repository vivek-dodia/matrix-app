import SwiftUI
import HealthKit

struct MetricsSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedMetrics: Set<String> = []
    @State private var allMetrics: [MetricOption] = []
    @State private var isLoading = true

    private var isAllSelected: Bool {
        selectedMetrics.count == allMetrics.count
    }

    var body: some View {
        ZStack {
            Color.matrixBackground
                .ignoresSafeArea()

            if isLoading {
                VStack {
                    ProgressView()
                        .tint(.matrixAccent)
                    Text("loading metrics...")
                        .monospacedFont(size: 12)
                        .foregroundColor(.matrixSecondaryText)
                        .padding(.top, 8)
                }
            } else {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.matrixPrimaryText)
                        }

                        Text("metric settings")
                            .monospacedFont(size: 18, weight: .semibold)
                            .foregroundColor(.matrixPrimaryText)

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .padding(.bottom, 16)

                    // Subtitle and Select All
                    VStack(spacing: 8) {
                        Text("select metrics to display")
                            .monospacedFont(size: 12)
                            .foregroundColor(.matrixSecondaryText)

                        HStack(spacing: 16) {
                            Text("\(selectedMetrics.count) of \(allMetrics.count) selected")
                                .monospacedFont(size: 12)
                                .foregroundColor(.matrixSecondaryText)

                            Text("•")
                                .monospacedFont(size: 12)
                                .foregroundColor(.matrixSecondaryText)

                            Button(action: toggleSelectAll) {
                                Text(isAllSelected ? "deselect all" : "select all")
                                    .monospacedFont(size: 12, weight: .medium)
                                    .foregroundColor(.matrixAccent)
                            }
                        }
                    }
                    .padding(.bottom, 20)

                    // Metrics list
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(allMetrics) { metric in
                                MetricOptionRow(
                                    metric: metric,
                                    isSelected: selectedMetrics.contains(metric.id),
                                    percentChange: getRandomPercentChange()
                                ) {
                                    toggleMetric(metric.id)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }
                        }
                    }

                    Spacer()

                    // Done button
                    Button(action: saveAndDismiss) {
                        Text("Done")
                            .monospacedFont(size: 14, weight: .medium)
                            .foregroundColor(Color.matrixBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.matrixAccent)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            loadAllMetrics()
            loadSelectedMetrics()
        }
    }

    private func loadAllMetrics() {
        var metrics: [MetricOption] = []

        // Quantity Types - All comprehensive metrics
        let quantityMetrics: [(HKQuantityTypeIdentifier, String, String)] = [
            // Activity & Movement
            (.stepCount, "step_count", "Steps"),
            (.distanceWalkingRunning, "distance_walking_running", "Walking/Running Distance"),
            (.distanceCycling, "distance_cycling", "Cycling Distance"),
            (.flightsClimbed, "flights_climbed", "Flights Climbed"),
            (.appleExerciseTime, "exercise_time", "Exercise Time"),
            (.appleStandTime, "stand_time", "Stand Time"),

            // Energy & Calories
            (.activeEnergyBurned, "active_energy", "Active Energy"),
            (.basalEnergyBurned, "basal_energy", "Basal Energy"),

            // Heart Metrics
            (.heartRate, "heart_rate", "Heart Rate"),
            (.restingHeartRate, "resting_heart_rate", "Resting Heart Rate"),
            (.walkingHeartRateAverage, "walking_heart_rate", "Walking Heart Rate"),
            (.heartRateVariabilitySDNN, "hrv", "Heart Rate Variability"),

            // Respiratory & Vitals
            (.respiratoryRate, "respiratory_rate", "Respiratory Rate"),
            (.oxygenSaturation, "oxygen_saturation", "Blood Oxygen"),
            (.bodyTemperature, "body_temperature", "Body Temperature"),
            (.bloodPressureSystolic, "blood_pressure_systolic", "Blood Pressure (Systolic)"),
            (.bloodPressureDiastolic, "blood_pressure_diastolic", "Blood Pressure (Diastolic)"),

            // Body Measurements
            (.bodyMass, "body_mass", "Body Mass"),
            (.bodyMassIndex, "bmi", "Body Mass Index"),
            (.bodyFatPercentage, "body_fat_percentage", "Body Fat %"),
            (.height, "height", "Height"),
            (.waistCircumference, "waist_circumference", "Waist Circumference"),

            // Metabolic
            (.bloodGlucose, "blood_glucose", "Blood Glucose"),
            (.vo2Max, "vo2_max", "VO2 Max"),

            // Mobility & Gait
            (.walkingSpeed, "walking_speed", "Walking Speed"),
            (.walkingStepLength, "walking_step_length", "Step Length"),
            (.walkingDoubleSupportPercentage, "walking_double_support", "Double Support %"),
            (.walkingAsymmetryPercentage, "walking_asymmetry", "Walking Asymmetry %"),
            (.appleWalkingSteadiness, "walking_steadiness", "Walking Steadiness"),
            (.stairAscentSpeed, "stair_ascent_speed", "Stair Ascent Speed"),
            (.stairDescentSpeed, "stair_descent_speed", "Stair Descent Speed"),
            (.sixMinuteWalkTestDistance, "six_minute_walk", "6-Minute Walk Distance"),

            // Audio & Environment
            (.environmentalAudioExposure, "environmental_audio", "Environmental Audio"),
            (.headphoneAudioExposure, "headphone_audio", "Headphone Audio"),
            (.environmentalSoundReduction, "sound_reduction", "Sound Reduction")
        ]

        for (identifier, id, name) in quantityMetrics {
            if HKQuantityType.quantityType(forIdentifier: identifier) != nil {
                metrics.append(MetricOption(id: id, name: name, isAvailable: true, category: "quantity"))
            }
        }

        // iOS 17+ metrics
        if #available(iOS 17.0, *) {
            if HKQuantityType.quantityType(forIdentifier: .physicalEffort) != nil {
                metrics.append(MetricOption(id: "physical_effort", name: "Physical Effort", isAvailable: true, category: "quantity"))
            }
        }

        // Category Types
        let categoryMetrics: [(HKCategoryTypeIdentifier, String, String)] = [
            (.sleepAnalysis, "sleep", "Sleep Analysis"),
            (.appleStandHour, "stand_hour", "Stand Hour"),
            (.mindfulSession, "mindful_session", "Mindful Session"),
            (.highHeartRateEvent, "high_heart_rate_event", "High Heart Rate Event"),
            (.lowHeartRateEvent, "low_heart_rate_event", "Low Heart Rate Event"),
            (.irregularHeartRhythmEvent, "irregular_rhythm_event", "Irregular Heart Rhythm"),
            (.toothbrushingEvent, "toothbrushing", "Toothbrushing"),
        ]

        for (identifier, id, name) in categoryMetrics {
            if HKCategoryType.categoryType(forIdentifier: identifier) != nil {
                metrics.append(MetricOption(id: id, name: name, isAvailable: true, category: "category"))
            }
        }

        // Workout Types
        let workoutTypes: [(String, String)] = [
            ("workout_walking", "Walking Workout"),
            ("workout_running", "Running Workout"),
            ("workout_cycling", "Cycling Workout"),
            ("workout_swimming", "Swimming Workout"),
            ("workout_strength", "Strength Training"),
            ("workout_functional", "Functional Training"),
            ("workout_hiit", "HIIT Workout"),
            ("workout_yoga", "Yoga"),
            ("workout_core", "Core Training"),
            ("workout_flexibility", "Flexibility"),
            ("workout_cooldown", "Cooldown"),
            ("workout_elliptical", "Elliptical"),
            ("workout_rowing", "Rowing"),
            ("workout_stairs", "Stair Climbing"),
            ("workout_other", "Other Workouts")
        ]

        for (id, name) in workoutTypes {
            metrics.append(MetricOption(id: id, name: name, isAvailable: true, category: "workout"))
        }

        // Activity Summary
        metrics.append(MetricOption(id: "activity_move_ring", name: "Move Ring Progress", isAvailable: true, category: "activity"))
        metrics.append(MetricOption(id: "activity_exercise_ring", name: "Exercise Ring Progress", isAvailable: true, category: "activity"))
        metrics.append(MetricOption(id: "activity_stand_ring", name: "Stand Ring Progress", isAvailable: true, category: "activity"))

        allMetrics = metrics.sorted { $0.name < $1.name }
        isLoading = false
    }

    private func toggleSelectAll() {
        if isAllSelected {
            // Deselect all
            selectedMetrics.removeAll()
        } else {
            // Select all
            selectedMetrics = Set(allMetrics.map { $0.id })
        }
    }

    private func toggleMetric(_ metricId: String) {
        if selectedMetrics.contains(metricId) {
            selectedMetrics.remove(metricId)
        } else {
            selectedMetrics.insert(metricId)
        }
    }

    private func loadSelectedMetrics() {
        if let saved = UserDefaults.standard.array(forKey: "selectedMetrics") as? [String] {
            selectedMetrics = Set(saved)
        } else {
            // Default selection - common metrics
            selectedMetrics = Set([
                "step_count", "heart_rate", "sleep", "active_energy",
                "distance_walking_running", "exercise_time", "stand_time", "flights_climbed"
            ])
        }
    }

    private func saveAndDismiss() {
        UserDefaults.standard.set(Array(selectedMetrics), forKey: "selectedMetrics")
        dismiss()
    }

    private func getRandomPercentChange() -> Int {
        return Int.random(in: -15...15)
    }
}

struct MetricOption: Identifiable {
    let id: String
    let name: String
    let isAvailable: Bool
    let category: String
}

struct MetricOptionRow: View {
    let metric: MetricOption
    let isSelected: Bool
    let percentChange: Int
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.matrixAccent : Color.matrixSecondaryText, lineWidth: 2)
                        .frame(width: 20, height: 20)

                    if isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.matrixAccent)
                            .frame(width: 20, height: 20)
                    }
                }

                // Metric name
                Text(metric.name)
                    .monospacedFont(size: 14)
                    .foregroundColor(.matrixPrimaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Sparkline
                SparklineView()
                    .frame(width: 60, height: 30)

                // Percentage
                Text("\(percentChange > 0 ? "+" : "")\(percentChange)%")
                    .monospacedFont(size: 12, weight: .medium)
                    .foregroundColor(percentChange > 0 ? Color(red: 0.3, green: 0.8, blue: 0.5) : (percentChange < 0 ? Color(red: 1.0, green: 0.3, blue: 0.3) : .matrixAccent))
                    .frame(width: 50, alignment: .trailing)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
