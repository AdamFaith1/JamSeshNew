//
//  FirebaseService.swift
//  JamSeshNew
//
//  Created by Adam Faith on 2025-12-08.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

internal import Combine

// MARK: - Data Models

struct UserProfile: Codable, Identifiable {
    let id: String
    var username: String
    var email: String
    var displayName: String
    var photoURL: String?
    var bio: String?
    var createdAt: Date
    var friendIds: [String]
    var publicRecordingIds: [String]
}

struct PublicRecording: Codable, Identifiable {
    let id: String
    let userId: String
    var username: String
    var songTitle: String
    var artistName: String
    var partName: String
    var audioURL: String
    var duration: TimeInterval
    var createdAt: Date
    var likes: Int
    var likedByUserIds: [String]

    init(id: String = UUID().uuidString,
         userId: String,
         username: String,
         songTitle: String,
         artistName: String,
         partName: String,
         audioURL: String,
         duration: TimeInterval,
         createdAt: Date = Date(),
         likes: Int = 0,
         likedByUserIds: [String] = []) {
        self.id = id
        self.userId = userId
        self.username = username
        self.songTitle = songTitle
        self.artistName = artistName
        self.partName = partName
        self.audioURL = audioURL
        self.duration = duration
        self.createdAt = createdAt
        self.likes = likes
        self.likedByUserIds = likedByUserIds
    }
}

/// Firebase service manager for handling authentication, database, and storage operations
@MainActor
class FirebaseService: ObservableObject {
    static let shared = FirebaseService()

    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    @Published var currentUser: FirebaseAuth.User? = nil
    @Published var isAuthenticated = false
    @Published var currentUserProfile: UserProfile? = nil

