import SwiftUI

struct ConfigurationView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedDataSource: DataSource = .influxDB
    @State private var pushgatewayURL: String = ""
    @State private var useBasicAuth = false
    @State private var username = ""
    @State private var password = ""
    @State private var pushInterval = 5.0
    @State private var showDocumentation = false
    @State private var influxDBURL = ""
    @State private var influxDBToken = ""
    @State private var influxDBOrg = ""
    @State private var influxDBBucket = ""
    @State private var connectionStatus: ConnectionStatus = .notTested
    @State private var testingConnection = false
    @State private var showInfluxDBToken = false
    @State private var showPrometheusPassword = false

    private let keychainManager = KeychainManager.shared
    
    enum DataSource {
        case influxDB
        case prometheus
    }
    
    enum ConnectionStatus {
        case notTested
        case testing
        case success
        case failed
    }
    
    var body: some View {
        ZStack {
            Color.matrixBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Data Source Toggle
                        dataSourceToggle
                        
                        // Configuration Fields
                        if selectedDataSource == .influxDB {
                            influxDBConfiguration
                        } else {
                            prometheusConfiguration
                        }
                        
                        // Push Interval
                        pushIntervalSection

                        // Connection Test
                        connectionTestSection
                        
                        // Save Button
                        saveButton
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }
            }
        }
        .onAppear {
            loadConfiguration()
        }
    }
    
    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                    Text("configuration")
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
    
    private var dataSourceToggle: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("data source")
                .monospacedFont(size: 14)
                .foregroundColor(.matrixSecondaryText)
            
            HStack(spacing: 0) {
                Button(action: { selectedDataSource = .influxDB }) {
                    Text("InfluxDB")
                        .monospacedFont(size: 14, weight: .medium)
                        .foregroundColor(selectedDataSource == .influxDB ? .matrixBackground : .matrixPrimaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedDataSource == .influxDB ? Color.matrixAccent : Color.clear)
                        .overlay(
                            Rectangle()
                                .stroke(selectedDataSource == .influxDB ? Color.matrixAccent : Color.matrixSecondaryText, lineWidth: 1)
                        )
                }
                
                Button(action: { selectedDataSource = .prometheus }) {
                    Text("Prometheus")
                        .monospacedFont(size: 14, weight: .medium)
                        .foregroundColor(selectedDataSource == .prometheus ? .matrixBackground : .matrixPrimaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedDataSource == .prometheus ? Color.matrixAccent : Color.clear)
                        .overlay(
                            Rectangle()
                                .stroke(selectedDataSource == .prometheus ? Color.matrixAccent : Color.matrixSecondaryText, lineWidth: 1)
                        )
                }
            }
        }
    }
    
    private var influxDBConfiguration: some View {
        VStack(alignment: .leading, spacing: 20) {
            configField(label: "server url", value: $influxDBURL, placeholder: "https://your-influxdb.com:8086")
            
            configField(label: "api token", value: $influxDBToken, placeholder: "your influxdb api token", isSecure: true)
            
            configField(label: "organization", value: $influxDBOrg, placeholder: "your-org")
            
            configField(label: "bucket", value: $influxDBBucket, placeholder: "metrics-bucket")
        }
    }
    
    private var prometheusConfiguration: some View {
        VStack(alignment: .leading, spacing: 20) {
            configField(label: "gateway url", value: $pushgatewayURL, placeholder: "http://pushgateway:9091")
            
            configField(label: "username (optional)", value: $username, placeholder: "basic auth username")
            
            configField(label: "password (optional)", value: $password, placeholder: "basic auth password", isSecure: true)
        }
    }
    
    private func configField(label: String, value: Binding<String>, placeholder: String, isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .monospacedFont(size: 14)
                .foregroundColor(.matrixPrimaryText)
            
            HStack {
                let shouldShowPassword = isSecure && (
                    (label.contains("api token") && showInfluxDBToken) ||
                    (label.contains("password") && showPrometheusPassword)
                )
                
                if isSecure && !shouldShowPassword {
                    SecureField("", text: value)
                        .placeholder(when: value.wrappedValue.isEmpty) {
                            Text(placeholder)
                                .monospacedFont(size: 14)
                                .foregroundColor(.matrixSecondaryText.opacity(0.5))
                        }
                        .monospacedFont(size: 14)
                        .foregroundColor(.matrixPrimaryText)
                        .accentColor(.matrixAccent)
                } else {
                    TextField("", text: value)
                        .placeholder(when: value.wrappedValue.isEmpty) {
                            Text(placeholder)
                                .monospacedFont(size: 14)
                                .foregroundColor(.matrixSecondaryText.opacity(0.5))
                        }
                        .monospacedFont(size: 14)
                        .foregroundColor(.matrixPrimaryText)
                        .accentColor(.matrixAccent)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                if isSecure {
                    Button(action: {
                        if label.contains("api token") {
                            showInfluxDBToken.toggle()
                        } else if label.contains("password") {
                            showPrometheusPassword.toggle()
                        }
                    }) {
                        Image(systemName: shouldShowPassword ? "eye.slash" : "eye")
                            .font(.system(size: 16))
                            .foregroundColor(.matrixSecondaryText.opacity(0.6))
                    }
                }
            }
            
            Rectangle()
                .fill(Color.matrixSecondaryText.opacity(0.3))
                .frame(height: 1)
        }
    }
    
    private var pushIntervalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("push interval")
                .monospacedFont(size: 14)
                .foregroundColor(.matrixPrimaryText)
            
            VStack(spacing: 8) {
                Slider(value: $pushInterval, in: 1...60, step: 1)
                    .accentColor(.matrixAccent)
                
                HStack {
                    Text("1 min")
                        .monospacedFont(size: 12)
                        .foregroundColor(.matrixSecondaryText)
                    
                    Spacer()
                    
                    Text("\(Int(pushInterval)) min")
                        .monospacedFont(size: 12)
                        .foregroundColor(.matrixAccent)
                    
                    Spacer()
                    
                    Text("60 min")
                        .monospacedFont(size: 12)
                        .foregroundColor(.matrixSecondaryText)
                }
            }
        }
        .padding(.top, 12)
    }

    private var connectionTestSection: some View {
        VStack(spacing: 16) {
            Button(action: testConnection) {
                Text("test connection")
                    .monospacedFont(size: 14, weight: .medium)
                    .foregroundColor(.matrixPrimaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .overlay(
                        Rectangle()
                            .stroke(Color.matrixSecondaryText, lineWidth: 1)
                    )
            }
            .disabled(testingConnection)
            
            if connectionStatus != .notTested {
                HStack(spacing: 8) {
                    Image(systemName: connectionStatus == .success ? "checkmark" : "xmark")
                        .font(.system(size: 14))
                        .foregroundColor(connectionStatus == .success ? .matrixSuccess : .matrixError)
                    
                    Text(connectionStatus == .success ? "connection successful" : "connection failed")
                        .monospacedFont(size: 12)
                        .foregroundColor(connectionStatus == .success ? .matrixSuccess : .matrixError)
                }
            }
        }
        .padding(.top, 12)
    }
    
    private var saveButton: some View {
        Button(action: saveConfiguration) {
            Text("Save")
                .monospacedFont(size: 14, weight: .medium)
                .foregroundColor(connectionStatus == .success ? .matrixBackground : .matrixSecondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(connectionStatus == .success ? Color.matrixAccent : Color.matrixSecondaryText.opacity(0.3))
                .cornerRadius(8)
        }
        .disabled(connectionStatus != .success)
        .padding(.top, 24)
    }
    
    private func testConnection() {
        connectionStatus = .testing
        testingConnection = true
        
        // Add minimum delay to avoid flash of failure/success
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Test connection logic
            let isValid = selectedDataSource == .influxDB ?
                (!influxDBURL.isEmpty && !influxDBToken.isEmpty && !influxDBOrg.isEmpty && !influxDBBucket.isEmpty) :
                (!pushgatewayURL.isEmpty)
            
            // Add small additional delay for visual feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                connectionStatus = isValid ? .success : .failed
                testingConnection = false
            }
        }
    }
    
    private func loadConfiguration() {
        // Load existing configuration
        pushgatewayURL = appState.pushgatewayURL
        pushInterval = Double(UserDefaults.standard.integer(forKey: "pushInterval"))
        if pushInterval == 0 { pushInterval = 5 }
        
        // Load InfluxDB settings
        let useInfluxDB = UserDefaults.standard.bool(forKey: "useInfluxDB")
        selectedDataSource = useInfluxDB ? .influxDB : .prometheus
        
        influxDBURL = UserDefaults.standard.string(forKey: "influxDBURL") ?? ""
        influxDBOrg = UserDefaults.standard.string(forKey: "influxDBOrg") ?? ""
        influxDBBucket = UserDefaults.standard.string(forKey: "influxDBBucket") ?? ""
        
        // Load auth settings
        if let authData = keychainManager.getCredentials() {
            useBasicAuth = true
            username = authData.username
            password = authData.password
        }
        
        // Load InfluxDB credentials
        if let influxData = keychainManager.getInfluxDBCredentials() {
            influxDBToken = influxData
        }
    }
    
    private func saveConfiguration() {
        // Save configuration based on selected data source
        UserDefaults.standard.set(selectedDataSource == .influxDB, forKey: "useInfluxDB")
        UserDefaults.standard.set(Int(pushInterval), forKey: "pushInterval")
        
        if selectedDataSource == .influxDB {
            UserDefaults.standard.set(influxDBURL, forKey: "influxDBURL")
            UserDefaults.standard.set(influxDBOrg, forKey: "influxDBOrg")
            UserDefaults.standard.set(influxDBBucket, forKey: "influxDBBucket")
            
            if !influxDBToken.isEmpty {
                keychainManager.saveInfluxDBCredentials(token: influxDBToken)
            }
            
            // Clear Prometheus configuration when using InfluxDB
            appState.pushgatewayURL = ""
            UserDefaults.standard.removeObject(forKey: "pushgatewayURL")
        } else {
            appState.pushgatewayURL = pushgatewayURL
            UserDefaults.standard.set(pushgatewayURL, forKey: "pushgatewayURL")
            
            if !username.isEmpty && !password.isEmpty {
                keychainManager.saveCredentials(username: username, password: password)
            } else {
                keychainManager.deleteCredentials()
            }
            
            // Clear InfluxDB configuration when using Prometheus
            UserDefaults.standard.removeObject(forKey: "influxDBURL")
            UserDefaults.standard.removeObject(forKey: "influxDBOrg")
            UserDefaults.standard.removeObject(forKey: "influxDBBucket")
            keychainManager.deleteInfluxDBCredentials()
        }
        
        appState.isConfigured = true
        appState.saveConfiguration()
        
        // Stop any running service first
        if appState.isPushServiceRunning {
            PrometheussPushService.shared.stopPushing()
            appState.isPushServiceRunning = false
        }
        
        // Start push service if HealthKit is authorized
        if appState.isHealthKitAuthorized {
            PrometheussPushService.shared.startPushing()
            appState.isPushServiceRunning = true
            appState.saveConfiguration()
        }
        
        dismiss()
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}