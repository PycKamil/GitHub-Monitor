import Foundation

struct Repository: Identifiable, Codable, Hashable {
    let id: UUID
    var owner: String
    var name: String
    var addedAt: Date

    init(id: UUID = UUID(), owner: String, name: String, addedAt: Date = Date()) {
        self.id = id
        self.owner = owner
        self.name = name
        self.addedAt = addedAt
    }

    var fullName: String { "\(owner)/\(name)" }
}
