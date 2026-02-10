import SwiftUI

@MainActor
struct DashboardView: View {
    @EnvironmentObject private var repoStore: RepositoryStore
    @EnvironmentObject private var gitHub: GitHubService
    @EnvironmentObject private var monitorData: MonitorData

    private let gridColumns = [
        GridItem(.adaptive(minimum: 280), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 24) {
            header
            content
            Spacer()
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
    }

    private var header: some View {
        HStack {
            Text("Dashboard")
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            if monitorData.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
            Button { Task { await monitorData.refresh(repos: repoStore.repositories, gitHub: gitHub) } } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .glassButtonStyle()
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var content: some View {
        if repoStore.repositories.isEmpty {
            VStack(spacing: 12) {
                Text("No repositories")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.textPrimary)
                Text("Add repositories in Settings to start monitoring.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else {
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(repoStore.repositories) { repo in
                        RepoCard(repo: repo, data: monitorData)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}

private struct RepoCard: View {
    let repo: Repository
    @ObservedObject var data: MonitorData

    var body: some View {
        let s = data.stats[repo.fullName]?[.monthly]

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "book.closed")
                    .foregroundStyle(Theme.accent)
                Text(repo.fullName)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Spacer()
            }

            if let s {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatCell(label: "Open PRs", value: "\(s.prOpen)")
                    StatCell(label: "Action Health", value: "\(s.actionsHealthPct)%")
                    StatCell(label: "Open Issues", value: "\(s.issuesOpen)")
                    StatCell(label: "Latest Release", value: data.releases[repo.fullName]?.first?.tagName ?? "—")
                }
            } else {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading…")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: 16, tint: Theme.glassTint, interactive: false, fallbackFill: Theme.card, fallbackStroke: .clear)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }
}

private struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .environmentObject(RepositoryStore())
            .environmentObject(GitHubService())
            .environmentObject(MonitorData())
    }
}
