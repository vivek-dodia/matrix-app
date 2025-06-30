import SwiftUI

@main
struct MatrixApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    // Configure app lifecycle
                    configureApp()
                }
        }
    }
    
    private func configureApp() {
        // Register for background tasks
        BackgroundTaskManager.shared.registerBackgroundTasks()
        
        // Configure notification settings
        NotificationManager.shared.requestAuthorization()
    }
}