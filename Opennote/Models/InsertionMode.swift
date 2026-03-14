import Foundation

/// How to insert scanned text into a note.
enum InsertionMode {
    case atCursor(position: Int)
    case appendToEnd
    case replaceAll
}
