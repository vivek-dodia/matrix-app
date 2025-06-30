import Foundation

struct CachedMetric: Codable {
    let metric: HealthMetric
    let timestamp: Date
    
    var age: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }
    
    var ageInMinutes: Int {
        Int(age / 60)
    }
}

class MetricCache {
    static let shared = MetricCache()
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "cachedHealthMetrics"
    private let maxCacheAge: TimeInterval = 3600 // 1 hour
    
    private init() {}
    
    func saveMetrics(_ metrics: [HealthMetric]) {
        let cachedMetrics = metrics.map { CachedMetric(metric: $0, timestamp: Date()) }
        
        if let encoded = try? JSONEncoder().encode(cachedMetrics) {
            userDefaults.set(encoded, forKey: cacheKey)
            Logger.shared.log("Cached \(metrics.count) metrics", level: .info)
        }
    }
    
    func getCachedMetrics() -> [CachedMetric]? {
        guard let data = userDefaults.data(forKey: cacheKey),
              let cachedMetrics = try? JSONDecoder().decode([CachedMetric].self, from: data) else {
            return nil
        }
        
        // Filter out metrics older than maxCacheAge
        let validMetrics = cachedMetrics.filter { $0.age <= maxCacheAge }
        
        if validMetrics.isEmpty {
            Logger.shared.log("All cached metrics expired", level: .info)
            return nil
        }
        
        Logger.shared.log("Retrieved \(validMetrics.count) cached metrics", level: .info)
        return validMetrics
    }
    
    func clearCache() {
        userDefaults.removeObject(forKey: cacheKey)
        Logger.shared.log("Metric cache cleared", level: .info)
    }
}