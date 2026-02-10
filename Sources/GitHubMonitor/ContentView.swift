import SwiftUI

@MainActor
struct ContentView: View {
    @EnvironmentObject private var repoStore: RepositoryStore
    @EnvironmentObject private var gitHub: GitHubService
    @EnvironmentObject private var monitorData: MonitorData
    @State private var selection: SidebarDestination? = .dashboard

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()
            WindowGlassConfigurator()

            NavigationSplitView {
                SidebarView(selection: $selection)
            } detail: {
                Group {
                    switch selection ?? .dashboard {
                    case .dashboard:
                        DashboardView()
                    case .pullRequests(let repo):
                        PullRequestsView(repoName: repo)
                    case .actions(let repo):
                        ActionsView(repoName: repo)
                    case .issues(let repo):
                        IssuesView(repoName: repo)
                    case .releases(let repo):
                        ReleasesView(repoName: repo)
                    case .contributors(let repo):
                        ContributorsView(repoName: repo)
                    case .stars(let repo):
                        StarsView(repoName: repo)
                    case .branches(let repo):
                        BranchHealthView(repoName: repo)
                    }
                }
                .id(selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
                .task {
                    await monitorData.loadIfNeeded(repos: repoStore.repositories, gitHub: gitHub)
                }
            }
            .navigationSplitViewStyle(.balanced)

            if let message = gitHub.apiErrorMessage {
                ErrorToast(message: message)
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                    .onTapGesture {
                        withAnimation {
                            gitHub.apiErrorMessage = nil
                        }
                    }
            }
        }
        .background(Color.clear)
        .onChange(of: gitHub.apiErrorMessage) { newValue in
            guard let message = newValue else { return }
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if gitHub.apiErrorMessage == message {
                    withAnimation {
                        gitHub.apiErrorMessage = nil
                    }
                }
            }
        }
        .animation(.easeInOut, value: gitHub.apiErrorMessage)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(RepositoryStore())
            .environmentObject(GitHubService())
            .environmentObject(MonitorData())
    }
}
