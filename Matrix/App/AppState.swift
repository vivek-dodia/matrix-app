import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var isHealthKitAuthorized = false
    @Published var isPushServiceRunning = false
    @Published var isConfigured = false
    @Published var pushgatewayURL = ""
    @Published var lastPushTime: Date?
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadConfiguration()
    }
    
    func loadConfiguration() {
        pushgatewayURL = userDefaults.string(forKey: "pushgatewayURL") ?? ""
        isConfigured = !pushgatewayURL.isEmpty
        isPushServiceRunning = userDefaults.bool(forKey: "isPushServiceRunning")
        
        if let lastPushTimestamp = userDefaults.object(forKey: "lastPushTime") as? Date {
            lastPushTime = lastPushTimestamp
        }
    }
    
    func saveConfiguration() {
        userDefaults.set(pushgatewayURL, forKey: "pushgatewayURL")
        userDefaults.set(isConfigured, forKey: "isConfigured")
        userDefaults.set(isPushServiceRunning, forKey: "isPushServiceRunning")
        
        if let lastPushTime = lastPushTime {
            userDefaults.set(lastPushTime, forKey: "lastPushTime")
        }
        
        userDefaults.synchronize()
    }
}