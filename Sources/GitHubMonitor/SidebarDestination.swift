import Foundation

enum SidebarDestination: Hashable {
    case dashboard
    case pullRequests(repo: String)
    case actions(repo: String)
    case issues(repo: String)
    case releases(repo: String)
    case contributors(repo: String)
    case stars(repo: String)
    case branches(repo: String)
}
