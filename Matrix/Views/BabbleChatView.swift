import SwiftUI

struct BabbleChatView: View {
    @Environment(\.dismiss) var dismiss
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var showingSettings = false

    private let claudeService = ClaudeService.shared
    private let healthKitManager = HealthKitManager.shared

    var body: some View {
        ZStack {
            // Babble blue background
            Color(red: 0.0, green: 0.0, blue: 0.4)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            if messages.isEmpty {
                                welcomeMessage
                            }

                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            if isLoading {
                                loadingIndicator
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                    .onChange(of: messages.count) { _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Quick action suggestions
                if !messages.isEmpty {
                    quickActions
                }

                // Input bar
                inputBar
            }
        }
        .sheet(isPresented: $showingSettings) {
            BabbleSettingsView()
        }
        .onAppear {
            if messages.isEmpty {
                addWelcomeMessage()
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("babble")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)

                Text("health insights assistant")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Button(action: { showingSettings = true }) {
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 12, height: 12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 16)
    }

    private var welcomeMessage: some View {
        VStack(alignment: .leading, spacing: 12) {
            MessageBubble(message: ChatMessage(
                role: "assistant",
                content: "hey there! i'm babble, your health metrics assistant. ask me anything about your health data or how different metrics relate to each other."
            ))

            Text(formatTime(Date()))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .padding(.leading, 4)
        }
    }

    private var loadingIndicator: some View {
        HStack {
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: isLoading
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.15))
            .cornerRadius(16)

            Spacer()
        }
    }

    private var quickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                QuickActionButton(title: "correlate metrics") {
                    sendQuickAction("correlate metrics")
                }

                QuickActionButton(title: "improve sleep") {
                    sendQuickAction("how can i improve my sleep?")
                }

                QuickActionButton(title: "exercise patterns") {
                    sendQuickAction("analyze my exercise patterns")
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.2))

            HStack(spacing: 12) {
                TextField("ask about your metrics...", text: $inputText)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(20)

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(inputText.isEmpty ? Color.white.opacity(0.3) : Color.yellow)
                }
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(red: 0.0, green: 0.0, blue: 0.4))
        }
    }

    private func addWelcomeMessage() {
        messages.append(ChatMessage(
            role: "assistant",
            content: "hey there! i'm babble, your health metrics assistant. ask me anything about your health data or how different metrics relate to each other."
        ))
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        let userMessage = inputText
        inputText = ""

        // Add user message
        messages.append(ChatMessage(role: "user", content: userMessage))

        // Get AI response
        Task {
            isLoading = true

            do {
                Logger.shared.log("Babble: Getting metrics context...", level: .info)

                // Get health metrics context
                let metricsContext = await buildMetricsContext()

                Logger.shared.log("Babble: Got \(metricsContext.count) chars of context", level: .info)

                // Send to Claude
                let response = try await claudeService.chat(
                    message: userMessage,
                    metrics: metricsContext,
                    conversationHistory: messages.dropLast() // Exclude the just-added user message
                )

                await MainActor.run {
                    messages.append(ChatMessage(role: "assistant", content: response))
                    isLoading = false
                }
            } catch {
                Logger.shared.log("Babble error: \(error)", level: .error)
                await MainActor.run {
                    messages.append(ChatMessage(
                        role: "assistant",
                        content: "sorry, i encountered an error: \(error.localizedDescription)"
                    ))
                    isLoading = false
                }
            }
        }
    }

    private func sendQuickAction(_ message: String) {
        inputText = message
        sendMessage()
    }

    private func buildMetricsContext() async -> String {
        do {
            Logger.shared.log("Building metrics context...", level: .info)

            // Get daily time-series data for the past 30 days
            let dailyMetrics = try await healthKitManager.collectDailyMetrics(days: 30)

            Logger.shared.log("Got daily metrics: \(dailyMetrics.prefix(100))...", level: .info)

            if dailyMetrics.isEmpty {
                Logger.shared.log("Daily metrics is empty", level: .warning)
                return "No recent metrics available."
            }

            return "Daily health metrics (last 30 days):\n\n\(dailyMetrics)\n\nNote: Each day shows steps, active calories burned, distance in km, heart rate, resting heart rate, and sleep hours when available."

        } catch {
            Logger.shared.log("Failed to build metrics context: \(error)", level: .error)
            return "Error loading metrics: \(error.localizedDescription)"
        }
    }

    private func formatMetricName(_ name: String) -> String {
        return name
            .replacingOccurrences(of: "healthkit_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func formatValue(_ metric: HealthMetric) -> String {
        let value = metric.value

        if metric.name.contains("steps") || metric.name.contains("calories") {
            return String(format: "%.0f", value)
        } else if metric.name.contains("heart_rate") {
            return String(format: "%.0f bpm", value)
        } else if metric.name.contains("sleep") {
            let hours = Int(value / 60)
            let minutes = Int(value.truncatingRemainder(dividingBy: 60))
            return "\(hours)h \(minutes)m"
        } else if metric.name.contains("distance") {
            return String(format: "%.1f km", value / 1000)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: date).lowercased()
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(message.isUser ? Color.yellow.opacity(0.3) : Color.white.opacity(0.15))
                    .cornerRadius(16)

                Text(formatTime(message.timestamp))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 4)
            }

            if !message.isUser {
                Spacer()
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: date).lowercased()
    }
}

struct QuickActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.15))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

struct BabbleSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var backendURL = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.0, green: 0.0, blue: 0.4)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("babble settings")
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("backend url")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))

                        TextField("https://your-vercel-url.vercel.app/api/chat", text: $backendURL)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }

                    Button(action: saveSettings) {
                        Text("save")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(red: 0.0, green: 0.0, blue: 0.4))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.yellow)
                            .cornerRadius(8)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.yellow)
                }
            }
        }
        .onAppear {
            backendURL = UserDefaults.standard.string(forKey: "backendURL") ?? ""
        }
    }

    private func saveSettings() {
        ClaudeService.shared.setBackendURL(backendURL)
        dismiss()
    }
}
