import Foundation

struct Paper: Identifiable {
    let id: String
    var title: String
    var lastEdited: Date
    var content: String
    var isFavorite: Bool
    
    init(id: String = UUID().uuidString, title: String, lastEdited: Date = .now, content: String = "", isFavorite: Bool = false) {
        self.id = id
        self.title = title
        self.lastEdited = lastEdited
        self.content = content
        self.isFavorite = isFavorite
    }
}
