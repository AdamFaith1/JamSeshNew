import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

@main
struct JamSeshApp: App {

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ModernTile()
        }
        // Provides the SwiftData ModelContext to the entire scene
        .modelContainer(for: [
            SDSong.self,
            SDSongPart.self,
            SDRecording.self,
            SDLoop.self,
            SDComposition.self,
            SDCompositionTrack.self

        ])
    }
}
