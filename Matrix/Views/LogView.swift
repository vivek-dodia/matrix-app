import SwiftUI

struct LogView: View {
    @Environment(\.dismiss) var dismiss
    @State private var logs: [LogEntry] = []
    @State private var filteredLogs: [LogEntry] = []
    
    private let logger = Logger.shared
    
    var body: some View {
        ZStack {
            Color.matrixBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Single unified logs section
                        if !filteredLogs.isEmpty {
                            unifiedLogsSection
                        } else {
                            emptyState
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }
                
                // Footer
                footer
            }
        }
        .onAppear {
            loadLogs()
        }
    }
    
    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                    Text("logs")
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
    
    private var unifiedLogsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.matrixSuccess)
                    .frame(width: 12, height: 12)
                
                Text("logs")
                    .monospacedFont(size: 14)
                    .foregroundColor(.matrixPrimaryText)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(filteredLogs) { log in
                    logEntry(log)
                }
            }
        }
    }
    
    private func logEntry(_ log: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formatTime(log.timestamp))
                .monospacedFont(size: 10)
                .foregroundColor(.matrixSecondaryText)
            
            Text(log.message)
                .monospacedFont(size: 14)
                .foregroundColor(logColor(for: log.level))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func logColor(for level: LogLevel) -> Color {
        switch level {
        case .info:
            return .matrixPrimaryText
        case .warning:
            return .matrixAccent
        case .error:
            return .matrixError
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("no logs yet")
                .monospacedFont(size: 16)
                .foregroundColor(.matrixSecondaryText)
            
            Text("logs will appear here when the app starts syncing metrics")
                .monospacedFont(size: 12)
                .foregroundColor(.matrixSecondaryText.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 100)
    }
    
    private var footer: some View {
        HStack(spacing: 24) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.matrixSuccess)
                    .frame(width: 12, height: 12)
                Text("\(filteredLogs.filter { $0.level == .info }.count)")
                    .monospacedFont(size: 14)
                    .foregroundColor(.matrixPrimaryText)
            }
            
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.matrixError)
                    .frame(width: 12, height: 12)
                Text("\(filteredLogs.filter { $0.level == .error || $0.level == .warning }.count)")
                    .monospacedFont(size: 14)
                    .foregroundColor(.matrixPrimaryText)
            }
            
            Spacer()
            
            Text("last 24h")
                .monospacedFont(size: 12)
                .foregroundColor(.matrixSecondaryText)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
    
    private func loadLogs() {
        logs = logger.getLogs()
        
        // Filter logs from last 24 hours and sort by timestamp (newest first)
        let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60)
        filteredLogs = logs.filter { $0.timestamp > cutoffDate }
            .sorted { $0.timestamp > $1.timestamp }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}