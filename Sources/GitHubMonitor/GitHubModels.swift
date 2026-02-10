import Foundation

struct PRInfo: Codable, Identifiable {
    let number: Int
    let title: String
    let state: String
    let createdAt: Date
    let mergedAt: Date?
    let closedAt: Date?
    let author: String

    var id: Int { number }
    var isMerged: Bool { mergedAt != nil }
    var isOpen: Bool { state == "OPEN" }
}

struct ActionRun: Codable, Identifiable {
    let databaseId: Int
    let name: String
    let status: String
    let conclusion: String
    let createdAt: Date
    let headBranch: String

    var id: Int { databaseId }
    var isSuccess: Bool { conclusion == "success" }
    var isFailure: Bool { conclusion == "failure" }
}

struct IssueInfo: Codable, Identifiable {
    let number: Int
    let title: String
    let state: String
    let createdAt: Date
    let closedAt: Date?
    let author: String
    let labels: [String]

    var id: Int { number }
    var isOpen: Bool { state == "OPEN" }

    var timeToClose: TimeInterval? {
        guard let closedAt else { return nil }
        return closedAt.timeIntervalSince(createdAt)
    }
}

struct ReleaseInfo: Codable, Identifiable {
    let tagName: String
    let name: String
    let publishedAt: Date
    let isPrerelease: Bool

    var id: String { tagName }
}

struct ContributorStat: Codable, Identifiable {
    let login: String
    let contributions: Int
    let weeks: [WeekStat]

    var id: String { login }

    struct WeekStat: Codable {
        let week: Date
        let additions: Int
        let deletions: Int
        let commits: Int
    }
}

struct RepoPeriodStats {
    var prCreated: Int = 0
    var prMerged: Int = 0
    var prOpen: Int = 0

    var issuesOpened: Int = 0
    var issuesClosed: Int = 0
    var issuesOpen: Int = 0

    var actionsTotal: Int = 0
    var actionsSucceeded: Int = 0
    var actionsFailed: Int = 0

    var actionsFailureRate: String {
        guard actionsTotal > 0 else { return "0%" }
        return String(format: "%.1f%%", Double(actionsFailed) / Double(actionsTotal) * 100)
    }

    var actionsHealthPct: Int {
        guard actionsTotal > 0 else { return 100 }
        return Int(Double(actionsTotal - actionsFailed) / Double(actionsTotal) * 100)
    }
}

struct ChartBucket: Identifiable {
    let date: Date
    let label: String
    let value: Int
    let category: String

    var id: String { "\(label)-\(category)" }
}

struct StarDataPoint: Identifiable {
    let date: Date
    let cumulativeCount: Int

    var id: Date { date }
}

struct BranchInfo: Codable, Identifiable {
    let name: String
    let isProtected: Bool
    let lastCommitDate: Date?

    var id: String { name }

    var isStale: Bool {
        guard let lastCommitDate else { return true }
        return Date().timeIntervalSince(lastCommitDate) > 30 * 24 * 3600
    }
}
