import SwiftUI
import SwiftData
// UNCOMMENT THESE AFTER ADDING FIREBASE PACKAGE IN XCODE:
// import FirebaseCore
// import FirebaseAuth
// import FirebaseFirestore

@main
struct JamSeshApp: App {

    init() {
        // UNCOMMENT THIS AFTER ADDING FIREBASE PACKAGE:
        // FirebaseApp.configure()
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
