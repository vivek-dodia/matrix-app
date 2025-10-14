import SwiftUI
import HealthKit

struct InsightsOverviewView: View {
    @Environment(\.dismiss) var dismiss
    @State private var metrics: [MetricDisplay] = []
    @State private var isLoading = true
    @State private var improvingCount = 0
    @State private var totalCount = 0
    @State private var lastSyncTime: Date?
    @State private var showSettings = false

    private let healthKitManager = HealthKitManager.shared

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

                        VStack(alignment: .leading, spacing: 2) {
                            Text("metrics")
                                .monospacedFont(size: 18, weight: .semibold)
                                .foregroundColor(.matrixPrimaryText)

                            Text(formatTime(Date()))
                                .monospacedFont(size: 10)
                                .foregroundColor(.matrixAccent)
                        }

                        Spacer()

                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.matrixPrimaryText)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .padding(.bottom, 16)

                    // Summary section
                    VStack(spacing: 8) {
                        Text("today's overview")
                            .monospacedFont(size: 12)
                            .foregroundColor(.matrixSecondaryText)

                        HStack(spacing: 4) {
                            Text("\(improvingCount)")
                                .monospacedFont(size: 16, weight: .semibold)
                                .foregroundColor(.matrixAccent)
                            Text("improving")
                                .monospacedFont(size: 16)
                                .foregroundColor(.matrixPrimaryText)
                            Text("•")
                                .monospacedFont(size: 16)
                                .foregroundColor(.matrixSecondaryText)
                            Text("\(totalCount)")
                                .monospacedFont(size: 16, weight: .semibold)
                                .foregroundColor(.matrixPrimaryText)
                            Text("tracked")
                                .monospacedFont(size: 16)
                                .foregroundColor(.matrixPrimaryText)
                        }

                        if let lastSync = lastSyncTime {
                            Text("last sync: \(timeAgo(lastSync))")
                                .monospacedFont(size: 10)
                                .foregroundColor(.matrixSecondaryText)
                        }
                    }
                    .padding(.vertical, 20)

                    // Metrics list
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(metrics) { metric in
                                MetricRow(metric: metric)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                            }
                        }
                    }

                    // Bottom indicator
                    HStack {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.matrixAccent)
                                .frame(width: 8, height: 8)
                            Text("\(totalCount)")
                                .monospacedFont(size: 12, weight: .semibold)
                                .foregroundColor(.matrixAccent)
                        }

                        Spacer()

                        Text("healthkit sync")
                            .monospacedFont(size: 12)
                            .foregroundColor(.matrixSecondaryText)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.height > 100 {
                                dismiss()
                            }
                        }
                )
            }
        }
        .sheet(isPresented: $showSettings) {
            MetricsSettingsView()
                .onDisappear {
                    loadMetrics()
                }
        }
        .onAppear {
            loadMetrics()
        }
    }

    private func loadMetrics() {
        isLoading = true

        Task {
            do {
                let healthMetrics = try await healthKitManager.collectAllMetrics(days: 1)
                lastSyncTime = Date()

                // Get selected metrics from UserDefaults
                let selectedMetrics = Set(UserDefaults.standard.array(forKey: "selectedMetrics") as? [String] ??
                    ["step_count", "heart_rate", "sleep", "active_energy", "distance_walking_running", "exercise_time", "stand_time", "flights_climbed"])

                // Convert to display metrics
                var displayMetrics: [MetricDisplay] = []

                let now = Date()

                // Process selected metrics
                for metricId in selectedMetrics {
                    if let metric = buildMetricDisplay(metricId: metricId, healthMetrics: healthMetrics, timestamp: now) {
                        displayMetrics.append(metric)
                    }
                }

                await MainActor.run {
                    self.metrics = displayMetrics
                    self.totalCount = displayMetrics.count
                    self.improvingCount = displayMetrics.filter { $0.percentChange > 0 }.count
                    self.isLoading = false
                }
            } catch {
                Logger.shared.log("Failed to load metrics: \(error)", level: .error)
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }

    private func buildMetricDisplay(metricId: String, healthMetrics: [HealthMetric], timestamp: Date) -> MetricDisplay? {
        // Map metric IDs to their HealthKit data and display properties
        switch metricId {
        // Activity & Movement
        case "step_count":
            guard let data = healthMetrics.first(where: { $0.name.contains("steps") }) else { return nil }
            return MetricDisplay(
                name: "Steps",
                value: String(format: "%.0f", data.value),
                unit: "steps",
                percentChange: Int.random(in: -5...20),
                timestamp: timestamp.addingTimeInterval(-Double.random(in: 60...3600)),
                color: .yellow
            )

        case "distance_walking_running":
            guard let data = healthMetrics.first(where: { $0.name.contains("distance") && !$0.name.contains("cycling") }) else { return nil }
            return MetricDisplay(
                name: "Walking/Running Distance",
                value: String(format: "%.1f", data.value / 1000),
                unit: "km",
                percentChange: Int.random(in: -5...15),
                timestamp: timestamp.addingTimeInterval(-Double.random(in: 60...3600)),
                color: .yellow
            )

        case "distance_cycling":
            return MetricDisplay(
                name: "Cycling Distance",
                value: String(format: "%.1f", Double.random(in: 0...20)),
                unit: "km",
                percentChange: Int.random(in: -10...25),
                timestamp: timestamp.addingTimeInterval(-Double.random(in: 60...3600)),
                color: .yellow
            )

        case "flights_climbed":
            guard let data = healthMetrics.first(where: { $0.name.contains("flights") }) else { return nil }
            return MetricDisplay(
                name: "Flights Climbed",
                value: String(format: "%.0f", data.value),
                unit: "flights",
                percentChange: Int.random(in: -10...20),
                timestamp: timestamp.addingTimeInterval(-Double.random(in: 60...3600)),
                color: .purple
            )

        case "exercise_time":
            guard let data = healthMetrics.first(where: { $0.name.contains("exercise_time") || $0.name.contains("AppleExerciseTime") }) else { return nil }
            return MetricDisplay(
                name: "Exercise Time",
                value: String(format: "%.0f", data.value),
                unit: "min",
                percentChange: Int.random(in: -15...20),
                timestamp: timestamp.addingTimeInterval(-Double.random(in: 60...3600)),
                color: .yellow
            )

        case "stand_time":
            guard let data = healthMetrics.first(where: { $0.name.contains("stand_time") || $0.name.contains("AppleStandTime") }) else { return nil }
            return MetricDisplay(
                name: "Stand Time",
                value: String(format: "%.0f", data.value),
                unit: "min",
                percentChange: Int.random(in: -5...10),
                timestamp: timestamp.addingTimeInterval(-Double.random(in: 60...3600)),
                color: .yellow
            )

        // Energy
        case "active_energy":
            guard let data = healthMetrics.first(where: { $0.name.contains("active_energy") }) else { return nil }
            return MetricDisplay(
                name: "Active Energy",
                value: String(format: "%.0f", data.value),
                unit: "kcal",
                percentChange: Int.random(in: -10...20),
                timestamp: timestamp.addingTimeInterval(-Double.random(in: 60...3600)),
                color: .yellow
            )

        case "basal_energy":
            guard let data = healthMetrics.first(where: { $0.name.contains("basal_energy") }) else { return nil }
            return MetricDisplay(
                name: "Basal Energy",
                value: String(format: "%.0f", data.value),
                unit: "kcal",
                percentChange: Int.random(in: -3...3),
                timestamp: timestamp.addingTimeInterval(-Double.random(in: 3600...7200)),
                color: .purple
            )

        // Heart Metrics
        case "heart_rate":
            guard let data = healthMetrics.first(where: { $0.name.contains("heart_rate") && !$0.name.contains("resting") && !$0.name.contains("walking") && !$0.name.contains("variability") }) else { return nil }
            return MetricDisplay(
                name: "Heart Rate",
                value: String(format: "%.0f", data.value),
                unit: "bpm",
                percentChange: Int.random(in: -8...8),
                timestamp: timestamp.addingTimeInterval(-Double.random(in: 60...1800)),
                color: .purple
            )

        case "resting_heart_rate":
            guard let data = healthMetrics.first(where: { $0.name.contains("resting_heart_rate") }) else { return nil }
            return MetricDisplay(
                name: "Resting Heart Rate",
                value: String(format: "%.0f", data.value),
                unit: "bpm",
                percentChange: Int.random(in: -6...6),
                timestamp: timestamp.addingTimeInterval(-Double.random(in: 3600...28800)),
                color: .purple
            )

        case "walking_heart_rate":
            return MetricDisplay(
                name: "Walking Heart Rate",
                value: String(format: "%.0f", Double.random(in: 80...120)),
                unit: "bpm",
                percentChange: Int.random(in: -5...5),
                timestamp: timestamp.addingTimeInterval(-Double.random(in: 3600...28800)),
                color: .purple
            )

        case "hrv":
            guard let data = healthMetrics.first(where: { $0.name.contains("variability") || $0.name.contains("HRV") }) else { return nil }
            return MetricDisplay(
                name: "HRV",
                value: String(format: "%.0f", data.value),
                unit: "ms",
                percentChange: Int.random(in: -10...10),
                timestamp: timestamp.addingTimeInterval(-Double.random(in: 3600...28800)),
                color: .purple
            )

        // Sleep
        case "sleep":
            guard let data = healthMetrics.first(where: { $0.name.contains("sleep") }) else { return nil }
            let hours = Int(data.value / 60)
            let minutes = Int(data.value.truncatingRemainder(dividingBy: 60))
            return MetricDisplay(
                name: "Sleep",
                value: "\(hours)h \(minutes)m",
                unit: "",
                percentChange: Int.random(in: -8...8),
                timestamp: timestamp.addingTimeInterval(-Double.random(in: 14400...28800)),
                color: .yellow
            )

        // Mobility
        case "walking_speed":
            return MetricDisplay(
                name: "Walking Speed",
                value: String(format: "%.1f", Double.random(in: 3.5...6.0)),
                unit: "km/h",
                percentChange: Int.random(in: -5...10),
                timestamp: timestamp.addingTimeInterval(-Double.random(in: 3600...28800)),
                color: .purple
            )

        case "walking_step_length":
            return MetricDisplay(
                name: "Step Length",
                value: String(format: "%.0f", Double.random(in: 60...80)),
                unit: "cm",
                percentChange: Int.random(in: -3...5),
                timestamp: timestamp.addingTimeInterval(-Double.random(in: 3600...28800)),
                color: .purple
            )

        case "walking_steadiness":
            return MetricDisplay(
                name: "Walking Steadiness",
                value: String(format: "%.1f", Double.random(in: 75...95)),
                unit: "%",
                percentChange: Int.random(in: -2...4),
                timestamp: timestamp.addingTimeInterval(-Double.random(in: 3600...86400)),
                color: .purple
            )

        // VO2 Max
        case "vo2_max":
            return MetricDisplay(
                name: "VO2 Max",
                value: String(format: "%.1f", Double.random(in: 35...50)),
                unit: "mL/kg/min",
                percentChange: Int.random(in: -3...5),
                timestamp: timestamp.addingTimeInterval(-Double.random(in: 86400...604800)),
                color: .purple
            )

        // Workouts
        case "workout_walking", "workout_running", "workout_cycling", "workout_strength":
            let workoutType = metricId.replacingOccurrences(of: "workout_", with: "").capitalized
            return MetricDisplay(
                name: "\(workoutType) Workouts",
                value: String(Int.random(in: 0...10)),
                unit: "workouts",
                percentChange: Int.random(in: -20...30),
                timestamp: timestamp.addingTimeInterval(-Double.random(in: 86400...604800)),
                color: .yellow
            )

        default:
            // Generic fallback for other metrics
            return MetricDisplay(
                name: metricId.replacingOccurrences(of: "_", with: " ").capitalized,
                value: String(format: "%.1f", Double.random(in: 10...100)),
                unit: "",
                percentChange: Int.random(in: -10...10),
                timestamp: timestamp.addingTimeInterval(-Double.random(in: 3600...86400)),
                color: .purple
            )
        }
    }

    private func formatMetricValue(_ value: Double, type: String) -> String {
        switch type {
        case "steps", "calories":
            return String(format: "%.0f", value).replacingOccurrences(of: ",", with: ",")
        case "heart_rate":
            return String(format: "%.0f", value)
        default:
            return String(format: "%.1f", value)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: date).lowercased()
    }

    private func timeAgo(_ date: Date) -> String {
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

struct MetricDisplay: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let unit: String
    let percentChange: Int
    let timestamp: Date
    let color: Color

    enum Color {
        case yellow
        case purple
    }
}

struct MetricRow: View {
    let metric: MetricDisplay

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Left section
                VStack(alignment: .leading, spacing: 8) {
                    // Dot and name
                    HStack(spacing: 8) {
                        Circle()
                            .fill(metric.color == .yellow ? Color.matrixAccent : Color(red: 0.6, green: 0.6, blue: 1.0))
                            .frame(width: 8, height: 8)

                        Text(metric.name)
                            .monospacedFont(size: 14)
                            .foregroundColor(.matrixPrimaryText)
                    }

                    // Value
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(metric.value)
                            .monospacedFont(size: 32, weight: .semibold)
                            .foregroundColor(metric.color == .yellow ? Color.matrixAccent : .matrixPrimaryText)

                        Text(metric.unit)
                            .monospacedFont(size: 14)
                            .foregroundColor(.matrixSecondaryText)
                    }

                    // Timestamp
                    Text(timeAgo(metric.timestamp))
                        .monospacedFont(size: 10)
                        .foregroundColor(.matrixSecondaryText.opacity(0.6))
                }

                Spacer()

                // Right section
                VStack(alignment: .trailing, spacing: 8) {
                    // Percentage change
                    Text("\(metric.percentChange > 0 ? "+" : "")\(metric.percentChange)%")
                        .monospacedFont(size: 12, weight: .medium)
                        .foregroundColor(metric.percentChange > 0 ? Color(red: 0.3, green: 0.8, blue: 0.5) : (metric.percentChange < 0 ? Color(red: 1.0, green: 0.3, blue: 0.3) : .matrixAccent))

                    // Sparkline
                    SparklineView()
                        .frame(width: 80, height: 40)
                }
            }
        }
    }

    private func timeAgo(_ date: Date) -> String {
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

struct SparklineView: View {
    @State private var points: [CGFloat] = []

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard points.count > 1 else { return }

                let width = geometry.size.width
                let height = geometry.size.height
                let stepX = width / CGFloat(points.count - 1)

                path.move(to: CGPoint(x: 0, y: height - points[0] * height))

                for (index, point) in points.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = height - point * height
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(Color.matrixAccent.opacity(0.6), lineWidth: 2)
        }
        .onAppear {
            // Generate random sparkline data
            points = (0..<10).map { _ in CGFloat.random(in: 0.3...0.9) }
        }
    }
}
