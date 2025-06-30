import Foundation
import BackgroundTasks
import UIKit

class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    private let healthRefreshTaskIdentifier = "com.matrix.healthrefresh"
    private let healthPushTaskIdentifier = "com.matrix.healthpush"
    
    private init() {}
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: healthRefreshTaskIdentifier, using: nil) { task in
            self.handleHealthRefresh(task: task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: healthPushTaskIdentifier, using: nil) { task in
            self.handleHealthPush(task: task as! BGProcessingTask)
        }
        
        scheduleBackgroundRefresh()
        scheduleBackgroundProcessing()
    }
    
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: healthRefreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60) // 5 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            Logger.shared.log("Background refresh scheduled", level: .info)
        } catch {
            Logger.shared.log("Failed to schedule background refresh: \(error)", level: .error)
        }
    }
    
    func scheduleBackgroundProcessing() {
        let request = BGProcessingTaskRequest(identifier: healthPushTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            Logger.shared.log("Background processing scheduled", level: .info)
        } catch {
            Logger.shared.log("Failed to schedule background processing: \(error)", level: .error)
        }
    }
    
    private func handleHealthRefresh(task: BGAppRefreshTask) {
        scheduleBackgroundRefresh() // Schedule next refresh
        
        let pushService = PrometheussPushService.shared
        
        Task {
            do {
                try await pushService.pushMetricsOnce()
                
                // Send success notification
                await NotificationManager.shared.sendStatusNotification(
                    title: "Matrix Health Data",
                    body: "Successfully pushed metrics",
                    isSuccess: true
                )
                
                task.setTaskCompleted(success: true)
            } catch {
                Logger.shared.log("Background refresh failed: \(error)", level: .error)
                
                // Send failure notification
                await NotificationManager.shared.sendStatusNotification(
                    title: "Matrix Health Data",
                    body: "Push failed: \(error.localizedDescription)",
                    isSuccess: false
                )
                
                task.setTaskCompleted(success: false)
            }
        }
        
        // Set expiration handler
        task.expirationHandler = {
            Logger.shared.log("Background refresh task expired", level: .warning)
        }
    }
    
    private func handleHealthPush(task: BGProcessingTask) {
        scheduleBackgroundProcessing() // Schedule next processing
        
        let pushService = PrometheussPushService.shared
        
        Task {
            do {
                try await pushService.pushMetricsOnce()
                
                task.setTaskCompleted(success: true)
            } catch {
                Logger.shared.log("Background processing failed: \(error)", level: .error)
                task.setTaskCompleted(success: false)
            }
        }
        
        // Set expiration handler
        task.expirationHandler = {
            Logger.shared.log("Background processing task expired", level: .warning)
        }
    }
}