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
class FirebaseService: ObservableObject {
    static let shared = FirebaseService()

  
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    @Published var currentUser: String? = nil
    @Published var isAuthenticated = false

    private init() {
        // Check for existing user session
        checkAuthStatus()
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
    }

    // MARK: - Firestore Database

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
      
        let storageRef = storage.reference().child(path)
        try await storageRef.delete()
    }
}

// MARK: - Example Usage

/*

 // Using FirebaseService in your views:

 struct ExampleView: View {
     @StateObject private var firebaseService = FirebaseService.shared

     var body: some View {
         if firebaseService.isAuthenticated {
             Text("Logged in as: \(firebaseService.currentUser ?? "Unknown")")
         } else {
             Button("Sign In") {
                 Task {
                     try await firebaseService.signIn(email: "user@example.com", password: "password")
                 }
             }
         }
     }
 }

 // Saving data:
 try await FirebaseService.shared.saveData(
     collection: "songs",
     documentId: "song123",
     data: mySongObject
 )

 // Loading data:
 let song: Song = try await FirebaseService.shared.getData(
     collection: "songs",
     documentId: "song123"
 )

 // Uploading a file:
 let audioData = try Data(contentsOf: audioFileURL)
 let downloadURL = try await FirebaseService.shared.uploadFile(
     path: "recordings/\(UUID().uuidString).m4a",
     data: audioData
 )

 */
