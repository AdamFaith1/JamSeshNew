//
//  MusicViewModel.swift
//  Discography
//
//  Created by Adam Faith on 2025-10-12.
//


import SwiftUI
import SwiftData
import AVFoundation
internal import Combine

@MainActor
final class MusicViewModel: ObservableObject {
    @Published var songs: [MTSong] = []
    @Published var selectedSongId: String?
    @Published var expandedParts: Set<String> = []
    @Published var activeTab: Tab = .collection
    @Published var searchQuery = ""
    @Published var isLoading = false
    @Published var notificationMessage: String? = nil
    
    // Grid and sort settings
    @Published var gridColumns: Int = 2
    @Published var sortOption: SortOption = .recentlyUpdated
    @Published var collectionViewMode: CollectionViewMode = .albums

    let loopCatalog = LoopCatalogService()
    
    enum Tab { case home, collection, social, studio }
    enum CollectionViewMode { case albums, clips }
    
    enum SortOption {
        case recentlyUpdated, titleAsc, titleDesc, artistAsc, artistDesc, dateAdded
    }

    // MARK: - UI helpers
    var selectedSong: MTSong? {
        guard let selectedSongId = selectedSongId else { return nil }
        return songs.first { $0.id == selectedSongId }
    }
    
    var filteredSongs: [MTSong] {
        var filtered = songs
        
        // Tab filter
        if activeTab == .studio {
            filtered = filtered.filter { $0.parts.contains { $0.status == .learning } }
        }
        
        // Search filter
        if !searchQuery.isEmpty {
            filtered = filtered.filter {
                $0.title.localizedCaseInsensitiveContains(searchQuery) ||
                $0.artist.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        
        // Sort
        switch sortOption {
        case .recentlyUpdated:
            // Sort by most recent recording date, fallback to ID for consistent ordering
            filtered.sort { (song1: MTSong, song2: MTSong) -> Bool in
                let date1 = song1.parts.flatMap { $0.recordings }.map { $0.date }.max() ?? Date.distantPast
                let date2 = song2.parts.flatMap { $0.recordings }.map { $0.date }.max() ?? Date.distantPast
                
                // If dates are equal, sort by ID for consistency
                if date1 == date2 {
                    return song1.id > song2.id
                }
                return date1 > date2
            }
        case .titleAsc:
            filtered.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .titleDesc:
            filtered.sort { $0.title.localizedCompare($1.title) == .orderedDescending }
        case .artistAsc:
            filtered.sort { $0.artist.localizedCompare($1.artist) == .orderedAscending }
        case .artistDesc:
            filtered.sort { $0.artist.localizedCompare($1.artist) == .orderedDescending }
        case .dateAdded:
            filtered.sort { $0.id > $1.id } // Newest first (assumes newer IDs are later)
        }
        
        return filtered
    }
    
    // MARK: - Clips helpers
    var allClips: [ClipItem] {
        var clips: [ClipItem] = []
        for song in songs {
            for part in song.parts {
                for recording in part.recordings {
                    clips.append(ClipItem(
                        recording: recording,
                        song: song,
                        part: part
                    ))
                }
            }
        }
        
        // Sort by date (most recent first)
        clips.sort { $0.recording.date > $1.recording.date }
        
        // Apply search filter
        if !searchQuery.isEmpty {
            clips = clips.filter {
                $0.song.title.localizedCaseInsensitiveContains(searchQuery) ||
                $0.song.artist.localizedCaseInsensitiveContains(searchQuery) ||
                $0.part.name.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        
        return clips
    }

    func togglePart(_ partId: String) {
        if expandedParts.contains(partId) { expandedParts.remove(partId) } else { expandedParts.insert(partId) }
    }

    // MARK: - Notifications
    private func showNotification(_ message: String) {
        notificationMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if self.notificationMessage == message { self.notificationMessage = nil }
        }
    }

    // MARK: - System
    func configureAudioSession() async {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    print("Microphone permission granted: \(granted)")
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    print("Microphone permission granted: \(granted)")
                }
            }
        } catch { print("Audio session error: \(error)") }
    }

    // MARK: - Data ops (context is passed in)

