import Foundation

struct Song: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var artist: String
    var part: String           // e.g., "Lead", "Intro", "Rhythm", etc.
    var status: String         // "In Progress" or "Completed"
    var createdAt: Date = Date()
}
