import Foundation

@MainActor
final class GitHubService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var authUser = ""

    func checkAuth() async {
        let result = await run(["gh", "auth", "status"])
        isAuthenticated = result.exitCode == 0
        if isAuthenticated {
            let whoami = await run(["gh", "api", "user", "--jq", ".login"])
            authUser = whoami.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: - Pull Requests

    func fetchPRs(for repo: Repository) async -> [PRInfo] {
        let fields = "number,title,state,createdAt,mergedAt,closedAt,author"
        let result = await run([
            "gh", "pr", "list",
            "--repo", repo.fullName,
            "--state", "all",
            "--json", fields,
            "--limit", "25"
        ])
        return decode(result.output, transform: { (raw: [PRRaw]) in
            raw.map { $0.toPRInfo() }
        }) ?? []
    }

    // MARK: - Actions

    func fetchActionRuns(for repo: Repository) async -> [ActionRun] {
        let fields = "databaseId,name,status,conclusion,createdAt,headBranch"
        let result = await run([
            "gh", "run", "list",
            "--repo", repo.fullName,
            "--json", fields,
            "--limit", "25"
        ])
        return decode(result.output) ?? []
    }

    // MARK: - Issues

    func fetchIssues(for repo: Repository) async -> [IssueInfo] {
        let fields = "number,title,state,createdAt,closedAt,author,labels"
        let result = await run([
            "gh", "issue", "list",
            "--repo", repo.fullName,
            "--state", "all",
            "--json", fields,
            "--limit", "25"
        ])
        return decode(result.output, transform: { (raw: [IssueRaw]) in
            raw.map { $0.toIssueInfo() }
        }) ?? []
    }

    // MARK: - Releases

    func fetchReleases(for repo: Repository) async -> [ReleaseInfo] {
        let fields = "tagName,name,publishedAt,isPrerelease"
        let result = await run([
            "gh", "release", "list",
            "--repo", repo.fullName,
            "--json", fields,
            "--limit", "50"
        ])
        return decode(result.output) ?? []
    }

    // MARK: - Contributors

    func fetchContributors(for repo: Repository) async -> [ContributorStat] {
        let result = await run([
            "gh", "api", "repos/\(repo.fullName)/stats/contributors"
        ])
        return decode(result.output, transform: { (raw: [ContributorRaw]) in
            raw.map { $0.toContributorStat() }
        }) ?? []
    }

    // MARK: - Branches

    func fetchBranches(for repo: Repository) async -> [BranchInfo] {
        let result = await run([
            "gh", "api", "repos/\(repo.fullName)/branches", "--paginate"
        ])
        return decode(result.output, transform: { (raw: [BranchRaw]) in
            raw.map { $0.toBranchInfo() }
        }) ?? []
    }

    // MARK: - Stars

    func fetchStarHistory(for repo: Repository) async -> [StarDataPoint] {
        // Get total star count first
        let infoResult = await run(["gh", "api", "repos/\(repo.fullName)", "--jq", ".stargazers_count"])
        let totalStars = Int(infoResult.output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        guard totalStars > 0 else { return [] }

        let perPage = 100
        let totalPages = (totalStars + perPage - 1) / perPage

        // For repos with <= 5000 stars, fetch all pages; otherwise sample ~50 pages
        let pagesToFetch: [Int]
        if totalPages <= 50 {
            pagesToFetch = Array(1...totalPages)
        } else {
            // Sample evenly across all pages
            let sampleCount = 50
            pagesToFetch = (0..<sampleCount).map { i in
                max(1, Int(Double(i) / Double(sampleCount - 1) * Double(totalPages - 1)) + 1)
            }
        }

        // Fetch pages in parallel
        let allDates: [Date] = await withTaskGroup(of: [Date].self) { group -> [Date] in
            for page in pagesToFetch {
                group.addTask {
                    let result = await self.run([
                        "gh", "api", "repos/\(repo.fullName)/stargazers?per_page=\(perPage)&page=\(page)",
                        "-H", "Accept: application/vnd.github.star+json",
                        "--jq", ".[].starred_at"
                    ])
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let fallback = ISO8601DateFormatter()
                    return result.output
                        .split(separator: "\n")
                        .compactMap { line in
                            let s = String(line).trimmingCharacters(in: .whitespaces)
                            return formatter.date(from: s) ?? fallback.date(from: s)
                        }
                }
            }
            var collected: [Date] = []
            for await dates in group { collected.append(contentsOf: dates) }
            return collected
        }

        guard !allDates.isEmpty else { return [] }
        let sorted = allDates.sorted()

        // Group by month and build cumulative curve
        let cal = Calendar.current
        var monthBuckets: [(date: Date, count: Int)] = []
        var currentMonth: DateComponents?
        var countInMonth = 0

        for date in sorted {
            let comps = cal.dateComponents([.year, .month], from: date)
            if comps != currentMonth {
                if let prev = currentMonth,
                   let d = cal.date(from: prev) {
                    monthBuckets.append((d, countInMonth))
                }
                currentMonth = comps
                countInMonth = 0
            }
            countInMonth += 1
        }
        if let last = currentMonth, let d = cal.date(from: last) {
            monthBuckets.append((d, countInMonth))
        }

        // Build cumulative data points
        var cumulative = 0
        // If we sampled, scale each bucket proportionally
        let scale = totalPages <= 50 ? 1.0 : Double(totalStars) / Double(allDates.count)
        var points: [StarDataPoint] = []
        for bucket in monthBuckets {
            cumulative += Int(Double(bucket.count) * scale)
            points.append(StarDataPoint(date: bucket.date, cumulativeCount: min(cumulative, totalStars)))
        }
        // Ensure the last point matches actual total
        if var last = points.last {
            last = StarDataPoint(date: last.date, cumulativeCount: totalStars)
            points[points.count - 1] = last
        }
        return points
    }

    // MARK: - Stats (API-based counts)

    func fetchStats(for repo: Repository, period: TimePeriod) async -> RepoPeriodStats {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let startStr = dateFormatter.string(from: period.startDate())
        let endStr = dateFormatter.string(from: Date())
        let dateRange = "\(startStr)..\(endStr)"
        let repoQ = "repo:\(repo.fullName)"

        async let graphQLResult = fetchGraphQLCounts(repo: repoQ, dateRange: dateRange)
        async let actionsResult = fetchActionsCounts(repo: repo, dateRange: dateRange)

        let gql = await graphQLResult
        let actions = await actionsResult

        return RepoPeriodStats(
            prCreated: gql.prCreated,
            prMerged: gql.prMerged,
            prOpen: gql.prOpen,
            issuesOpened: gql.issuesOpened,
            issuesClosed: gql.issuesClosed,
            issuesOpen: gql.issuesOpen,
            actionsTotal: actions.total,
            actionsSucceeded: actions.succeeded,
            actionsFailed: actions.failed
        )
    }

    private struct GraphQLCounts: Sendable {
        var prCreated = 0, prMerged = 0, prOpen = 0
        var issuesOpened = 0, issuesClosed = 0, issuesOpen = 0
    }

    private func fetchGraphQLCounts(repo: String, dateRange: String) async -> GraphQLCounts {
        let query = """
        {
          prCreated: search(query: "\(repo) type:pr created:\(dateRange)", type: ISSUE) { issueCount }
          prMerged: search(query: "\(repo) type:pr is:merged created:\(dateRange)", type: ISSUE) { issueCount }
          prOpen: search(query: "\(repo) type:pr is:open", type: ISSUE) { issueCount }
          issuesOpened: search(query: "\(repo) type:issue created:\(dateRange)", type: ISSUE) { issueCount }
          issuesClosed: search(query: "\(repo) type:issue is:closed created:\(dateRange)", type: ISSUE) { issueCount }
          issuesOpen: search(query: "\(repo) type:issue is:open", type: ISSUE) { issueCount }
        }
        """
        let result = await run(["gh", "api", "graphql", "-f", "query=\(query)"])
        guard let data = result.output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any] else {
            return GraphQLCounts()
        }

        func count(_ key: String) -> Int {
            (dataObj[key] as? [String: Any])?["issueCount"] as? Int ?? 0
        }

        return GraphQLCounts(
            prCreated: count("prCreated"), prMerged: count("prMerged"), prOpen: count("prOpen"),
            issuesOpened: count("issuesOpened"), issuesClosed: count("issuesClosed"), issuesOpen: count("issuesOpen")
        )
    }

    private struct ActionsCounts: Sendable {
        var total = 0, succeeded = 0, failed = 0
    }

    private func fetchActionsCounts(repo: Repository, dateRange: String) async -> ActionsCounts {
        async let totalResult = run(["gh", "api", "repos/\(repo.fullName)/actions/runs?created=\(dateRange)&per_page=1"])
        async let failedResult = run(["gh", "api", "repos/\(repo.fullName)/actions/runs?created=\(dateRange)&per_page=1&conclusion=failure"])
        async let succeededResult = run(["gh", "api", "repos/\(repo.fullName)/actions/runs?created=\(dateRange)&per_page=1&conclusion=success"])

        let total = await extractTotalCount(totalResult)
        let failed = await extractTotalCount(failedResult)
        let succeeded = await extractTotalCount(succeededResult)

        return ActionsCounts(total: total, succeeded: succeeded, failed: failed)
    }

    private nonisolated func extractTotalCount(_ result: ProcessResult) -> Int {
        guard let data = result.output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let count = json["total_count"] as? Int else { return 0 }
        return count
    }

    // MARK: - Chart Data (per-bucket counts)

    struct ChartData: Sendable {
        var prCreated: [ChartBucket] = []
        var prMerged: [ChartBucket] = []
        var issuesOpened: [ChartBucket] = []
        var issuesClosed: [ChartBucket] = []
        var actionsSucceeded: [ChartBucket] = []
        var actionsFailed: [ChartBucket] = []
    }

    func fetchChartData(for repo: Repository, period: TimePeriod) async -> ChartData {
        let buckets = period.dateBuckets()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        async let prIssueChart = fetchPRIssueChartData(repo: repo.fullName, buckets: buckets, df: df, period: period)
        async let actionsChart = fetchActionsChartData(repo: repo, buckets: buckets, df: df, period: period)

        let pi = await prIssueChart
        let ac = await actionsChart

        return ChartData(
            prCreated: pi.prCreated, prMerged: pi.prMerged,
            issuesOpened: pi.issuesOpened, issuesClosed: pi.issuesClosed,
            actionsSucceeded: ac.succeeded, actionsFailed: ac.failed
        )
    }

    private struct PRIssueChartResult: Sendable {
        var prCreated: [ChartBucket] = []
        var prMerged: [ChartBucket] = []
        var issuesOpened: [ChartBucket] = []
        var issuesClosed: [ChartBucket] = []
    }

    private func fetchPRIssueChartData(repo: String, buckets: [(start: Date, end: Date)], df: DateFormatter, period: TimePeriod) async -> PRIssueChartResult {
        // Build a single GraphQL query with aliases for each bucket
        var aliases: [String] = []
        for (i, bucket) in buckets.enumerated() {
            let range = "\(df.string(from: bucket.start))..\(df.string(from: bucket.end))"
            let rq = "repo:\(repo)"
            aliases.append("prC\(i): search(query: \"\(rq) type:pr created:\(range)\", type: ISSUE) { issueCount }")
            aliases.append("prM\(i): search(query: \"\(rq) type:pr is:merged created:\(range)\", type: ISSUE) { issueCount }")
            aliases.append("issO\(i): search(query: \"\(rq) type:issue created:\(range)\", type: ISSUE) { issueCount }")
            aliases.append("issC\(i): search(query: \"\(rq) type:issue is:closed created:\(range)\", type: ISSUE) { issueCount }")
        }

        let query = "{ " + aliases.joined(separator: "\n") + " }"
        let result = await run(["gh", "api", "graphql", "-f", "query=\(query)"])

        guard let data = result.output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any] else {
            return PRIssueChartResult()
        }

        func count(_ key: String) -> Int {
            (dataObj[key] as? [String: Any])?["issueCount"] as? Int ?? 0
        }

        var res = PRIssueChartResult()
        for (i, bucket) in buckets.enumerated() {
            let label = period.bucketLabel(for: bucket.start)
            res.prCreated.append(ChartBucket(date: bucket.start, label: label, value: count("prC\(i)"), category: "Created"))
            res.prMerged.append(ChartBucket(date: bucket.start, label: label, value: count("prM\(i)"), category: "Merged"))
            res.issuesOpened.append(ChartBucket(date: bucket.start, label: label, value: count("issO\(i)"), category: "Opened"))
            res.issuesClosed.append(ChartBucket(date: bucket.start, label: label, value: count("issC\(i)"), category: "Closed"))
        }
        return res
    }

    private struct ActionsChartResult: Sendable {
        var succeeded: [ChartBucket] = []
        var failed: [ChartBucket] = []
    }

    private func fetchActionsChartData(repo: Repository, buckets: [(start: Date, end: Date)], df: DateFormatter, period: TimePeriod) async -> ActionsChartResult {
        var succeeded: [ChartBucket] = []
        var failed: [ChartBucket] = []

        // Fetch in parallel using task group (max ~12 buckets × 2 calls)
        let results = await withTaskGroup(of: (Int, Int, Int).self) { group -> [(Int, Int, Int)] in
            for (i, bucket) in buckets.enumerated() {
                group.addTask {
                    let range = "\(df.string(from: bucket.start))..\(df.string(from: bucket.end))"
                    let sResult = await self.run(["gh", "api", "repos/\(repo.fullName)/actions/runs?created=\(range)&per_page=1&conclusion=success"])
                    let fResult = await self.run(["gh", "api", "repos/\(repo.fullName)/actions/runs?created=\(range)&per_page=1&conclusion=failure"])
                    return (i, self.extractTotalCount(sResult), self.extractTotalCount(fResult))
                }
            }
            var collected: [(Int, Int, Int)] = []
            for await item in group { collected.append(item) }
            return collected.sorted { $0.0 < $1.0 }
        }

        for (i, sCount, fCount) in results {
            let label = period.bucketLabel(for: buckets[i].start)
            succeeded.append(ChartBucket(date: buckets[i].start, label: label, value: sCount, category: "Succeeded"))
            failed.append(ChartBucket(date: buckets[i].start, label: label, value: fCount, category: "Failed"))
        }

        return ActionsChartResult(succeeded: succeeded, failed: failed)
    }

    // MARK: - Helpers

    private func run(_ arguments: [String]) async -> ProcessResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                let escaped = arguments.map { arg in
                    "'\(arg.replacingOccurrences(of: "'", with: "'\\''"))'"
                }.joined(separator: " ")
                process.arguments = ["-lc", escaped]

                let pipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = pipe
                process.standardError = errPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: ProcessResult(output: "", exitCode: -1))
                    return
                }

                // Read pipe BEFORE waitUntilExit to avoid deadlock when
                // output exceeds the ~64 KB pipe buffer.
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                let output = String(decoding: data, as: UTF8.self)
                continuation.resume(returning: ProcessResult(output: output, exitCode: process.terminationStatus))
            }
        }
    }

    private func decode<T: Decodable>(_ json: String) -> T? {
        guard let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    private func decode<T: Decodable, R>(_ json: String, transform: (T) -> R) -> R? {
        guard let decoded: T = decode(json) else { return nil }
        return transform(decoded)
    }
}

