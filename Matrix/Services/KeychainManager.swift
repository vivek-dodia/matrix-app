import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private let serviceName = "com.matrix.health"
    private let accountName = "pushgateway"
    private let influxDBAccountName = "influxdb-cloud"
    
    private init() {}
    
    func saveCredentials(username: String, password: String) {
        let credentials = "\(username):\(password)"
        guard let data = credentials.data(using: .utf8) else { return }
        
        // Delete any existing item
        deleteCredentials()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            Logger.shared.log("Failed to save credentials to keychain: \(status)", level: .error)
        } else {
            Logger.shared.log("Credentials saved to keychain", level: .info)
        }
    }
    
    func getCredentials() -> (username: String, password: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess,
           let data = dataTypeRef as? Data,
           let credentials = String(data: data, encoding: .utf8) {
            let components = credentials.split(separator: ":", maxSplits: 1)
            if components.count == 2 {
                return (username: String(components[0]), password: String(components[1]))
            }
        }
        
        return nil
    }
    
    func deleteCredentials() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - InfluxDB Cloud Credentials
    
    func saveInfluxDBCredentials(token: String) {
        guard let data = token.data(using: .utf8) else { return }
        
        // Delete any existing item
        deleteInfluxDBCredentials()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: influxDBAccountName,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            Logger.shared.log("Failed to save InfluxDB credentials to keychain: \(status)", level: .error)
        } else {
            Logger.shared.log("InfluxDB credentials saved to keychain", level: .info)
        }
    }
    
    func getInfluxDBCredentials() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: influxDBAccountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess,
           let data = dataTypeRef as? Data,
           let token = String(data: data, encoding: .utf8) {
            return token
        }
        
        return nil
    }
    
    func deleteInfluxDBCredentials() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: influxDBAccountName
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}