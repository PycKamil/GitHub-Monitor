import SwiftUI

@main
struct GitHubMonitorApp: App {
    @StateObject private var repoStore = RepositoryStore()
    @StateObject private var gitHub = GitHubService()
    @StateObject private var monitorData = MonitorData()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(repoStore)
                .environmentObject(gitHub)
                .environmentObject(monitorData)
                .frame(minWidth: 1200, minHeight: 760)
                .task { await gitHub.checkAuth() }
        }
        .windowStyle(.titleBar)
        Settings {
            SettingsView()
                .environmentObject(repoStore)
                .environmentObject(gitHub)
        }
    }
}