private struct ProcessResult {
    let output: String
    let exitCode: Int32
}

// MARK: - Raw API models for decoding

private struct PRRaw: Decodable {
    let number: Int
    let title: String
    let state: String
    let createdAt: Date
    let mergedAt: Date?
    let closedAt: Date?
    let author: AuthorRaw?

    func toPRInfo() -> PRInfo {
        PRInfo(
            number: number, title: title, state: state,
            createdAt: createdAt, mergedAt: mergedAt, closedAt: closedAt,
            author: author?.login ?? "unknown"
        )
    }
}

private struct AuthorRaw: Decodable {
    let login: String?
}

private struct IssueRaw: Decodable {
    let number: Int
    let title: String
    let state: String
    let createdAt: Date
    let closedAt: Date?
    let author: AuthorRaw?
    let labels: [LabelRaw]?

    func toIssueInfo() -> IssueInfo {
        IssueInfo(
            number: number, title: title, state: state,
            createdAt: createdAt, closedAt: closedAt,
            author: author?.login ?? "unknown",
            labels: labels?.map(\.name) ?? []
        )
    }
}

private struct LabelRaw: Decodable {
    let name: String
}

private struct ContributorRaw: Decodable {
    let author: ContributorAuthor?
    let total: Int
    let weeks: [WeekRaw]

