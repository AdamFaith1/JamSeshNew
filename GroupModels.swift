//
//  GroupModels.swift
//  Discography
//
//  Created for Groups feature
//

import Foundation
import SwiftUI

// MARK: - Group Model
struct Group: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var coverPhotoURL: String?
    var memberIds: [String]
    var createdById: String
    var createdDate: Date
    var description: String?

    init(id: String = UUID().uuidString,
         name: String,
         coverPhotoURL: String? = nil,
         memberIds: [String] = [],
         createdById: String,
         createdDate: Date = Date(),
         description: String? = nil) {
        self.id = id
        self.name = name
        self.coverPhotoURL = coverPhotoURL
        self.memberIds = memberIds
        self.createdById = createdById
        self.createdDate = createdDate
        self.description = description
    }
}

// MARK: - Group Song Model
struct GroupSong: Identifiable, Codable, Hashable {
    let id: String
    let groupId: String
    var title: String
    var artist: String
    var artworkURL: String?
    var addedById: String
    var addedDate: Date

    // Track which members can play this song
    var memberProgressIds: [String] // IDs of members who have posted progress on this song

    init(id: String = UUID().uuidString,
         groupId: String,
         title: String,
         artist: String,
         artworkURL: String? = nil,
         addedById: String,
         addedDate: Date = Date(),
         memberProgressIds: [String] = []) {
        self.id = id
        self.groupId = groupId
        self.title = title
        self.artist = artist
        self.artworkURL = artworkURL
        self.addedById = addedById
        self.addedDate = addedDate
        self.memberProgressIds = memberProgressIds
    }
}

// MARK: - Group Progress Update Model
struct GroupProgress: Identifiable, Codable, Hashable {
    let id: String
    let groupId: String
    let songId: String // Reference to GroupSong
    var songTitle: String // Denormalized for easy display
    var songArtist: String // Denormalized for easy display
    let postedById: String
    var postedByUsername: String // Denormalized for easy display
    var postedDate: Date
    var progressText: String // e.g., "Learned the chorus!", "Nailed the solo!"
    var videoURL: String? // Optional video recording URL
    var audioURL: String? // Optional audio recording URL
    var reactionCounts: [String: Int] // e.g., ["👍": 5, "🔥": 3, "🎸": 2]

    init(id: String = UUID().uuidString,
         groupId: String,
         songId: String,
         songTitle: String,
         songArtist: String,
         postedById: String,
         postedByUsername: String,
         postedDate: Date = Date(),
         progressText: String,
         videoURL: String? = nil,
         audioURL: String? = nil,
         reactionCounts: [String: Int] = [:]) {
        self.id = id
        self.groupId = groupId
        self.songId = songId
        self.songTitle = songTitle
        self.songArtist = songArtist
        self.postedById = postedById
        self.postedByUsername = postedByUsername
        self.postedDate = postedDate
        self.progressText = progressText
        self.videoURL = videoURL
        self.audioURL = audioURL
        self.reactionCounts = reactionCounts
    }
}

// MARK: - Group Reaction Model
struct GroupReaction: Identifiable, Codable, Hashable {
    let id: String
    let progressId: String // Reference to GroupProgress
    let userId: String
    var emoji: String // e.g., "👍", "🔥", "🎸", "❤️"
    var createdDate: Date

    init(id: String = UUID().uuidString,
         progressId: String,
         userId: String,
         emoji: String,
         createdDate: Date = Date()) {
        self.id = id
        self.progressId = progressId
        self.userId = userId
        self.emoji = emoji
        self.createdDate = createdDate
    }
}

// MARK: - Member Info Helper (for displaying group members)
struct GroupMemberInfo: Identifiable, Hashable {
    let id: String // User ID
    let username: String
    let photoURL: String?
    var songsCanPlay: [String] // Song IDs from group songlist

    init(id: String, username: String, photoURL: String? = nil, songsCanPlay: [String] = []) {
        self.id = id
        self.username = username
        self.photoURL = photoURL
        self.songsCanPlay = songsCanPlay
    }
}

// MARK: - Jam List Item (for songs everyone can play)
struct JamListSong: Identifiable, Hashable {
    let id: String // Song ID
    let title: String
    let artist: String
    let artworkURL: String?
    var memberCount: Int // Number of members who can play this

    init(id: String, title: String, artist: String, artworkURL: String? = nil, memberCount: Int = 0) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artworkURL = artworkURL
        self.memberCount = memberCount
    }
}
