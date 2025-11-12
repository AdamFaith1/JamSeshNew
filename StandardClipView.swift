//
//  StandardClipView.swift
//  JamSeshNew
//
//  Created by Adam Faith on 2025-11-10.
//

import SwiftUI
import AVFoundation

// MARK: - Standardized Clip Component
struct StandardClipView: View {
    let recording: MTRecording
    let song: MTSong
    let part: MTSongPart
    let isPlaying: Bool
    let size: ClipSize
    let onPlay: () -> Void

    enum ClipSize {
        case compact  // For lists
        case standard // For song view
        case large    // For featured/studio

        var height: CGFloat {
            switch self {
            case .compact: return 90
            case .standard: return 110
            case .large: return 130
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .compact: return 16
            case .standard: return 18
            case .large: return 20
            }
        }
    }

    @State private var waveformLevels: [CGFloat] = []
    @State private var animateWaveform = false

    private var partTypeColor: Color {
        let lowercased = part.name.lowercased()
        if lowercased.contains("intro") || lowercased.contains("outro") { return .purple }
        if lowercased.contains("verse") { return .blue }
        if lowercased.contains("chorus") { return .pink }
        if lowercased.contains("bridge") { return .orange }
        if lowercased.contains("solo") || lowercased.contains("lead") { return .red }
        if lowercased.contains("rhythm") { return .green }
        if lowercased.contains("bass") { return .indigo }
        if lowercased.contains("drum") { return .yellow }
        return .purple
    }