    struct ContributorAuthor: Decodable {
        let login: String
    }

    struct WeekRaw: Decodable {
        let w: Int
        let a: Int
        let d: Int
        let c: Int
    }

    func toContributorStat() -> ContributorStat {
        ContributorStat(
            login: author?.login ?? "unknown",
            contributions: total,
            weeks: weeks.map {
                ContributorStat.WeekStat(
                    week: Date(timeIntervalSince1970: TimeInterval($0.w)),
                    additions: $0.a, deletions: $0.d, commits: $0.c
                )
            }
        )
    }
}

private struct BranchRaw: Decodable {
    let name: String
    let protected: Bool?
    let commit: CommitRaw?

    struct CommitRaw: Decodable {
        let commit: CommitDetail?

        struct CommitDetail: Decodable {
            let committer: CommitterRaw?

            struct CommitterRaw: Decodable {
                let date: String?
            }
        }
    }

    func toBranchInfo() -> BranchInfo {
        let dateStr = commit?.commit?.committer?.date
        var lastCommit: Date? = nil
        if let dateStr {
            let formatter = ISO8601DateFormatter()
            lastCommit = formatter.date(from: dateStr)
        }
        return BranchInfo(
            name: name,
            isProtected: protected ?? false,
            lastCommitDate: lastCommit
        )
    }
}
