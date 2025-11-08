import SwiftUI
import SwiftData

// MARK: - SwiftData entities

@Model
final class SDSong {
    @Attribute(.unique) var id: String
    var title: String
    var artist: String
    var artworkURLString: String?
    var albumColorRaw: String
    var dateAdded: Date?  // Made optional to handle old songs without this field
    @Relationship(deleteRule: .cascade) var parts: [SDSongPart]

    init(id: String = UUID().uuidString, title: String, artist: String, artworkURLString: String? = nil, albumColorRaw: String, parts: [SDSongPart] = [], dateAdded: Date? = Date()) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artworkURLString = artworkURLString
        self.albumColorRaw = albumColorRaw
        self.dateAdded = dateAdded
        self.parts = parts
    }
}

@Model
final class SDSongPart {
    @Attribute(.unique) var id: String
    var name: String
    var statusRaw: String
    @Relationship(deleteRule: .cascade) var recordings: [SDRecording]

    init(id: String = UUID().uuidString, name: String, statusRaw: String, recordings: [SDRecording] = []) {
        self.id = id
        self.name = name
        self.statusRaw = statusRaw
        self.recordings = recordings
    }
}

@Model
final class SDRecording {
    @Attribute(.unique) var id: String
    var typeRaw: String
    var date: Date
    var note: String
    var fileURL: String?

    init(id: String = UUID().uuidString, typeRaw: String, date: Date, note: String, fileURL: String?) {
        self.id = id
        self.typeRaw = typeRaw
        self.date = date
        self.note = note
        self.fileURL = fileURL
    }
}


@Model
final class SDLoop {
    @Attribute(.unique) var id: String
    var recordingId: String
    var songId: String
    var songTitle: String
    var songArtist: String
    var partType: String
    var lengthSeconds: Double
    var dateCreated: Date
    var bpm: Int?
    var key: String?
    var tagsArray: [String]
    var fileURL: String
    var isImported: Bool
    var sharedBy: String?
    var isStarred: Bool
    
    init(id: String = UUID().uuidString, recordingId: String, songId: String,
         songTitle: String, songArtist: String, partType: String,
         lengthSeconds: Double, dateCreated: Date, bpm: Int? = nil,
         key: String? = nil, tagsArray: [String] = [], fileURL: String,
         isImported: Bool = false, sharedBy: String? = nil, isStarred: Bool = false) {
        self.id = id
        self.recordingId = recordingId
        self.songId = songId
        self.songTitle = songTitle
        self.songArtist = songArtist
        self.partType = partType
        self.lengthSeconds = lengthSeconds
        self.dateCreated = dateCreated
        self.bpm = bpm
        self.key = key
        self.tagsArray = tagsArray
        self.fileURL = fileURL
        self.isImported = isImported
        self.sharedBy = sharedBy
        self.isStarred = isStarred
    }
}


// MARK: - App models (Codable/Identifiable mirrors)

struct MTSong: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var artist: String
    var albumColor: MTAlbumColor
    var artworkURL: String?
    var dateAdded: Date
    var parts: [MTSongPart]

    var completionPercentage: Int {
        let completeParts = parts.filter { $0.status == .complete }.count
        return parts.isEmpty ? 0 : Int((Double(completeParts) / Double(parts.count)) * 100)
    }
    var isFullyLearned: Bool { !parts.isEmpty && parts.allSatisfy { $0.status == .complete } }
}

struct MTSongPart: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var status: PartStatus
    var recordings: [MTRecording]

    enum PartStatus: String, Codable { case learning, complete }
}

struct MTRecording: Identifiable, Codable, Equatable {
    let id: String
    var type: RecordingType
    var date: Date
    var note: String
    var fileURL: String?

    enum RecordingType: String, Codable { case video, audio }
}

// Add MTLoop struct (after MTRecording, before MTAlbumColor)
struct MTLoop: Identifiable, Codable, Equatable {
    let id: String
    var recordingId: String
    var songId: String
    var songTitle: String
    var songArtist: String
    var partType: String
    var lengthSeconds: Double
    var dateCreated: Date
    var bpm: Int?
    var key: String?
    var tags: [String]
    var fileURL: String
    var isImported: Bool
    var sharedBy: String?
    var isStarred: Bool
}

enum MTAlbumColor: String, Codable { case purple, blue, orange, green, fuchsia }

// MARK: - Raw <-> enum helpers

extension MTAlbumColor { init(raw: String) { self = MTAlbumColor(rawValue: raw) ?? .purple }; var raw: String { rawValue } }
extension MTSongPart.PartStatus { init(raw: String) { self = Self(rawValue: raw) ?? .learning }; var raw: String { rawValue } }
extension MTRecording.RecordingType { init(raw: String) { self = Self(rawValue: raw) ?? .audio }; var raw: String { rawValue } }

// MARK: - SwiftData -> App model mapping

extension MTSong {
    init(from sd: SDSong) {
        id = sd.id
        title = sd.title
        artist = sd.artist
        albumColor = MTAlbumColor(raw: sd.albumColorRaw)
        artworkURL = sd.artworkURLString
        dateAdded = sd.dateAdded ?? Date()  // Use Date() as fallback for old songs
        parts = sd.parts.map { MTSongPart(from: $0) }
    }
}

extension MTLoop {
    init(from sd: SDLoop) {
        id = sd.id
        recordingId = sd.recordingId
        songId = sd.songId
        songTitle = sd.songTitle
        songArtist = sd.songArtist
        partType = sd.partType
        lengthSeconds = sd.lengthSeconds
        dateCreated = sd.dateCreated
        bpm = sd.bpm
        key = sd.key
        tags = sd.tagsArray
        fileURL = sd.fileURL
        isImported = sd.isImported
        sharedBy = sd.sharedBy
        isStarred = sd.isStarred
    }
}
extension MTSongPart {
    init(from sd: SDSongPart) {
        id = sd.id
        name = sd.name
        status = .init(raw: sd.statusRaw)
        recordings = sd.recordings.map { MTRecording(from: $0) }
    }
}

extension MTRecording {
    init(from sd: SDRecording) {
        id = sd.id
        type = .init(raw: sd.typeRaw)
        date = sd.date
        note = sd.note
        fileURL = sd.fileURL
    }
}

// MARK: - Standard song parts (centralized)
enum StandardSongPart: String, CaseIterable, Codable {
    case intro = "Intro"
    case riff = "Riff"
    case chords = "Chords"
    case bridge = "Bridge"
    case solo = "Solo"
    case outro = "Outro"
}

extension StandardSongPart {
    static var displayNames: [String] { Self.allCases.map { $0.rawValue } }
}
