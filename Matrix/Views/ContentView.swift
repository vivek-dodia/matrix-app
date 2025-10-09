import SwiftUI
import HealthKit

// Custom font modifier for SF Mono
struct MonospacedModifier: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: weight, design: .monospaced))
            .tracking(0.5) // Wide letter spacing
    }
}

extension View {
    func monospacedFont(size: CGFloat = 14, weight: Font.Weight = .regular) -> some View {
        self.modifier(MonospacedModifier(size: size, weight: weight))
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showConfiguration = false
    @State private var showLogs = false
    @State private var showMetricsOverview = false
    @State private var showBabbleChat = false
    @State private var authorizationStatus = "Not Checked"
    @State private var isLoading = false
    @State private var testResult = ""
    @State private var metricsCount = 0
    @State private var infoLogCount = 0
    @State private var errorLogCount = 0
    
    // Animation states
    @State private var rotationX: Double = 0
    @State private var rotationY: Double = 0
    @State private var velocityX: Double = 0
    @State private var velocityY: Double = 0
    @State private var lastDragValue: CGSize = .zero
    @State private var timer: Timer?
    
    private let healthKitManager = HealthKitManager.shared
    private let pushService = PrometheussPushService.shared
    private let logger = Logger.shared
    private let keychainManager = KeychainManager.shared
    
    var body: some View {
        ZStack {
            Color.matrixBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Status Section
                statusSection
                    .padding(.top, 100)
                
                Spacer()
                
                // Circular Visualization
                circularVisualization
                
                Spacer()
                
                // Bottom Section
                bottomSection
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showConfiguration) {
            ConfigurationView()
                .environmentObject(appState)
                .onDisappear {
                    // Refresh configuration status when configuration view is dismissed
                    checkConfigurationAndStartService()
                    updateMetricsCount()
                    updateLogCounts()
                }
        }
        .sheet(isPresented: $showLogs) {
            LogView()
        }
        .sheet(isPresented: $showMetricsOverview) {
            MetricsOverviewView()
        }
        .sheet(isPresented: $showBabbleChat) {
            BabbleChatView()
        }
        .onAppear {
            checkHealthKitAuthorization()
            updateMetricsCount()
            updateLogCounts()
            checkConfigurationAndStartService()
        }
        .onDisappear {
            // Clean up timer when view disappears
            timer?.invalidate()
        }
    }
    
    private var statusSection: some View {
        VStack(spacing: 8) {
            Text("connection status")
                .monospacedFont(size: 18)
                .foregroundColor(.matrixPrimaryText)
            
            if appState.isConfigured && appState.isHealthKitAuthorized {
                Text(appState.isPushServiceRunning ? "connected" : "disconnected")
                    .monospacedFont(size: 18)
                    .foregroundColor(appState.isPushServiceRunning ? .matrixSuccess : .matrixSecondaryText)
            } else {
                Text("not configured")
                    .monospacedFont(size: 18)
                    .foregroundColor(.matrixSecondaryText)
            }
            
            if appState.isPushServiceRunning {
                HStack(spacing: 4) {
                    Text("\(metricsCount)")
                        .monospacedFont(size: 14)
                        .foregroundColor(.matrixAccent)
                    Text("metrics in 24 hours")
                        .monospacedFont(size: 14)
                        .foregroundColor(.matrixSecondaryText)
                }
                .padding(.top, 4)
                
                if let lastPush = appState.lastPushTime {
                    Text("last sync: \(formatDate(lastPush))")
                        .monospacedFont(size: 10)
                        .foregroundColor(.matrixSecondaryText.opacity(0.8))
                        .padding(.top, 2)
                }
            }
        }
    }
    
    private var circularVisualization: some View {
        ZStack {
            // Outer circle border (sphere outline)
            Circle()
                .stroke(Color.matrixBorder, lineWidth: 2)
                .frame(width: 256, height: 256)
            
            // Status dots positioned on sphere
            ForEach(0..<8) { index in
                statusDot(for: index)
                    .position(sphericalDotPosition(for: index, radius: 128))
            }
            
            // Central white circle
            Circle()
                .fill(Color.matrixCentralCircle)
                .frame(width: 64, height: 64)
                .scaleEffect(centralCircleScale())
                .onTapGesture {
                    // Force collect metrics before showing
                    if appState.isHealthKitAuthorized {
                        Task {
                            do {
                                logger.log("Manually collecting metrics...", level: .info)
                                let metrics = try await healthKitManager.collectAllMetrics()
                                logger.log("Collected \(metrics.count) metrics", level: .info)

                                await MainActor.run {
                                    metricsCount = metrics.count
                                    updateMetricsCount()
                                    showMetricsOverview = true
                                }
                            } catch {
                                logger.log("Failed to collect metrics: \(error)", level: .error)
                                await MainActor.run {
                                    showMetricsOverview = true
                                }
                            }
                        }
                    } else {
                        showMetricsOverview = true
                    }
                }
        }
        .frame(width: 256, height: 256)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let deltaX = value.translation.width - lastDragValue.width
                    let deltaY = value.translation.height - lastDragValue.height
                    
                    // Update rotation based on drag
                    rotationY += deltaX * 0.5
                    rotationX -= deltaY * 0.5
                    
                    // Calculate velocity for momentum
                    velocityX = deltaY * 0.5
                    velocityY = deltaX * 0.5
                    
                    lastDragValue = value.translation
                }
                .onEnded { _ in
                    lastDragValue = .zero
                    startMomentumAnimation()
                }
        )
        .onTapGesture {
            // Gentle spin on tap
            withAnimation(.spring(response: 1.0, dampingFraction: 0.6)) {
                rotationY += 180
            }
        }
    }
    
    private func statusDot(for index: Int) -> some View {
        let isActive = appState.isPushServiceRunning && index < metricsCount % 8
        
        // Calculate 3D position
        let spherePos = calculate3DPosition(for: index)
        
        // Scale based on z-position (depth)
        let scale = 0.7 + 0.3 * ((spherePos.z + 1.0) / 2.0)
        
        // Opacity based on z-position (dots behind sphere are dimmer)
        let opacity = spherePos.z > -0.3 ? (0.4 + 0.6 * ((spherePos.z + 1.0) / 2.0)) : 0.1
        
        return Circle()
            .fill(isActive ? Color.matrixAccent : Color.clear)
            .overlay(
                Circle()
                    .stroke(isActive ? Color.matrixAccent : Color.matrixDotHollow, lineWidth: 2)
            )
            .frame(width: 12, height: 12)
            .scaleEffect(scale)
            .opacity(opacity)
            .zIndex(spherePos.z)
    }
    
    private func sphericalDotPosition(for index: Int, radius: CGFloat) -> CGPoint {
        let pos = calculate3DPosition(for: index)
        // Project 3D position to 2D
        let x = radius + pos.x * radius
        let y = radius + pos.y * radius
        return CGPoint(x: x, y: y)
    }
    
    private func calculate3DPosition(for index: Int) -> (x: Double, y: Double, z: Double) {
        // Initial angle for dot placement
        let baseAngle = (Double(index) * 45.0 - 90.0) * .pi / 180.0
        
        // Convert rotation to radians
        let rotX = rotationX * .pi / 180.0
        let rotY = rotationY * .pi / 180.0
        
        // Calculate 3D coordinates on sphere surface
        var x = cos(baseAngle)
        var y = sin(baseAngle)
        var z = 0.0
        
        // Apply Y rotation (horizontal swipe)
        let newX = x * cos(rotY) - z * sin(rotY)
        let newZ = x * sin(rotY) + z * cos(rotY)
        x = newX
        z = newZ
        
        // Apply X rotation (vertical swipe)
        let newY = y * cos(rotX) - z * sin(rotX)
        let finalZ = y * sin(rotX) + z * cos(rotX)
        y = newY
        z = finalZ
        
        return (x: x, y: y, z: z)
    }
    
    private func centralCircleScale() -> CGFloat {
        // Scale central circle based on rotation to enhance 3D effect
        let rotX = abs(rotationX).truncatingRemainder(dividingBy: 360)
        let rotY = abs(rotationY).truncatingRemainder(dividingBy: 360)
        let maxRotation = max(rotX, rotY)
        return 1.0 - (maxRotation / 360.0) * 0.1
    }
    
    private var bottomSection: some View {
        HStack {
            // Log indicators
            Button(action: { showLogs = true }) {
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.matrixSuccess)
                            .frame(width: 12, height: 12)
                        Text("\(infoLogCount)")
                            .monospacedFont(size: 14)
                            .foregroundColor(.matrixPrimaryText)
                    }
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.matrixError)
                            .frame(width: 12, height: 12)
                        Text("\(errorLogCount)")
                            .monospacedFont(size: 14)
                            .foregroundColor(.matrixPrimaryText)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()

            // Babble and Configure buttons
            HStack(spacing: 12) {
                // Babble button
                Button(action: {
                    showBabbleChat = true
                }) {
                    Text("Babble")
                        .monospacedFont(size: 14, weight: .medium)
                        .foregroundColor(.matrixPrimaryText)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.matrixAccent, lineWidth: 2)
                        )
                }
                .disabled(!appState.isHealthKitAuthorized)
                .opacity(appState.isHealthKitAuthorized ? 1.0 : 0.5)

                // Configure button
                Button(action: {
                    if !appState.isHealthKitAuthorized {
                        setupApp()
                    } else {
                        showConfiguration = true
                    }
                }) {
                    Text(appState.isHealthKitAuthorized ? "Configure" : "Authorize")
                        .monospacedFont(size: 14, weight: .medium)
                        .foregroundColor(.matrixBackground)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.matrixAccent)
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private func setupApp() {
        isLoading = true
        logger.log("Starting HealthKit authorization", level: .info)

        healthKitManager.requestAuthorization { success, error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    self.logger.log("HealthKit authorization error: \(error.localizedDescription)", level: .error)
                    self.authorizationStatus = "Error"
                    self.appState.isHealthKitAuthorized = false
                    return
                }

                if success {
                    self.logger.log("HealthKit authorization successful", level: .info)
                    self.authorizationStatus = "Authorized"
                    self.appState.isHealthKitAuthorized = true

                    // Trigger immediate metric collection
                    Task {
                        do {
                            let metrics = try await self.healthKitManager.collectAllMetrics()
                            self.logger.log("Collected \(metrics.count) metrics after authorization", level: .info)

                            await MainActor.run {
                                self.metricsCount = metrics.count
                                self.updateMetricsCount()
                            }
                        } catch {
                            self.logger.log("Failed to collect initial metrics: \(error)", level: .error)
                        }
                    }

                    if !self.appState.isConfigured {
                        self.showConfiguration = true
                    }
                } else {
                    self.logger.log("HealthKit authorization denied", level: .warning)
                    self.authorizationStatus = "Denied"
                    self.appState.isHealthKitAuthorized = false
                }
            }
        }
    }
    
    private func checkHealthKitAuthorization() {
        if HKHealthStore.isHealthDataAvailable() {
            let status = healthKitManager.authorizationStatus()
            authorizationStatus = status
            appState.isHealthKitAuthorized = (status == "Authorized")
        } else {
            authorizationStatus = "Not Available"
        }
    }
    
    private func updateMetricsCount() {
        // Get cached metrics count
        if let cached = MetricCache.shared.getCachedMetrics() {
            metricsCount = cached.count
        }
    }
    
    private func updateLogCounts() {
        let logs = logger.getLogs()
        let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60)
        let recentLogs = logs.filter { $0.timestamp > cutoffDate }
        
        infoLogCount = recentLogs.filter { $0.level == .info }.count
        errorLogCount = recentLogs.filter { $0.level == .error || $0.level == .warning }.count
    }
    
    private func checkConfigurationAndStartService() {
        // Check if we have valid configuration
        let useInfluxDB = UserDefaults.standard.bool(forKey: "useInfluxDB")
        var isConfigured = false
        
        if useInfluxDB {
            // Check InfluxDB configuration
            let influxURL = UserDefaults.standard.string(forKey: "influxDBURL") ?? ""
            let influxOrg = UserDefaults.standard.string(forKey: "influxDBOrg") ?? ""
            let influxBucket = UserDefaults.standard.string(forKey: "influxDBBucket") ?? ""
            let hasToken = keychainManager.getInfluxDBCredentials() != nil
            
            isConfigured = !influxURL.isEmpty && !influxOrg.isEmpty && !influxBucket.isEmpty && hasToken
            
            // Clear Prometheus URL when using InfluxDB to prevent confusion
            if isConfigured {
                appState.pushgatewayURL = ""
            }
        } else {
            // Check Prometheus configuration
            let pushgatewayURL = UserDefaults.standard.string(forKey: "pushgatewayURL") ?? ""
            isConfigured = !pushgatewayURL.isEmpty
            
            if isConfigured {
                appState.pushgatewayURL = pushgatewayURL
            }
        }
        
        // Update app state
        appState.isConfigured = isConfigured
        
        // Auto-start push service if configured and authorized
        if appState.isHealthKitAuthorized && appState.isConfigured && !appState.isPushServiceRunning {
            pushService.startPushing()
            appState.isPushServiceRunning = true
            appState.saveConfiguration()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "\(seconds) seconds ago"
        } else if seconds < 3600 {
            return "\(seconds / 60) minutes ago"
        } else {
            return "\(seconds / 3600) hours ago"
        }
    }
    
    private func startMomentumAnimation() {
        // Cancel any existing timer
        timer?.invalidate()
        
        // Create a timer for physics simulation
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            // Apply velocity to rotation
            rotationX -= velocityX
            rotationY += velocityY
            
            // Apply friction
            velocityX *= 0.95
            velocityY *= 0.95
            
            // Stop when velocity is negligible
            if abs(velocityX) < 0.1 && abs(velocityY) < 0.1 {
                timer?.invalidate()
                velocityX = 0
                velocityY = 0
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
}