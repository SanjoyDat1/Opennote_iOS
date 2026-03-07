import Foundation

struct Journal: Identifiable {
    let id: String
    var title: String
    var lastEdited: Date
    var isFavorite: Bool
    
    init(id: String = UUID().uuidString, title: String, lastEdited: Date = .now, isFavorite: Bool = false) {
        self.id = id
        self.title = title
        self.lastEdited = lastEdited
        self.isFavorite = isFavorite
    }
}
