import SwiftUI

struct MetricsConfigurationView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedMetrics: Set<String> = []
    
    private let availableMetrics = [
        ("healthkit_steps_total", "steps"),
        ("healthkit_heart_rate_bpm", "heart rate"),
        ("healthkit_resting_heart_rate_bpm", "resting hr"),
        ("healthkit_sleep_minutes_total", "sleep"),
        ("healthkit_active_energy_burned_calories_total", "active energy"),
        ("healthkit_distance_walking_running_meters_total", "distance"),
        ("healthkit_basal_energy_burned_calories_total", "basal energy"),
        ("healthkit_oxygen_saturation_percent", "oxygen saturation"),
        ("healthkit_body_weight_kg", "weight"),
        ("healthkit_body_mass_index", "BMI"),
        ("healthkit_body_fat_percent", "body fat %"),
        ("healthkit_blood_pressure_systolic_mmhg", "blood pressure sys"),
        ("healthkit_blood_pressure_diastolic_mmhg", "blood pressure dia"),
        ("healthkit_blood_glucose_mg_dl", "blood glucose"),
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
                    .padding(.bottom, 32)
                
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
                    
                    HStack {
                        Spacer()
                            .frame(width: 28) // Align with text after checkbox
                        
                        Spacer()
                        
                        // Sparkline
                        sparkline()
                            .frame(width: 60, height: 20)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func sparkline() -> some View {
        Path { path in
            let points = generateSparklinePoints()
            guard let first = points.first else { return }
            
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
        .stroke(Color.matrixSecondaryText, lineWidth: 1.5)
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
    
    private func generateSparklinePoints() -> [CGPoint] {
        let width: CGFloat = 60
        let height: CGFloat = 20
        var points: [CGPoint] = []
        
        for i in 0..<8 {
            let x = CGFloat(i) * (width / 7)
            let y = height * CGFloat.random(in: 0.3...0.8)
            points.append(CGPoint(x: x, y: y))
        }
        return points
    }
}