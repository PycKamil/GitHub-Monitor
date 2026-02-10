import XCTest
@testable import GitHubMonitor

@MainActor
final class GitHubServiceTests: XCTestCase {
    func testStargazersArguments() {
        let args = GitHubService.stargazersArguments(
            repoFullName: "owner/repo",
            perPage: 100,
            page: 1
        )

        XCTAssertEqual(args, [
            "gh", "api", "repos/owner/repo/stargazers?per_page=100&page=1",
            "-H", "Accept: application/vnd.github.star+json",
            "--jq", ".[].starred_at"
        ])
    }
}
