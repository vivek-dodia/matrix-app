import SwiftUI
import HealthKit

struct MetricsOverviewView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showConfiguration = false
    @State private var metrics: [HealthMetric] = []
    @State private var improvingCount = 0
    @State private var trackedCount = 0
    @State private var lastSyncTime: Date?
    
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
            
            Button(action: { showConfiguration = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18))
                    .foregroundColor(.matrixPrimaryText)
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
            ForEach(getSelectedMetrics(), id: \.name) { metric in
                metricRow(metric)
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
                    
                    // Sparkline placeholder
                    sparkline()
                        .frame(width: 60, height: 20)
                }
            }
        }
    }
    
    private func sparkline() -> some View {
        // Simple sparkline representation
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
        Task {
            do {
                let todayMetrics = try await healthKitManager.collectAllMetrics()
                
                await MainActor.run {
                    self.metrics = todayMetrics
                    self.trackedCount = getSelectedMetrics().count
                    self.improvingCount = calculateImprovingCount()
                    self.lastSyncTime = Date()
                }
            } catch {
                print("Failed to load metrics: \(error)")
            }
        }
    }
    
    private func getSelectedMetrics() -> [HealthMetric] {
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
        case "healthkit_last_sync_seconds": return "last sync"
        default: return name.replacingOccurrences(of: "healthkit_", with: "").replacingOccurrences(of: "_", with: " ")
        }
    }
    
    private func formatMetricValue(_ metric: HealthMetric) -> String {
        switch metric.name {
        case "healthkit_steps_total":
            return String(format: "%.0f", metric.value)
        case "healthkit_heart_rate_bpm", "healthkit_resting_heart_rate_bpm":
            return "\(Int(metric.value))"
        case "healthkit_sleep_minutes_total":
            let hours = Int(metric.value / 60)
            let minutes = Int(metric.value.truncatingRemainder(dividingBy: 60))
            return "\(hours)h \(minutes)m"
        case "healthkit_active_energy_burned_calories_total", "healthkit_basal_energy_burned_calories_total":
            return String(format: "%.0f", metric.value)
        case "healthkit_distance_walking_running_meters_total":
            return String(format: "%.1f", metric.value / 1000) // Convert to km
        case "healthkit_oxygen_saturation_percent", "healthkit_body_fat_percent":
            return String(format: "%.1f%%", metric.value * 100)
        case "healthkit_body_weight_kg":
            return String(format: "%.1f kg", metric.value)
        case "healthkit_body_mass_index":
            return String(format: "%.1f", metric.value)
        case "healthkit_blood_pressure_systolic_mmhg", "healthkit_blood_pressure_diastolic_mmhg":
            return String(format: "%.0f", metric.value)
        case "healthkit_blood_glucose_mg_dl":
            return String(format: "%.0f", metric.value)
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
        case "healthkit_distance_walking_running_meters_total": return "km"
        case "healthkit_oxygen_saturation_percent", "healthkit_body_fat_percent": return "%"
        case "healthkit_body_weight_kg": return "kg"
        case "healthkit_body_mass_index": return ""
        case "healthkit_blood_pressure_systolic_mmhg", "healthkit_blood_pressure_diastolic_mmhg": return "mmHg"
        case "healthkit_blood_glucose_mg_dl": return "mg/dL"
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
    
    private func generateSparklinePoints() -> [CGPoint] {
        // Generate simple sparkline data
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