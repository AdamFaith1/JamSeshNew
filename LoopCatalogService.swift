//
//  LoopCatalogService.swift
//  JamSesh
//
//  Created by Adam Faith on 2025-11-06.
//

import SwiftUI
import SwiftData
import AVFoundation
internal import Combine

// MARK: - Loop Catalog Service
@MainActor
final class LoopCatalogService: ObservableObject {
    @Published var loops: [MTLoop] = []
    @Published var isLoading = false
    
    // Filters
    @Published var filterPartType: String? = nil
    @Published var filterBPMRange: ClosedRange<Int>? = nil
    @Published var filterKey: String? = nil
    @Published var filterTags: Set<String> = []
    @Published var showOnlyStarred: Bool = false
    @Published var showOnlyImported: Bool = false
    
    // Search
    @Published var searchQuery: String = ""
    
    // MARK: - Computed Properties
    
    var filteredLoops: [MTLoop] {
        var result = loops
        
        // Part type filter
        if let partType = filterPartType {
            result = result.filter { $0.partType == partType }
        }
        
        // BPM range filter
        if let bpmRange = filterBPMRange {
            result = result.filter { loop in
                guard let bpm = loop.bpm else { return false }
                return bpmRange.contains(bpm)
            }
        }
        
        // Key filter
        if let key = filterKey {
            result = result.filter { $0.key == key }
        }
        
        // Tags filter (loop must have ALL selected tags)
        if !filterTags.isEmpty {
            result = result.filter { loop in
                filterTags.isSubset(of: loop.tags)
            }
        }
        
        // Starred filter
        if showOnlyStarred {
            result = result.filter { $0.isStarred }
        }
        
        // Imported filter
        if showOnlyImported {
            result = result.filter { $0.isImported }
        }
        
        // Search query
        if !searchQuery.isEmpty {
            result = result.filter { loop in
                loop.songTitle.localizedCaseInsensitiveContains(searchQuery) ||
                loop.songArtist.localizedCaseInsensitiveContains(searchQuery) ||
                loop.partType.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        
        // Sort by date created (most recent first)
        return result.sorted { $0.dateCreated > $1.dateCreated }
    }
    
    var availablePartTypes: [String] {
        Array(Set(loops.map { $0.partType })).sorted()
    }
    
    var availableKeys: [String] {
        Array(Set(loops.compactMap { $0.key })).sorted()
    }
    
    var availableTags: [String] {
        Array(Set(loops.flatMap { $0.tags })).sorted()
    }
    
    // MARK: - CRUD Operations
    
    func loadLoops(context: ModelContext) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let descriptor = FetchDescriptor<SDLoop>(
                predicate: nil,
                sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
            )
            let sdLoops = try context.fetch(descriptor)
            self.loops = sdLoops.map { MTLoop(from: $0) }
        } catch {
            print("Error loading loops: \(error)")
            self.loops = []
        }
    }
    
    func createLoop(context: ModelContext, loop: MTLoop) async {
        do {
            let sdLoop = SDLoop(
                id: loop.id,
                recordingId: loop.recordingId,
                songId: loop.songId,
                songTitle: loop.songTitle,
                songArtist: loop.songArtist,
                partType: loop.partType,
                lengthSeconds: loop.lengthSeconds,
                dateCreated: loop.dateCreated,
                bpm: loop.bpm,
                key: loop.key,
                tagsArray: loop.tags,
                fileURL: loop.fileURL,
                isImported: loop.isImported,
                sharedBy: loop.sharedBy,
                isStarred: loop.isStarred
            )
            
            context.insert(sdLoop)
            try context.save()
            
            // Update in-memory array
            loops.append(loop)
            
        } catch {
            print("Error creating loop: \(error)")
        }
    }
    