    func loadSongs(context: ModelContext) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let descriptor = FetchDescriptor<SDSong>(predicate: nil, sortBy: [SortDescriptor(\.title, order: .forward)])
            let sdSongs = try context.fetch(descriptor)
            self.songs = sdSongs.map { MTSong(from: $0) }
        } catch {
            print("SwiftData fetch error: \(error)")
            self.songs = []
        }
        await loopCatalog.loadLoops(context: context)
    }

    func saveRecording(context: ModelContext, songId: String, partId: String, recording: MTRecording) async {
        do {
            let descriptor = FetchDescriptor<SDSong>(predicate: #Predicate { $0.id == songId })
            if let sdSong = try context.fetch(descriptor).first,
               let sdPart = sdSong.parts.first(where: { $0.id == partId }) {
                let sdRec = SDRecording(
                    id: recording.id,
                    typeRaw: recording.type.raw,
                    date: recording.date,
                    note: recording.note,
                    fileURL: recording.fileURL,
                    isLoop: recording.isLoop,
                    loopStartTime: recording.loopStartTime,
                    loopEndTime: recording.loopEndTime
                )
                sdPart.recordings.append(sdRec)
                try context.save()
                
                if let sIdx = songs.firstIndex(where: { $0.id == songId }),
                   let pIdx = songs[sIdx].parts.firstIndex(where: { $0.id == partId }) {
                    songs[sIdx].parts[pIdx].recordings.append(recording)
                    
                    let song = songs[sIdx]
                    let part = songs[sIdx].parts[pIdx]
                    await loopCatalog.createLoopFromRecording(
                        context: context,
                        recording: recording,
                        song: song,
                        part: part
                    )
                }
                showNotification("Saved recording to \(sdSong.title) – \(sdPart.name)")
            }
        } catch { print("Failed to save recording: \(error)") }
    }

    func updatePartStatus(context: ModelContext, songId: String, partId: String, status: MTSongPart.PartStatus) async {
        do {
            let descriptor = FetchDescriptor<SDSong>(predicate: #Predicate { $0.id == songId })
            if let sdSong = try context.fetch(descriptor).first,
               let sdPart = sdSong.parts.first(where: { $0.id == partId }) {
                sdPart.statusRaw = status.raw
                try context.save()
                if let sIdx = songs.firstIndex(where: { $0.id == songId }),
                   let pIdx = songs[sIdx].parts.firstIndex(where: { $0.id == partId }) {
                    songs[sIdx].parts[pIdx].status = status
                }
            }
        } catch { print("Failed to update part status: \(error)") }
    }

    func addSong(context: ModelContext, title: String, artist: String, albumColor: MTAlbumColor, partName: String, partStatus: MTSongPart.PartStatus, artworkURL: String?) async {
        do {
            let firstPart = SDSongPart(name: partName, statusRaw: partStatus.raw)
            let sdSong = SDSong(title: title, artist: artist, artworkURLString: artworkURL, albumColorRaw: albumColor.raw, parts: [firstPart])
            context.insert(sdSong)
            try context.save()
            self.songs.append(MTSong(from: sdSong))
        } catch { print("Failed to add song: \(error)") }
    }

    func addPart(context: ModelContext, to song: MTSong, name: String, status: MTSongPart.PartStatus) async {
        do {
            let descriptor = FetchDescriptor<SDSong>(predicate: #Predicate { $0.id == song.id })
            if let sdSong = try context.fetch(descriptor).first {
                let sdPart = SDSongPart(name: name, statusRaw: status.raw)
                sdSong.parts.append(sdPart)
                try context.save()
                
                // Update the in-memory model and ensure UI refresh
                if let idx = songs.firstIndex(where: { $0.id == song.id }) {
                    let newMTPart = MTSongPart(from: sdPart)
                    songs[idx].parts.append(newMTPart)
                }
                
                showNotification("Added \"\(name)\" to \"\(song.title)\"")
            }
        } catch {
            print("Failed to add part: \(error)")
            showNotification("Failed to add part")
        }
    }

    func deleteRecording(context: ModelContext, songId: String, partId: String, recordingId: String) async {
        do {
            let descriptor = FetchDescriptor<SDSong>(predicate: #Predicate { $0.id == songId })
            if let sdSong = try context.fetch(descriptor).first,
               let sdPart = sdSong.parts.first(where: { $0.id == partId }),
               let sdRecording = sdPart.recordings.first(where: { $0.id == recordingId }) {
                
                if let idx = sdPart.recordings.firstIndex(where: { $0.id == recordingId }) {
                    sdPart.recordings.remove(at: idx)
                }
                context.delete(sdRecording)
                try context.save()
                
                // Update in-memory model
                if let sIdx = songs.firstIndex(where: { $0.id == songId }),
                   let pIdx = songs[sIdx].parts.firstIndex(where: { $0.id == partId }) {
                    songs[sIdx].parts[pIdx].recordings.removeAll { $0.id == recordingId }
                }
                
                // ← NEW: Delete associated loop
                if let loopToDelete = loopCatalog.loops.first(where: { $0.recordingId == recordingId }) {
                    await loopCatalog.deleteLoop(context: context, loopId: loopToDelete.id)
                }
                
                showNotification("Recording deleted")
            }
        } catch {
            print("Failed to delete recording: \(error)")
            showNotification("Failed to delete recording")
        }
    }
    
    func deletePart(context: ModelContext, song: MTSong, part: MTSongPart) async {
        do {
            let descriptor = FetchDescriptor<SDSong>(predicate: #Predicate { $0.id == song.id })
            if let sdSong = try context.fetch(descriptor).first,
               let sdPart = sdSong.parts.first(where: { $0.id == part.id }) {
                if let idx = sdSong.parts.firstIndex(where: { $0.id == sdPart.id }) {
                    sdSong.parts.remove(at: idx)
                }
                context.delete(sdPart)
                try context.save()
                if let sIdx = songs.firstIndex(where: { $0.id == song.id }) {
                    songs[sIdx].parts.removeAll { $0.id == part.id }
                }
            }
        } catch { print("Failed to delete part: \(error)") }
    }

    func addOrUpdateSong(context: ModelContext, title: String, artist: String, albumColor: MTAlbumColor, partName: String, partStatus: MTSongPart.PartStatus, artworkURL: String?) async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)

        if let index = songs.firstIndex(where: {
            $0.title.localizedCaseInsensitiveCompare(trimmedTitle) == .orderedSame &&
            $0.artist.localizedCaseInsensitiveCompare(trimmedArtist) == .orderedSame
        }) {
            let existing = songs[index]
            do {
                let descriptor = FetchDescriptor<SDSong>(predicate: #Predicate { $0.id == existing.id })
                if let sdSong = try context.fetch(descriptor).first {
                    let newPart = SDSongPart(name: partName, statusRaw: partStatus.raw)
                    sdSong.parts.append(newPart)
                    try context.save()
                    songs[index].parts.append(MTSongPart(from: newPart))
                    showNotification("Added \"\(partName)\" to \"\(existing.title)\"")
                }
            } catch { print("Failed to add part to existing song: \(error)") }
        } else {
            do {
                let sdSong = SDSong(title: trimmedTitle, artist: trimmedArtist, artworkURLString: artworkURL, albumColorRaw: albumColor.raw, parts: [SDSongPart(name: partName, statusRaw: partStatus.raw)])
                context.insert(sdSong)
                try context.save()
                songs.append(MTSong(from: sdSong))
                showNotification("Created \"\(sdSong.title)\" with part \"\(partName)\"")
            } catch { print("Failed to add song: \(error)") }
        }
    }

    func deleteSong(context: ModelContext, song: MTSong) async {
        do {
            let descriptor = FetchDescriptor<SDSong>(predicate: #Predicate { $0.id == song.id })
            if let sdSong = try context.fetch(descriptor).first {
                // Delete all associated recordings and their files
                for sdPart in sdSong.parts {
                    for sdRecording in sdPart.recordings {
                        // Delete the actual file if it exists
                        if let fileURL = sdRecording.fileURL {
                            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                            let fullURL = documentsPath.appendingPathComponent(fileURL)
                            try? FileManager.default.removeItem(at: fullURL)
                        }
                    }
                }
                
                // Delete from SwiftData
                context.delete(sdSong)
                try context.save()
                
                // Update in-memory model
                songs.removeAll { $0.id == song.id }
                
                showNotification("Deleted \"\(song.title)\" and all associated recordings")
            }
        } catch {
            print("Failed to delete song: \(error)")
            showNotification("Failed to delete song")
        }
    }
}

// MARK: - ClipItem for clips view
struct ClipItem: Identifiable {
    let id: String
    let recording: MTRecording
    let song: MTSong
    let part: MTSongPart
    
    init(recording: MTRecording, song: MTSong, part: MTSongPart) {
        self.id = recording.id
        self.recording = recording
        self.song = song
        self.part = part
    }
}
