import SwiftUI

public struct AddSongSheet: View {
    @ObservedObject var viewModel: MusicViewModel
    let onSongSelected: (MTSong) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        NavigationStack {
            List(viewModel.songs, id: \.id) { song in
                Button {
                    onSongSelected(song)
                    dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(song.title)
                            .font(.body)
                        Text(song.artist)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Plug in a Song")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
