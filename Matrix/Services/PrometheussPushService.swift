import Foundation
import UIKit

class PrometheussPushService {
    static let shared = PrometheussPushService()
    
    private let healthKitManager = HealthKitManager.shared
    private let keychainManager = KeychainManager.shared
    private let logger = Logger.shared
    
    private var pushTimer: Timer?
    private let jobName = "my_health_data"
    
    private init() {}
    
    func startPushing() {
        stopPushing() // Stop any existing timer
        
        let interval = TimeInterval(UserDefaults.standard.integer(forKey: "pushInterval") * 60)
        let actualInterval = interval > 0 ? interval : 300 // Default 5 minutes
        
        // Push immediately
        Task {
            do {
                try await pushMetricsOnce()
            } catch {
                logger.log("Failed to push metrics on start: \(error)", level: .error)
            }
        }
        
        // Schedule regular pushes
        pushTimer = Timer.scheduledTimer(withTimeInterval: actualInterval, repeats: true) { _ in
            Task {
                do {
                    try await self.pushMetricsOnce()
                } catch {
                    self.logger.log("Failed to push metrics: \(error)", level: .error)
                }
            }
        }
        
        logger.log("Push service started with interval: \(actualInterval/60) minutes", level: .info)
    }
    
    func stopPushing() {
        pushTimer?.invalidate()
        pushTimer = nil
        logger.log("Push service stopped", level: .info)
    }
    
    func pushMetricsOnce() async throws {
        // Check which endpoint to use
        let useInfluxDB = UserDefaults.standard.bool(forKey: "useInfluxDB")
        
        let targetURL: String
        if useInfluxDB {
            guard let influxURL = getInfluxDBURL() else {
                throw PushError.invalidConfiguration("InfluxDB URL not configured")
            }
            // Validate InfluxDB configuration completely
            guard let _ = getInfluxDBOrg(),
                  let _ = getInfluxDBBucket(),
                  let _ = keychainManager.getInfluxDBCredentials() else {
                throw PushError.invalidConfiguration("InfluxDB configuration incomplete")
            }
            targetURL = influxURL
        } else {
            guard let pushgatewayURL = getPushgatewayURL() else {
                throw PushError.invalidConfiguration("Pushgateway URL not configured")
            }
            targetURL = pushgatewayURL
        }
        
        // Collect metrics from HealthKit
        let metrics = try await healthKitManager.collectAllMetrics()
        
        if metrics.isEmpty {
            logger.log("No metrics to push", level: .warning)
            return
        }
        
        // Push to appropriate endpoint with retry logic
        if useInfluxDB {
            let influxData = convertToInfluxLineProtocol(metrics: metrics)
            try await pushToInfluxDBWithRetry(url: targetURL, data: influxData)
        } else {
            let formattedMetrics = PrometheusFormatter.format(metrics: metrics)
            try await pushToGatewayWithRetry(url: targetURL, metrics: formattedMetrics)
        }
        
        // Update last push time
        DispatchQueue.main.async {
            UserDefaults.standard.set(Date(), forKey: "lastPushTime")
        }
        
        let destination = useInfluxDB ? "InfluxDB Cloud" : "local Pushgateway"
        logger.log("Successfully pushed \(metrics.count) metrics to \(destination)", level: .info)
    }
    
