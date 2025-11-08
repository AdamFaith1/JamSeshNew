import SwiftUI
import SwiftData

@main
struct JamSeshApp: App {
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
