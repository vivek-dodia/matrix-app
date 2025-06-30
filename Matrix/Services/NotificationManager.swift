import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                Logger.shared.log("Notification permission granted", level: .info)
            } else if let error = error {
                Logger.shared.log("Notification permission error: \(error)", level: .error)
            }
        }
    }
    
    func sendStatusNotification(title: String, body: String, isSuccess: Bool) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = isSuccess ? .default : .defaultCritical
        
        // Create a trigger for immediate delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Logger.shared.log("Failed to send notification: \(error)", level: .error)
        }
    }
    
    func schedulePeriodicStatusNotification() {
        // Remove any existing periodic notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["periodic-status"])
        
        let content = UNMutableNotificationContent()
        content.title = "Matrix Health Data"
        content.body = "Checking push service status..."
        content.sound = .default
        
        // Schedule for every 6 hours
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 6 * 60 * 60, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "periodic-status",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.shared.log("Failed to schedule periodic notification: \(error)", level: .error)
            } else {
                Logger.shared.log("Periodic status notification scheduled", level: .info)
            }
        }
    }
}