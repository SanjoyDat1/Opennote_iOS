import Foundation

struct Journal: Identifiable {
    let id: String
    var title: String
    var lastEdited: Date
    
    init(id: String = UUID().uuidString, title: String, lastEdited: Date = .now) {
        self.id = id
        self.title = title
        self.lastEdited = lastEdited
    }
}
