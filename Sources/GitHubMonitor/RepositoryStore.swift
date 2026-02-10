import Foundation
import SwiftUI

@MainActor
final class RepositoryStore: ObservableObject {
    @Published var repositories: [Repository] = []

    private let storageURL: URL

    init() {
        self.storageURL = RepositoryStore.storageLocation()
        self.repositories = RepositoryStore.load(from: storageURL)
    }

    func add(owner: String, name: String) {
        let repo = Repository(owner: owner, name: name)
        guard !repositories.contains(where: { $0.fullName == repo.fullName }) else { return }
        repositories.insert(repo, at: 0)
        save()
    }

    func add(fullName: String) {
        let parts = fullName.split(separator: "/")
        guard parts.count == 2 else { return }
        add(owner: String(parts[0]), name: String(parts[1]))
    }

    func remove(_ repo: Repository) {
        repositories.removeAll { $0.id == repo.id }
        save()
    }

    func remove(at offsets: IndexSet) {
        repositories.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Persistence

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(repositories) else { return }
        try? data.write(to: storageURL, options: [.atomic])
    }

    private static func storageLocation() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("GitHubMonitor", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("repositories.json")
    }

    private static func load(from url: URL) -> [Repository] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Repository].self, from: data)) ?? []
    }
}