    private var duration: String {
        guard let fileURL = recording.fileURL else { return "--:--" }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(fileURL)

        if let player = try? AVAudioPlayer(contentsOf: url) {
            let minutes = Int(player.duration) / 60
            let seconds = Int(player.duration) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
        return "--:--"
    }

    // Album artwork helpers
    private var artworkImage: UIImage? {
        guard let artworkString = song.artworkURL, !artworkString.isEmpty else { return nil }
        if !artworkString.hasPrefix("http"), let data = Data(base64Encoded: artworkString) {
            return UIImage(data: data)
        }
        return nil
    }

    private var artworkURL: URL? {
        guard let artworkString = song.artworkURL, artworkString.hasPrefix("http") else { return nil }
        return URL(string: artworkString)
    }

    private var albumGradient: LinearGradient {
        let baseColor: Color
        switch song.albumColor {
        case .purple: baseColor = .purple
        case .blue: baseColor = .blue
        case .green: baseColor = .green
        case .orange: baseColor = .orange
        case .fuchsia: baseColor = Color(red: 0.9, green: 0.1, blue: 0.6)
        }

        return LinearGradient(
            colors: [baseColor.opacity(0.8), baseColor.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 0) {
                // Left accent stripe with glow effect
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: size.cornerRadius)
                        .fill(partTypeColor)
                        .frame(width: 5)

                    if isPlaying {
                        RoundedRectangle(cornerRadius: size.cornerRadius)
                            .fill(partTypeColor)
                            .frame(width: 5)
                            .blur(radius: 8)
                            .opacity(0.8)
                    }
                }

                // Main content area
                HStack(spacing: 12) {
                    // Album artwork thumbnail
                    ZStack {
                        albumGradient

                        if let image = artworkImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else if let url = artworkURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Image(systemName: "music.note")
                                .foregroundStyle(.white.opacity(0.5))
                                .font(.system(size: size == .compact ? 20 : 24))
                        }
                    }
                    .frame(
                        width: size == .compact ? 60 : 70,
                        height: size == .compact ? 60 : 70
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(partTypeColor.opacity(0.3), lineWidth: 1.5)
                    )
                    .shadow(color: partTypeColor.opacity(0.3), radius: 6, y: 2)

                    // Info section
                    VStack(alignment: .leading, spacing: 6) {
                        // Part name with badge
                        HStack(spacing: 8) {
                            Text(part.name)
                                .font(size == .compact ? .subheadline : .headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            // Part type badge
                            Text(part.status == .complete ? "✓" : "⏱")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(part.status == .complete ? Color.green.opacity(0.3) : Color.orange.opacity(0.3))
                                )
                        }

                        // Song title and artist
                        if size != .compact {
                            HStack(spacing: 4) {
                                Text(song.title)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .lineLimit(1)

                                Text("•")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.3))

                                Text(song.artist)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .lineLimit(1)
                            }
                        }

                        // Metadata row
                        HStack(spacing: 6) {
                            // Duration
                            HStack(spacing: 3) {
                                Image(systemName: "clock.fill")
                                    .font(.caption2)
                                Text(duration)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(partTypeColor.opacity(0.9))

                            // Loop indicator
                            if recording.isLoop {
                                Text("•")
                                    .foregroundStyle(.white.opacity(0.3))
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.caption2)
                                    Text("Loop")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(.green)
                            }

                            // Note indicator
                            if !recording.note.isEmpty {
                                Text("•")
                                    .foregroundStyle(.white.opacity(0.3))
                                Image(systemName: "note.text")
                                    .font(.caption2)
                                    .foregroundStyle(.blue.opacity(0.8))
                            }

                            Spacer()

                            // Date
                            Text(formatDate(recording.date))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }

                    Spacer()

                    // Play button
                    ZStack {
                        // Glow effect when playing
                        if isPlaying {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [partTypeColor.opacity(0.4), partTypeColor.opacity(0)],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 35
                                    )
                                )
                                .frame(width: 70, height: 70)
                        }

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: isPlaying ?
                                        [partTypeColor, partTypeColor.opacity(0.7)] :
                                        [Color.white.opacity(0.15), Color.white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(
                                width: size == .compact ? 44 : 52,
                                height: size == .compact ? 44 : 52
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(isPlaying ? 0.4 : 0.2),
                                                Color.clear
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(
                                color: isPlaying ? partTypeColor.opacity(0.5) : .black.opacity(0.3),
                                radius: isPlaying ? 8 : 4,
                                y: 2
                            )

                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: size == .compact ? 16 : 20, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: isPlaying ? 0 : 2)
                    }
                    .scaleEffect(isPlaying ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPlaying)
                    .padding(.trailing, 4)
                }
                .padding(.vertical, 12)
                .padding(.leading, 12)
                .padding(.trailing, 8)
            }
            .frame(height: size.height)
            .background(
                ZStack {
                    // Base gradient background
                    RoundedRectangle(cornerRadius: size.cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.1, green: 0.1, blue: 0.15).opacity(0.95),
                                    Color(red: 0.06, green: 0.06, blue: 0.1).opacity(0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Subtle color tint when playing
                    if isPlaying {
                        RoundedRectangle(cornerRadius: size.cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        partTypeColor.opacity(0.08),
                                        partTypeColor.opacity(0.03)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: isPlaying ?
                                [partTypeColor.opacity(0.6), partTypeColor.opacity(0.3)] :
                                [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isPlaying ? 2 : 1
                    )
            )
            .shadow(
                color: isPlaying ? partTypeColor.opacity(0.3) : .black.opacity(0.4),
                radius: isPlaying ? 12 : 8,
                y: 4
            )
        }
        .buttonStyle(ClipButtonStyle())
        .onAppear {
            generateWaveform()
        }
    }
    
    private func waveformHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = size == .compact ? 8 : 12
        let maxHeight: CGFloat = size == .compact ? 24 : 32
        
        // Create a bell curve effect
        let center = 6.0
        let variance = 3.0
        let normalizedIndex = Double(index)
        let bellCurve = exp(-pow(normalizedIndex - center, 2) / (2 * variance))
        
        if isPlaying {
            return baseHeight + (CGFloat(bellCurve) * (maxHeight - baseHeight) * CGFloat.random(in: 0.7...1.0))
        } else {
            return baseHeight + (CGFloat(bellCurve) * (maxHeight - baseHeight) * 0.5)
        }
    }
    
    private func generateWaveform() {
        waveformLevels = (0..<12).map { _ in CGFloat.random(in: 0.3...1.0) }
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Clip Button Style
struct ClipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Compact Song Header
struct CompactSongHeader: View {
    let song: MTSong
    let onBack: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: onBack) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            // Mini album art
            AlbumArtView(song: song, size: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(song.artist)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Stats
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.caption2)
                    Text("\(song.parts.flatMap { $0.recordings }.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.purple)
                
                Text("\(song.parts.count) parts")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding()
        .background(
            Color.black.opacity(0.4)
                .background(.ultraThinMaterial)
        )
    }
}

// MARK: - Part Clips Section
struct PartClipsSection: View {
    let part: MTSongPart
    let clips: [MTRecording]
    let song: MTSong
    let isExpanded: Bool
    @ObservedObject var audioPlaybackManager: AudioPlaybackManager
    let onToggleExpand: () -> Void
    let onDelete: (MTRecording) -> Void
    
    private var mostRecentClip: MTRecording? { clips.first }
    private var olderClips: [MTRecording] { Array(clips.dropFirst()) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Circle()
                    .fill(part.status == .complete ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                
                Text(part.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                if clips.count > 1 {
                    Button(action: onToggleExpand) {
                        HStack(spacing: 4) {
                            Text("\(clips.count - 1) more")
                                .font(.caption)
                                .foregroundStyle(.purple.opacity(0.8))
                            
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                                .foregroundStyle(.purple.opacity(0.8))
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            
            // Most recent clip (always visible)
            if let recent = mostRecentClip {
                StandardClipView(
                    recording: recent,
                    song: song,
                    part: part,
                    isPlaying: audioPlaybackManager.currentlyPlayingId == recent.id && audioPlaybackManager.isPlaying,
                    size: .standard,
                    onPlay: {
                        guard let fileURL = recent.fileURL else { return }
                        audioPlaybackManager.playRecording(id: recent.id, fileURL: fileURL)
                    }
                )
                .contextMenu {
                    Button(role: .destructive) {
                        onDelete(recent)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            
            // Older clips (expanded)
            if isExpanded && !olderClips.isEmpty {
                VStack(spacing: 8) {
                    ForEach(olderClips) { clip in
                        StandardClipView(
                            recording: clip,
                            song: song,
                            part: part,
                            isPlaying: audioPlaybackManager.currentlyPlayingId == clip.id && audioPlaybackManager.isPlaying,
                            size: .compact,
                            onPlay: {
                                guard let fileURL = clip.fileURL else { return }
                                audioPlaybackManager.playRecording(id: clip.id, fileURL: fileURL)
                            }
                        )
                        .contextMenu {
                            Button(role: .destructive) {
                                onDelete(clip)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.leading, 20)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
    }
}

// MARK: - Floating Record Button
struct FloatingRecordButton: View {
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: .purple.opacity(0.4), radius: 12, y: 6)
                
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        } perform: {
            action()
        }
    }
}

// MARK: - Add Part Button
struct AddPartButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Add New Part")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    colors: [.purple.opacity(0.3), .pink.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(ClipButtonStyle())
    }
}

// MARK: - Album Art View Helper
struct AlbumArtView: View {
    let song: MTSong
    let size: CGFloat
    
    private var artworkImage: UIImage? {
        guard let artworkString = song.artworkURL, !artworkString.isEmpty else { return nil }
        if !artworkString.hasPrefix("http"), let data = Data(base64Encoded: artworkString) {
            return UIImage(data: data)
        }
        return nil
    }
    
    private var artworkURL: URL? {
        guard let artworkString = song.artworkURL, artworkString.hasPrefix("http") else { return nil }
        return URL(string: artworkString)
    }
    
    private var albumGradient: LinearGradient {
        let baseColor: Color
        switch song.albumColor {
        case .purple: baseColor = .purple
        case .blue: baseColor = .blue
        case .green: baseColor = .green
        case .orange: baseColor = .orange
        case .fuchsia: baseColor = Color(red: 0.9, green: 0.1, blue: 0.6)
        }
        
        return LinearGradient(
            colors: [baseColor.opacity(0.8), baseColor.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        ZStack {
            albumGradient
            
            if let image = artworkImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = artworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "music.note")
                    .foregroundStyle(.white.opacity(0.6))
                    .font(.system(size: size * 0.4))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
    }
}
