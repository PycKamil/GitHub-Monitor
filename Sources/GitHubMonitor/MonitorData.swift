import Foundation
import SwiftUI

@MainActor
final class MonitorData: ObservableObject {
    // API-based exact counts, keyed by repoName then period
    @Published var stats: [String: [TimePeriod: RepoPeriodStats]] = [:]

    // Recent items for list display (small page, period-independent)
    @Published var recentPRs: [String: [PRInfo]] = [:]
    @Published var recentRuns: [String: [ActionRun]] = [:]
    @Published var recentIssues: [String: [IssueInfo]] = [:]

    // These are low-volume, keep as full arrays
    @Published var releases: [String: [ReleaseInfo]] = [:]
    @Published var contributors: [String: [ContributorStat]] = [:]
    @Published var branches: [String: [BranchInfo]] = [:]
    @Published var starHistory: [String: [StarDataPoint]] = [:]

    // Chart data keyed by repo+period
    @Published var chartData: [String: [TimePeriod: GitHubService.ChartData]] = [:]

    @Published var isLoading = false

    private var loadedRepos: Set<String> = []

    func loadIfNeeded(repos: [Repository], gitHub: GitHubService) async {
        let repoNames = Set(repos.map(\.fullName))
        let missing = repos.filter { !loadedRepos.contains($0.fullName) }

        // Clean removed repos
        for name in loadedRepos where !repoNames.contains(name) {
            stats.removeValue(forKey: name)
            recentPRs.removeValue(forKey: name)
            recentRuns.removeValue(forKey: name)
            recentIssues.removeValue(forKey: name)
            releases.removeValue(forKey: name)
            contributors.removeValue(forKey: name)
            branches.removeValue(forKey: name)
            starHistory.removeValue(forKey: name)
            chartData.removeValue(forKey: name)
            loadedRepos.remove(name)
        }

        guard !missing.isEmpty else { return }
        await load(repos: missing, gitHub: gitHub)
    }

    func refresh(repos: [Repository], gitHub: GitHubService) async {
        loadedRepos.removeAll()
        stats.removeAll()
        recentPRs.removeAll()
        recentRuns.removeAll()
        recentIssues.removeAll()
        releases.removeAll()
        contributors.removeAll()
        branches.removeAll()
        starHistory.removeAll()
        chartData.removeAll()
        await load(repos: repos, gitHub: gitHub)
    }

    /// Fetch stats for a specific repo+period if not already cached
    func fetchStatsIfNeeded(repo: String, period: TimePeriod, gitHub: GitHubService) async {
        if stats[repo]?[period] != nil { return }
        guard let repository = repositoryFromName(repo) else { return }
        let result = await gitHub.fetchStats(for: repository, period: period)
        if stats[repo] == nil { stats[repo] = [:] }
        stats[repo]?[period] = result
    }

    /// Fetch chart data for a specific repo+period if not already cached
    func fetchChartIfNeeded(repo: String, period: TimePeriod, gitHub: GitHubService) async {
        if chartData[repo]?[period] != nil { return }
        guard let repository = repositoryFromName(repo) else { return }
        let result = await gitHub.fetchChartData(for: repository, period: period)
        if chartData[repo] == nil { chartData[repo] = [:] }
        chartData[repo]?[period] = result
    }

    /// Fetch star history for a repo if not already cached
    func fetchStarHistoryIfNeeded(repo: String, gitHub: GitHubService) async {
        if starHistory[repo] != nil { return }
        guard let repository = repositoryFromName(repo) else { return }
        let result = await gitHub.fetchStarHistory(for: repository)
        starHistory[repo] = result
    }

    private func repositoryFromName(_ fullName: String) -> Repository? {
        let parts = fullName.split(separator: "/")
        guard parts.count == 2 else { return nil }
        return Repository(owner: String(parts[0]), name: String(parts[1]))
    }

    private func load(repos: [Repository], gitHub: GitHubService) async {
        isLoading = true
        await withTaskGroup(of: (String, RepoData).self) { group in
            for repo in repos {
                group.addTask {
                    async let statsResult = gitHub.fetchStats(for: repo, period: .monthly)
                    async let prs = gitHub.fetchPRs(for: repo)
                    async let runs = gitHub.fetchActionRuns(for: repo)
                    async let issues = gitHub.fetchIssues(for: repo)
                    async let rels = gitHub.fetchReleases(for: repo)
                    async let contribs = gitHub.fetchContributors(for: repo)
                    async let brs = gitHub.fetchBranches(for: repo)
                    return (repo.fullName, RepoData(
                        stats: await statsResult,
                        recentPRs: await prs, recentRuns: await runs,
                        recentIssues: await issues, releases: await rels,
                        contributors: await contribs, branches: await brs
                    ))
                }
            }
            for await (name, data) in group {
                stats[name] = [.monthly: data.stats]
                recentPRs[name] = data.recentPRs
                recentRuns[name] = data.recentRuns
                recentIssues[name] = data.recentIssues
                releases[name] = data.releases
                contributors[name] = data.contributors
                branches[name] = data.branches
                loadedRepos.insert(name)
            }
        }
        isLoading = false
    }
}

private struct RepoData {
    let stats: RepoPeriodStats
    let recentPRs: [PRInfo]
    let recentRuns: [ActionRun]
    let recentIssues: [IssueInfo]
    let releases: [ReleaseInfo]
    let contributors: [ContributorStat]
    let branches: [BranchInfo]
}
