import Foundation
import SwiftData

/// A category is the top level collection and the same entity the coded folder
/// component draws. An asset lives in one category, or in none, which is Inbox.
@Model
final class ShelfCategory {
    #Index<ShelfCategory>([\.createdAt])

    var id: UUID = UUID()
    var name: String = "New Category"
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Asset.category)
    var assets: [Asset] = []

    init(name: String = "New Category") {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }

    var itemCount: Int { assets.count }
}
