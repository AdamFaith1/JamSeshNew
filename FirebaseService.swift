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
            self.currentUser = user.uid
            self.isAuthenticated = true
        }
    }
    
    func signIn(email: String, password: String) async throws {
        
        let result = try await auth.signIn(withEmail: email, password: password)
        await MainActor.run {
            self.currentUser = result.user.uid
            self.isAuthenticated = true
        }
    }
    
    func signUp(email: String, password: String) async throws {
        
        let result = try await auth.createUser(withEmail: email, password: password)
        await MainActor.run {
            self.currentUser = result.user.uid
            self.isAuthenticated = true
        }
    }
    
    func signOut() throws {
        
        try auth.signOut()
        self.currentUser = nil
        self.isAuthenticated = false
        
        if let user = auth.currentUser {
            self.currentUser = user
            self.isAuthenticated = true
            Task {
                try? await loadUserProfile(userId: user.uid)
            }
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
        
        
        func saveData<T: Encodable>(collection: String, documentId: String, data: T) async throws {
            
            try db.collection(collection).document(documentId).setData(from: data)
        }
        
        func getData<T: Decodable>(collection: String, documentId: String) async throws -> T {
            let document = try await db.collection(collection).document(documentId).getDocument()
            return try document.data(as: T.self)
            throw NSError(domain: "FirebaseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Firebase not configured"])
        }
        
        func deleteData(collection: String, documentId: String) async throws {
            
            try await db.collection(collection).document(documentId).delete()
            
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
            throw NSError(domain: "FirebaseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Firebase not configured"])
        }
        
        func downloadFile(path: String) async throws -> Data {
            
            let storageRef = storage.reference().child(path)
            return try await storageRef.data(maxSize: 50 * 1024 * 1024) // 50MB max
            throw NSError(domain: "FirebaseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Firebase not configured"])
        }
        
        func deleteFile(path: String) async throws {
            
            
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
        }
        
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
    }
}