    private func pushToGatewayWithRetry(url: String, metrics: String, maxRetries: Int = 3) async throws {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                try await pushToGateway(url: url, metrics: metrics)
                return // Success, exit retry loop
            } catch {
                lastError = error
                logger.log("Push attempt \(attempt) failed: \(error)", level: .warning)
                
                if attempt < maxRetries {
                    // Exponential backoff: 2^attempt seconds
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // All retries failed, throw the last error
        throw lastError ?? PushError.invalidResponse
    }
    
    private func pushToGateway(url: String, metrics: String) async throws {
        let instanceName = UIDevice.current.name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")
        
        let fullURL = "\(url)/metrics/job/\(jobName)/instance/\(instanceName)"
        
        guard let url = URL(string: fullURL) else {
            throw PushError.invalidURL(fullURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain; version=0.0.4", forHTTPHeaderField: "Content-Type")
        request.httpBody = metrics.data(using: .utf8)
        
        // Add basic auth if configured
        if let credentials = keychainManager.getCredentials() {
            let authString = "\(credentials.username):\(credentials.password)"
            if let authData = authString.data(using: .utf8) {
                let base64Auth = authData.base64EncodedString()
                request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
            }
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PushError.invalidResponse
        }
        
        if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PushError.httpError(statusCode: httpResponse.statusCode, body: errorBody)
        }
    }
    
    private func getPushgatewayURL() -> String? {
        let url = UserDefaults.standard.string(forKey: "pushgatewayURL")
        return url?.isEmpty == false ? url : nil
    }
    
    private func getInfluxDBURL() -> String? {
        let url = UserDefaults.standard.string(forKey: "influxDBURL")
        return url?.isEmpty == false ? url : nil
    }
    
    private func getInfluxDBOrg() -> String? {
        let org = UserDefaults.standard.string(forKey: "influxDBOrg")
        return org?.isEmpty == false ? org : nil
    }
    
    private func getInfluxDBBucket() -> String? {
        let bucket = UserDefaults.standard.string(forKey: "influxDBBucket")
        return bucket?.isEmpty == false ? bucket : nil
    }
    
    private func pushToInfluxDBWithRetry(url: String, data: String, maxRetries: Int = 3) async throws {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                try await pushToInfluxDB(url: url, data: data)
                return // Success, exit retry loop
            } catch {
                lastError = error
                logger.log("InfluxDB push attempt \(attempt) failed: \(error)", level: .warning)
                
                if attempt < maxRetries {
                    // Exponential backoff: 2^attempt seconds
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // All retries failed, throw the last error
        throw lastError ?? PushError.invalidResponse
    }
    
    private func pushToInfluxDB(url: String, data: String) async throws {
        // Get InfluxDB configuration
        let org = UserDefaults.standard.string(forKey: "influxDBOrg") ?? ""
        let bucket = UserDefaults.standard.string(forKey: "influxDBBucket") ?? ""
        
        // Build InfluxDB write API URL
        let writeURL = "\(url)/api/v2/write?org=\(org)&bucket=\(bucket)&precision=ms"
        
        guard let requestURL = URL(string: writeURL) else {
            throw PushError.invalidURL(writeURL)
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        request.httpBody = data.data(using: .utf8)
        
        // Add InfluxDB authentication
        if let token = keychainManager.getInfluxDBCredentials() {
            request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        } else {
            throw PushError.invalidConfiguration("InfluxDB token not configured")
        }
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PushError.invalidResponse
        }
        
        if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            let errorBody = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw PushError.httpError(statusCode: httpResponse.statusCode, body: errorBody)
        }
    }
    
    private func convertToInfluxLineProtocol(metrics: [HealthMetric]) -> String {
        var lines: [String] = []
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000) // milliseconds
        
        for metric in metrics {
            // Convert Prometheus format to InfluxDB line protocol
            // Format: measurement,tag1=value1,tag2=value2 field1=value1,field2=value2 timestamp
            
            let measurementName = metric.name.replacingOccurrences(of: ".", with: "_")
            
            // Add device tags
            var tags = [
                "device=\(UIDevice.current.name.replacingOccurrences(of: " ", with: "_"))",
                "job=my_health_data"
            ]
            
            // Add metric-specific tags based on name
            if metric.name.contains("steps") {
                tags.append("metric_type=steps")
            } else if metric.name.contains("heart_rate") {
                tags.append("metric_type=heart_rate")
            } else if metric.name.contains("active_energy") {
                tags.append("metric_type=active_energy")
            } else if metric.name.contains("distance_walking") {
                tags.append("metric_type=distance_walking")
            } else if metric.name.contains("flights_climbed") {
                tags.append("metric_type=flights_climbed")
            } else if metric.name.contains("body_mass") {
                tags.append("metric_type=body_mass")
            } else if metric.name.contains("sleep") {
                tags.append("metric_type=sleep_analysis")
            } else {
                tags.append("metric_type=\(metric.type == .gauge ? "gauge" : "counter")")
            }
            
            let tagString = tags.joined(separator: ",")
            let fieldString = "value=\(metric.value)"
            
            let line = "\(measurementName),\(tagString) \(fieldString) \(timestamp)"
            lines.append(line)
        }
        
        return lines.joined(separator: "\n")
    }
    
    
}

enum PushError: LocalizedError {
    case invalidConfiguration(String)
    case invalidURL(String)
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message):
            return "Configuration error: \(message)"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, let body):
            return "HTTP error \(statusCode): \(body)"
        }
    }
}