    func updateLoop(context: ModelContext, loop: MTLoop) async {
        do {
            let descriptor = FetchDescriptor<SDLoop>(
                predicate: #Predicate { $0.id == loop.id }
            )
            
            if let sdLoop = try context.fetch(descriptor).first {
                sdLoop.bpm = loop.bpm
                sdLoop.key = loop.key
                sdLoop.tagsArray = loop.tags
                sdLoop.isStarred = loop.isStarred
                
                try context.save()
                
                // Update in-memory array
                if let index = loops.firstIndex(where: { $0.id == loop.id }) {
                    loops[index] = loop
                }
            }
        } catch {
            print("Error updating loop: \(error)")
        }
    }
    
    func deleteLoop(context: ModelContext, loopId: String) async {
        do {
            let descriptor = FetchDescriptor<SDLoop>(
                predicate: #Predicate { $0.id == loopId }
            )
            
            if let sdLoop = try context.fetch(descriptor).first {
                context.delete(sdLoop)
                try context.save()
                
                // Update in-memory array
                loops.removeAll { $0.id == loopId }
            }
        } catch {
            print("Error deleting loop: \(error)")
        }
    }
    
    func toggleStar(context: ModelContext, loopId: String) async {
        guard let index = loops.firstIndex(where: { $0.id == loopId }) else { return }
        
        var loop = loops[index]
        loop.isStarred.toggle()
        
        await updateLoop(context: context, loop: loop)
    }
    
    // MARK: - Utility Functions
    
    func getLoopDuration(fileURL: String) -> TimeInterval? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fullURL = documentsPath.appendingPathComponent(fileURL)
        
        guard FileManager.default.fileExists(atPath: fullURL.path) else { return nil }
        
        do {
            let player = try AVAudioPlayer(contentsOf: fullURL)
            return player.duration
        } catch {
            print("Error getting loop duration: \(error)")
            return nil
        }
    }
    
    func clearFilters() {
        filterPartType = nil
        filterBPMRange = nil
        filterKey = nil
        filterTags = []
        showOnlyStarred = false
        showOnlyImported = false
        searchQuery = ""
    }
    
    // MARK: - Smart Compatibility Helper
    
    func findCompatibleLoops(for loop: MTLoop) -> [MTLoop] {
        loops.filter { candidate in
            guard candidate.id != loop.id else { return false }
            
            // Same or compatible key
            let keyMatch = (loop.key == nil || candidate.key == nil || loop.key == candidate.key)
            
            // Within ±8% BPM
            let bpmMatch: Bool
            if let loopBPM = loop.bpm, let candidateBPM = candidate.bpm {
                let tolerance = Double(loopBPM) * 0.08
                bpmMatch = abs(Double(loopBPM) - Double(candidateBPM)) <= tolerance
            } else {
                bpmMatch = true // If no BPM data, don't filter by it
            }
            
            return keyMatch && bpmMatch
        }
    }
}

// MARK: - Loop Creation Helper (from Recording)

extension LoopCatalogService {
    func createLoopFromRecording(
        context: ModelContext,
        recording: MTRecording,
        song: MTSong,
        part: MTSongPart
    ) async {
        guard let fileURL = recording.fileURL else {
            print("Cannot create loop: recording has no file URL")
            return
        }
        
        // Get duration from audio file
        let duration = getLoopDuration(fileURL: fileURL) ?? 0.0
        
        let loop = MTLoop(
            id: UUID().uuidString,
            recordingId: recording.id,
            songId: song.id,
            songTitle: song.title,
            songArtist: song.artist,
            partType: part.name,
            lengthSeconds: duration,
            dateCreated: recording.date,
            bpm: nil,  // Will be filled by analysis later
            key: nil,  // Will be filled by analysis later
            tags: [],  // Will be filled by analysis later
            fileURL: fileURL,
            isImported: false,
            sharedBy: nil,
            isStarred: false
        )
        
        await createLoop(context: context, loop: loop)
        print("✅ Created loop: \(loop.songTitle) - \(loop.partType) (\(Int(loop.lengthSeconds))s)")
    }
}
