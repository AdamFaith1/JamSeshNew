import SwiftUI

struct ClipsListView: View {
    @ObservedObject var viewModel: MusicViewModel

    var body: some View {
        ZStack {
            // Transparent background to blend with parent gradient
            Color.clear.ignoresSafeArea()

            if viewModel.allClips.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("No clips yet")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Record parts to see them here as clips")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding()
            } else {
                List(viewModel.allClips) { item in
                    ClipRow(item: item)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

private struct ClipRow: View {
    let item: ClipItem

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: item.recording.date)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.6), .pink.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                Image(systemName: "music.note")
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.song.title)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.part.name)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("•")
                        .foregroundStyle(.white.opacity(0.3))
                    Text(dateString)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    // Minimal preview with empty view model to verify build
    let vm = MusicViewModel()
    return ClipsListView(viewModel: vm)
        .background(
            LinearGradient(colors: [Color(red:0.02, green:0.04, blue:0.07),
                                    Color(red:0.15, green:0.02, blue:0.2),
                                    Color(red:0.02, green:0.04, blue:0.07)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
}
