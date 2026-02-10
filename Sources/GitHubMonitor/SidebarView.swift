import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarDestination?
    @EnvironmentObject private var repoStore: RepositoryStore
    @EnvironmentObject private var gitHub: GitHubService

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                Section("Overview") {
                    NavigationLink(value: SidebarDestination.dashboard) {
                        Label("Dashboard", systemImage: "square.grid.2x2")
                    }
                }

                Section("Repositories") {
                    if repoStore.repositories.isEmpty {
                        Text("No repos added")
                            .foregroundStyle(Theme.textTertiary)
                            .font(.caption)
                    } else {
                        ForEach(repoStore.repositories) { repo in
                            DisclosureGroup {
                                NavigationLink(value: SidebarDestination.pullRequests(repo: repo.fullName)) {
                                    Label("Pull Requests", systemImage: "arrow.triangle.branch")
                                }
                                NavigationLink(value: SidebarDestination.actions(repo: repo.fullName)) {
                                    Label("Actions", systemImage: "gearshape.2")
                                }
                                NavigationLink(value: SidebarDestination.issues(repo: repo.fullName)) {
                                    Label("Issues", systemImage: "exclamationmark.circle")
                                }
                                NavigationLink(value: SidebarDestination.releases(repo: repo.fullName)) {
                                    Label("Releases", systemImage: "tag")
                                }
                                NavigationLink(value: SidebarDestination.contributors(repo: repo.fullName)) {
                                    Label("Contributors", systemImage: "person.3")
                                }
                                NavigationLink(value: SidebarDestination.stars(repo: repo.fullName)) {
                                    Label("Stars", systemImage: "star")
                                }
                                NavigationLink(value: SidebarDestination.branches(repo: repo.fullName)) {
                                    Label("Branches", systemImage: "point.3.connected.trianglepath.dotted")
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "book.closed")
                                        .foregroundStyle(Theme.accent)
                                        .font(.caption)
                                    Text(repo.fullName)
                                        .font(.body)
                                        .foregroundStyle(Theme.textPrimary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .tint(Theme.accent)
            .background(Color.clear)

            HStack {
                authStatusView
                Spacer()
                SettingsLink {
                    Label("Settings", systemImage: "gear")
                }
                .glassButtonStyle()
                .tint(Theme.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 220)
        .background(sidebarBackground)
    }

    @ViewBuilder
    private var authStatusView: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(gitHub.isAuthenticated ? Color.green : Color.red)
                .frame(width: 6, height: 6)
            Text(gitHub.isAuthenticated ? gitHub.authUser : "Not signed in")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var sidebarBackground: some View {
        if #available(macOS 26, *) {
            Rectangle()
                .fill(.clear)
                .glassEffect(.regular.tint(Theme.glassSidebarTint), in: .rect(cornerRadius: 0))
        } else {
            Theme.sidebar
        }
    }
}

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView(selection: .constant(.dashboard))
            .environmentObject(RepositoryStore())
            .environmentObject(GitHubService())
    }
}
