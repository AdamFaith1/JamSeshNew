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
            case .compact: return 60
            case .standard: return 80
            case .large: return 100
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .compact: return 12
            case .standard: return 14
            case .large: return 16
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
    
    var body: some View {
        Button(action: onPlay) {
            ZStack {
                // Main clip body with gradient
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.08, green: 0.08, blue: 0.12),
                                Color(red: 0.05, green: 0.05, blue: 0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        // Subtle inner shadow for depth
                        RoundedRectangle(cornerRadius: size.cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                ),
                                lineWidth: 1
                            )
                    )
                
                HStack(spacing: 0) {
                    // Left side - Part type color bar
                    RoundedRectangle(cornerRadius: size.cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    partTypeColor,
                                    partTypeColor.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 6)
                        .padding(4)
                    
                    // Play button circle
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: isPlaying ?
                                        [partTypeColor, partTypeColor.opacity(0.6)] :
                                        [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: size == .compact ? 36 : 44, height: size == .compact ? 36 : 44)
                        
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: size == .compact ? 14 : 18, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: isPlaying ? 0 : 1)
                    }
                    .padding(.leading, 8)
                    
                    // Waveform visualization
                    HStack(spacing: 2) {
                        ForEach(0..<12, id: \.self) { index in
                            Capsule()
                                .fill(
                                    isPlaying ?
                                        LinearGradient(
                                            colors: [partTypeColor, partTypeColor.opacity(0.5)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ) :
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                )
                                .frame(width: 3, height: waveformHeight(for: index))
                                .animation(
                                    isPlaying ?
                                        .easeInOut(duration: 0.3)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.05) :
                                        .default,
                                    value: isPlaying
                                )
                        }
                    }
                    .frame(width: 60)
                    .padding(.horizontal, 12)
                    
                    // Clip info
                    VStack(alignment: .leading, spacing: size == .compact ? 2 : 4) {
                        Text(part.name)
                            .font(size == .compact ? .caption : .subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        HStack(spacing: 4) {
                            Text(duration)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                            
                            if recording.isLoop {
                                Text("•")
                                    .foregroundStyle(.white.opacity(0.3))
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                            
                            if !recording.note.isEmpty {
                                Text("•")
                                    .foregroundStyle(.white.opacity(0.3))
                                Image(systemName: "note.text")
                                    .font(.caption2)
                                    .foregroundStyle(.blue.opacity(0.7))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Recording date
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatDate(recording.date))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                        
                        if size != .compact {
                            Text(formatTime(recording.date))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.3))
                        }
                    }
                    .padding(.trailing, 12)
                }
            }
            .frame(height: size.height)
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            .overlay(
                // Playing indicator overlay
                Group {
                    if isPlaying {
                        RoundedRectangle(cornerRadius: size.cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        partTypeColor.opacity(0.6),
                                        partTypeColor.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .shadow(color: partTypeColor.opacity(0.5), radius: 4)
                    }
                }
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
