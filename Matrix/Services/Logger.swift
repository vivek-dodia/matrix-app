import Foundation

class Logger {
    static let shared = Logger()
    
    private var logs: [LogEntry] = []
    private let maxLogs = 1000
    private let dateFormatter: DateFormatter
    
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }
    
    func log(_ message: String, level: LogLevel) {
        let entry = LogEntry(
            timestamp: Date(),
            message: message,
            level: level
        )
        
        DispatchQueue.main.async {
            self.logs.append(entry)
            
            // Keep only the most recent logs
            if self.logs.count > self.maxLogs {
                self.logs.removeFirst(self.logs.count - self.maxLogs)
            }
            
            // Post notification for log viewers
            NotificationCenter.default.post(
                name: .logUpdated,
                object: nil,
                userInfo: ["entry": entry]
            )
        }
        
        // Also print to console for debugging
        print("[\(level.rawValue)] \(dateFormatter.string(from: entry.timestamp)): \(message)")
    }
    
    func getLogs(level: LogLevel? = nil) -> [LogEntry] {
        if let level = level {
            return logs.filter { $0.level == level }
        }
        return logs
    }
    
    func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
            NotificationCenter.default.post(name: .logsCleared, object: nil)
        }
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let level: LogLevel
}

enum LogLevel: String, CaseIterable {
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    
    var color: String {
        switch self {
        case .info: return "blue"
        case .warning: return "orange"
        case .error: return "red"
        }
    }
}

extension Notification.Name {
    static let logUpdated = Notification.Name("logUpdated")
    static let logsCleared = Notification.Name("logsCleared")
}