    private init() {
        // Check for existing user session
        checkAuthStatus()

        // Listen for auth state changes
        auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                if let user = user {
                    try? await self?.loadUserProfile(userId: user.uid)
                } else {
                    self?.currentUserProfile = nil
                }
            }
        }
    }

    // MARK: - Authentication

    func checkAuthStatus() {
        if let user = auth.currentUser {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }

    func signIn(email: String, password: String) async throws {
        let result = try await auth.signIn(withEmail: email, password: password)
        self.currentUser = result.user
        self.isAuthenticated = true
        try await loadUserProfile(userId: result.user.uid)
    }

    func signUp(email: String, password: String, username: String) async throws {
        let result = try await auth.createUser(withEmail: email, password: password)
        self.currentUser = result.user
        self.isAuthenticated = true

        // Create user profile in Firestore
        let profile = UserProfile(
            id: result.user.uid,
            username: username,
            email: email,
            displayName: username,
            photoURL: nil,
            bio: nil,
            createdAt: Date(),
            friendIds: [],
            publicRecordingIds: []
        )

        try await saveUserProfile(profile)
        self.currentUserProfile = profile
    }

    func signOut() throws {
        try auth.signOut()
        self.currentUser = nil
        self.isAuthenticated = false
        self.currentUserProfile = nil
    }

    // MARK: - User Profile

    func saveUserProfile(_ profile: UserProfile) async throws {
        try db.collection("users").document(profile.id).setData(from: profile)
    }

    func loadUserProfile(userId: String) async throws {
        let document = try await db.collection("users").document(userId).getDocument()
        self.currentUserProfile = try document.data(as: UserProfile.self)
    }

    func updateUserProfile(userId: String, updates: [String: Any]) async throws {
        try await db.collection("users").document(userId).updateData(updates)
        try await loadUserProfile(userId: userId)
    }

    func searchUsers(query: String) async throws -> [UserProfile] {
        let snapshot = try await db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: query)
            .whereField("username", isLessThan: query + "z")
            .limit(to: 20)
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: UserProfile.self) }
    }

    // MARK: - Friends

    func addFriend(friendId: String) async throws {
        guard let userId = currentUser?.uid else { return }

        try await db.collection("users").document(userId).updateData([
            "friendIds": FieldValue.arrayUnion([friendId])
        ])

        try await loadUserProfile(userId: userId)
    }

    func removeFriend(friendId: String) async throws {
        guard let userId = currentUser?.uid else { return }

        try await db.collection("users").document(userId).updateData([
            "friendIds": FieldValue.arrayRemove([friendId])
        ])

        try await loadUserProfile(userId: userId)
    }

    func getFriends(userId: String) async throws -> [UserProfile] {
        let userDoc = try await db.collection("users").document(userId).getDocument()
        let user = try userDoc.data(as: UserProfile.self)

        guard !user.friendIds.isEmpty else { return [] }

        let friendsSnapshot = try await db.collection("users")
            .whereField(FieldPath.documentID(), in: user.friendIds)
            .getDocuments()

        return try friendsSnapshot.documents.compactMap { try $0.data(as: UserProfile.self) }
    }

    // MARK: - Public Recordings

    func savePublicRecording(_ recording: PublicRecording) async throws {
        try db.collection("publicRecordings").document(recording.id).setData(from: recording)

        // Update user's public recording list
        guard let userId = currentUser?.uid else { return }
        try await db.collection("users").document(userId).updateData([
            "publicRecordingIds": FieldValue.arrayUnion([recording.id])
        ])
    }

    func loadPublicRecording(recordingId: String) async throws -> PublicRecording {
        let document = try await db.collection("publicRecordings").document(recordingId).getDocument()
        return try document.data(as: PublicRecording.self)
    }

    func getFriendsRecordings() async throws -> [PublicRecording] {
        guard let userId = currentUser?.uid,
              let friendIds = currentUserProfile?.friendIds,
              !friendIds.isEmpty else { return [] }

        let snapshot = try await db.collection("publicRecordings")
            .whereField("userId", in: friendIds)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: PublicRecording.self) }
    }

    func getUserRecordings(userId: String) async throws -> [PublicRecording] {
        let snapshot = try await db.collection("publicRecordings")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: PublicRecording.self) }
    }

    func deletePublicRecording(recordingId: String) async throws {
        guard let userId = currentUser?.uid else { return }

        try await db.collection("publicRecordings").document(recordingId).delete()

        try await db.collection("users").document(userId).updateData([
            "publicRecordingIds": FieldValue.arrayRemove([recordingId])
        ])
    }

    // MARK: - Storage

    func uploadFile(path: String, data: Data) async throws -> URL {
        let storageRef = storage.reference().child(path)
        _ = try await storageRef.putDataAsync(data)
        return try await storageRef.downloadURL()
    }

    func downloadFile(path: String) async throws -> Data {
        let storageRef = storage.reference().child(path)
        return try await storageRef.data(maxSize: 50 * 1024 * 1024) // 50MB max
    }

    func deleteFile(path: String) async throws {
        let storageRef = storage.reference().child(path)
        try await storageRef.delete()
    }

    func uploadAudioFile(recordingId: String, data: Data) async throws -> URL {
        let path = "recordings/\(recordingId).m4a"
        let storageRef = storage.reference().child(path)
        _ = try await storageRef.putDataAsync(data)
        return try await storageRef.downloadURL()
    }

    func downloadAudioFile(url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }

    func deleteAudioFile(path: String) async throws {
        let storageRef = storage.reference().child(path)
        try await storageRef.delete()
    }

    // MARK: - Data Operations

    func saveData<T: Encodable>(collection: String, documentId: String, data: T) async throws {
        try db.collection(collection).document(documentId).setData(from: data)
    }

    func getData<T: Decodable>(collection: String, documentId: String) async throws -> T {
        let document = try await db.collection(collection).document(documentId).getDocument()
        return try document.data(as: T.self)
    }

    func deleteData(collection: String, documentId: String) async throws {
        try await db.collection(collection).document(documentId).delete()
    }

    // MARK: - Groups Management

    /// Create a new group
    func createGroup(_ group: Group) async throws {
        try db.collection("groups").document(group.id).setData(from: group)
    }

    /// Update an existing group
    func updateGroup(_ group: Group) async throws {
        try db.collection("groups").document(group.id).setData(from: group)
    }

    /// Delete a group and all its related data
    func deleteGroup(groupId: String) async throws {
        // Delete all group songs
        let songsSnapshot = try await db.collection("groupSongs")
            .whereField("groupId", isEqualTo: groupId)
            .getDocuments()

        for doc in songsSnapshot.documents {
            try await doc.reference.delete()
        }

        // Delete all progress updates
        let progressSnapshot = try await db.collection("groupProgress")
            .whereField("groupId", isEqualTo: groupId)
            .getDocuments()

        for doc in progressSnapshot.documents {
            try await doc.reference.delete()
        }

        // Delete the group itself
        try await db.collection("groups").document(groupId).delete()
    }

    /// Get all groups for the current user
    func getUserGroups() async throws -> [Group] {
        guard let userId = currentUser?.uid else { return [] }

        let snapshot = try await db.collection("groups")
            .whereField("memberIds", arrayContains: userId)
            .order(by: "createdDate", descending: true)
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: Group.self) }
    }

    /// Get a specific group by ID
    func getGroup(groupId: String) async throws -> Group {
        let document = try await db.collection("groups").document(groupId).getDocument()
        return try document.data(as: Group.self)
    }

    /// Add a member to a group
    func addGroupMember(groupId: String, userId: String) async throws {
        try await db.collection("groups").document(groupId).updateData([
            "memberIds": FieldValue.arrayUnion([userId])
        ])
    }

    /// Remove a member from a group
    func removeGroupMember(groupId: String, userId: String) async throws {
        try await db.collection("groups").document(groupId).updateData([
            "memberIds": FieldValue.arrayRemove([userId])
        ])
    }

    /// Get profiles for all members of a group
    func getGroupMembers(group: Group) async throws -> [UserProfile] {
        guard !group.memberIds.isEmpty else { return [] }

        let snapshot = try await db.collection("users")
            .whereField(FieldPath.documentID(), in: group.memberIds)
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: UserProfile.self) }
    }

    /// Upload group cover photo
    func uploadGroupCoverPhoto(groupId: String, imageData: Data) async throws -> URL {
        let path = "groups/\(groupId)/cover.jpg"
        return try await uploadFile(path: path, data: imageData)
    }

    // MARK: - Group Songs

    /// Add a song to a group's shared songlist
    func addSongToGroup(_ song: GroupSong) async throws {
        try db.collection("groupSongs").document(song.id).setData(from: song)
    }

    /// Remove a song from a group's songlist
    func removeSongFromGroup(songId: String) async throws {
        try await db.collection("groupSongs").document(songId).delete()
    }

    /// Get all songs in a group's songlist
    func getGroupSongs(groupId: String) async throws -> [GroupSong] {
        let snapshot = try await db.collection("groupSongs")
            .whereField("groupId", isEqualTo: groupId)
            .order(by: "addedDate", descending: true)
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: GroupSong.self) }
    }

    /// Update member progress IDs for a song
    func updateSongMemberProgress(songId: String, userId: String) async throws {
        try await db.collection("groupSongs").document(songId).updateData([
            "memberProgressIds": FieldValue.arrayUnion([userId])
        ])
    }

    // MARK: - Group Progress Updates

    /// Post a progress update to a group
    func addProgressUpdate(_ progress: GroupProgress) async throws {
        try db.collection("groupProgress").document(progress.id).setData(from: progress)

        // Update the song's member progress list
        try await updateSongMemberProgress(songId: progress.songId, userId: progress.postedById)
    }

    /// Delete a progress update
    func deleteProgressUpdate(progressId: String) async throws {
        try await db.collection("groupProgress").document(progressId).delete()
    }

    /// Get all progress updates for a group
    func getGroupProgress(groupId: String) async throws -> [GroupProgress] {
        let snapshot = try await db.collection("groupProgress")
            .whereField("groupId", isEqualTo: groupId)
            .order(by: "postedDate", descending: true)
            .limit(to: 100)
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: GroupProgress.self) }
    }

    /// Get progress updates for a specific song in a group
    func getSongProgress(groupId: String, songId: String) async throws -> [GroupProgress] {
        let snapshot = try await db.collection("groupProgress")
            .whereField("groupId", isEqualTo: groupId)
            .whereField("songId", isEqualTo: songId)
            .order(by: "postedDate", descending: true)
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: GroupProgress.self) }
    }

    /// Upload progress video or audio
    func uploadProgressMedia(progressId: String, data: Data, isVideo: Bool) async throws -> URL {
        let ext = isVideo ? "mp4" : "m4a"
        let path = "groupProgress/\(progressId).\(ext)"
        return try await uploadFile(path: path, data: data)
    }

    // MARK: - Group Reactions

    /// Add a reaction to a progress update
    func addReaction(_ reaction: GroupReaction) async throws {
        // Save the reaction document
        try db.collection("groupReactions").document(reaction.id).setData(from: reaction)

        // Update the progress update's reaction counts
        let progressRef = db.collection("groupProgress").document(reaction.progressId)
        let progressDoc = try await progressRef.getDocument()

        if var progress = try? progressDoc.data(as: GroupProgress.self) {
            progress.reactionCounts[reaction.emoji, default: 0] += 1
            try progressRef.setData(from: progress)
        }
    }

    /// Remove a reaction from a progress update
    func removeReaction(_ reaction: GroupReaction) async throws {
        // Delete the reaction document
        try await db.collection("groupReactions").document(reaction.id).delete()

        // Update the progress update's reaction counts
        let progressRef = db.collection("groupProgress").document(reaction.progressId)
        let progressDoc = try await progressRef.getDocument()

        if var progress = try? progressDoc.data(as: GroupProgress.self) {
            if let count = progress.reactionCounts[reaction.emoji], count > 0 {
                progress.reactionCounts[reaction.emoji] = count - 1
                if progress.reactionCounts[reaction.emoji] == 0 {
                    progress.reactionCounts.removeValue(forKey: reaction.emoji)
                }
                try progressRef.setData(from: progress)
            }
        }
    }

    /// Get all reactions for a progress update
    func getReactions(progressId: String) async throws -> [GroupReaction] {
        let snapshot = try await db.collection("groupReactions")
            .whereField("progressId", isEqualTo: progressId)
            .order(by: "createdDate", descending: true)
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: GroupReaction.self) }
    }

    /// Check if current user has reacted with a specific emoji
    func hasUserReacted(progressId: String, emoji: String) async throws -> GroupReaction? {
        guard let userId = currentUser?.uid else { return nil }

        let snapshot = try await db.collection("groupReactions")
            .whereField("progressId", isEqualTo: progressId)
            .whereField("userId", isEqualTo: userId)
            .whereField("emoji", isEqualTo: emoji)
            .limit(to: 1)
            .getDocuments()

        return try snapshot.documents.first.flatMap { try $0.data(as: GroupReaction.self) }
    }
}
