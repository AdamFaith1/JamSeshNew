//
//  CompositionModels.swift
//  JamSeshNew
//
//  Created by Adam Faith on 2025-11-08.
//

import Foundation
import SwiftData

// MARK: - Composition Models

struct Composition: Identifiable, Codable {
    let id: String
    var title: String
    var createdDate: Date
    var tracks: [CompositionTrack]
    var duration: Double
}

struct CompositionTrack: Identifiable, Codable {
    let id: String
    var recordingId: String
    var startTime: Double
    var volume: Float
    var isMuted: Bool
    var trackColor: String
}

@Model
final class SDComposition {
    @Attribute(.unique) var id: String
    var title: String
    var createdDate: Date
    var duration: Double
    @Relationship(deleteRule: .cascade) var tracks: [SDCompositionTrack]
    
    init(id: String = UUID().uuidString, title: String, createdDate: Date, duration: Double, tracks: [SDCompositionTrack] = []) {
        self.id = id
        self.title = title
        self.createdDate = createdDate
        self.duration = duration
        self.tracks = tracks
    }
}

@Model
final class SDCompositionTrack {
    @Attribute(.unique) var id: String
    var recordingId: String
    var startTime: Double
    var volume: Float
    var isMuted: Bool
    var trackColor: String
    
    init(id: String = UUID().uuidString, recordingId: String, startTime: Double, volume: Float = 1.0, isMuted: Bool = false, trackColor: String = "purple") {
        self.id = id
        self.recordingId = recordingId
        self.startTime = startTime
        self.volume = volume
        self.isMuted = isMuted
        self.trackColor = trackColor
    }
}

extension Composition {
    init(from sd: SDComposition) {
        id = sd.id
        title = sd.title
        createdDate = sd.createdDate
        duration = sd.duration
        tracks = sd.tracks.map { CompositionTrack(from: $0) }
    }
}

extension CompositionTrack {
    init(from sd: SDCompositionTrack) {
        id = sd.id
        recordingId = sd.recordingId
        startTime = sd.startTime
        volume = sd.volume
        isMuted = sd.isMuted
        trackColor = sd.trackColor
    }
}
