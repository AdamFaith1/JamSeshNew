//
//  CollectionViews.swift
//  Discography
//
//  Created by Adam Faith on 2025-10-27.
//

import SwiftUI
import SwiftData
import AVFoundation

// MARK: - Songs Grid View
struct SongsGridView: View {
    @ObservedObject var viewModel: MusicViewModel
    @Binding var showingDeleteConfirmation: Bool
    @Binding var songToDelete: MTSong?
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar (always visible in collection view)
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.purple.opacity(0.6))
                TextField("Search your collection...", text: $viewModel.searchQuery)
                    .foregroundStyle(.white)
                
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.purple.opacity(0.3)))
            .cornerRadius(16)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Content area - Grid or Empty State
            if viewModel.filteredSongs.isEmpty {
                // Show empty state but keep search bar
                CollectionSearchEmptyStateView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Grid
                ScrollView {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: 16, alignment: .top),
                            count: viewModel.gridColumns
                        ),
                        spacing: 16
                    ) {
                        ForEach(viewModel.filteredSongs) { song in
                            AlbumTileCell(song: song, gridColumns: viewModel.gridColumns)
                                .overlay(selectionOverlay(for: song))
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        viewModel.selectedSongId = song.id
                                    }
                                }
                                .contextMenu {
                                    // View Details (opens the song)
                                    Button {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            viewModel.selectedSongId = song.id
                                        }
                                    } label: {
                                        Label("View Details", systemImage: "music.note.list")
                                    }
                                    
                                    // Add Part
                                    Button {
                                        // TODO: Wire up to add part sheet
                                        // For now, just opens the song detail where they can add parts
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            viewModel.selectedSongId = song.id
                                        }
                                    } label: {
                                        Label("Add Part", systemImage: "plus.circle")
                                    }
                                    
                                    Divider()
                                    
                                    // Share Song Info
                                    Button {
                                        let shareText = "\(song.title) by \(song.artist) - \(song.parts.count) parts learned"
                                        let activityVC = UIActivityViewController(
                                            activityItems: [shareText],
                                            applicationActivities: nil
                                        )
                                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                           let window = windowScene.windows.first,
                                           let rootVC = window.rootViewController {
                                            rootVC.present(activityVC, animated: true)
                                        }
                                    } label: {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                    }
                                    
                                    Divider()
                                    
                                    // Delete
                                    Button(role: .destructive) {
                                        songToDelete = song
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, 100) // Extra space for bottom tab bar
                }
            }
        }
    }
    
    @ViewBuilder
    private func selectionOverlay(for song: MTSong) -> some View {
        if viewModel.selectedSongId == song.id {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.8), lineWidth: 3)
                .shadow(color: Color.white.opacity(0.4), radius: 6, x: 0, y: 0)
                .animation(.easeInOut, value: viewModel.selectedSongId)
        } else {
            EmptyView()
        }
    }
}
// MARK: - Album Tile Cell (Enhanced with clip indicators)
struct AlbumTileCell: View {
    let song: MTSong
    let gridColumns: Int
    
    // Generate a subtle random tilt for each tile based on song ID
    private var tiltAngle: Double {
        let angles: [Double] = [1.5, -1.5, 2.0, -2.0, 0.5, -0.5, 1.0, -1.0]
        let index = abs(song.id.hashValue) % angles.count
        return angles[index]
    }
    
    // Responsive sizing based on grid columns
    private var artworkHeight: CGFloat {
        gridColumns == 3 ? 100 : 160
    }
    
    private var fontSize: Font {
        gridColumns == 3 ? .subheadline : .headline
    }
    
    // Progress calculations
    private var totalRecordings: Int {
        song.parts.flatMap { $0.recordings }.count
    }
    
    private var totalParts: Int {
        song.parts.count
    }
    
    private var learningCount: Int {
        song.parts.filter { $0.status == .learning }.count
    }
    
    private var completeCount: Int {
        song.parts.filter { $0.status == .complete }.count
    }
    
    private var gradientColors: [Color] {
        let baseColor: Color
        switch song.albumColor {
        case .purple:
            baseColor = .purple
        case .blue:
            baseColor = .blue
        case .green:
            baseColor = .green
        case .orange:
            baseColor = .orange
        case .fuchsia:
            baseColor = Color(red: 0.9, green: 0.1, blue: 0.6)
        }
        
        return [
            baseColor.opacity(0.85),
            baseColor.opacity(0.6),
            baseColor.opacity(0.4)
        ]
    }
    
    private var isCompleted: Bool {
        song.isFullyLearned
    }
    
    // Helper to get artwork image from base64 or URL
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
    
    // Part type colors for indicators
    private func colorForPartType(_ partName: String) -> Color {
        let lowercased = partName.lowercased()
        if lowercased.contains("bass") { return .blue }
        if lowercased.contains("lead") || lowercased.contains("solo") { return .pink }
        if lowercased.contains("rhythm") || lowercased.contains("chord") { return .orange }
        if lowercased.contains("vocal") { return .purple }
        if lowercased.contains("drum") { return .red }
        return .green
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: gridColumns == 3 ? 6 : 8) {
            // Album artwork with clip indicators
            ZStack(alignment: .bottom) {
                // Main artwork
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: gradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    if let image = artworkImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .clipped()
                    } else if let url = artworkURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                            default:
                                EmptyView()
                            }
                        }
                    }
                }
                .frame(height: artworkHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [.purple.opacity(0.3), .pink.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                
                // Clip indicators at bottom
                if totalRecordings > 0 {
                    HStack(spacing: 2) {
                        // Show up to 5 part type indicators as colored dots
                        ForEach(Array(song.parts.prefix(5)), id: \.id) { part in
                            if !part.recordings.isEmpty {
                                Circle()
                                    .fill(colorForPartType(part.name))
                                    .frame(width: gridColumns == 3 ? 5 : 6, height: gridColumns == 3 ? 5 : 6)
                            }
                        }
                        
                        // Show total clip count
                        Text("\(totalRecordings)")
                            .font(.system(size: gridColumns == 3 ? 9 : 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.6))
                            .blur(radius: 2)
                    )
                    .padding(.bottom, 6)
                }
            }
            
            // Song info
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(song.title)
                    .font(fontSize)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Artist name with indicators on the right
                HStack(alignment: .bottom) {
                    Text(song.artist)
                        .font(gridColumns == 3 ? .caption : .subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Part count indicators in bottom-right
                    if totalParts > 0 {
                        HStack(spacing: 4) {
                            // Learning parts (yellow)
                            if learningCount > 0 {
                                HStack(spacing: 2) {
                                    Circle()
                                        .fill(Color.yellow)
                                        .frame(width: gridColumns == 3 ? 6 : 7, height: gridColumns == 3 ? 6 : 7)
                                    Text("\(learningCount)")
                                        .font(gridColumns == 3 ? .caption2 : .caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.yellow)
                                }
                            }
                            
                            // Complete parts (green)
                            if completeCount > 0 {
                                HStack(spacing: 2) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: gridColumns == 3 ? 6 : 7, height: gridColumns == 3 ? 6 : 7)
                                    Text("\(completeCount)")
                                        .font(gridColumns == 3 ? .caption2 : .caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.3))
                        )
                    }
                    
                    // Completion seal if fully learned
                    if isCompleted {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .imageScale(gridColumns == 3 ? .small : .medium)
                    }
                }
            }
        }
        .padding(gridColumns == 3 ? 8 : 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.2), .pink.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        .rotationEffect(.degrees(tiltAngle))
    }
}
// MARK: - Clips List View (for Collection tab)
struct ClipsListView: View {
    @ObservedObject var viewModel: MusicViewModel
    @StateObject private var audioPlaybackManager = AudioPlaybackManager()
    @State private var selectedClip: ClipItem?
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.purple.opacity(0.6))
                TextField("Search clips...", text: $viewModel.searchQuery)
                    .foregroundStyle(.white)
                
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.purple.opacity(0.3)))
            .cornerRadius(16)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Clips list or empty state
            if viewModel.allClips.isEmpty {
                ClipsEmptyStateView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.allClips) { clip in
                            StandardClipView(
                                recording: clip.recording,
                                song: clip.song,
                                part: clip.part,
                                isPlaying: audioPlaybackManager.currentlyPlayingId == clip.recording.id && audioPlaybackManager.isPlaying,
                                size: .standard,
                                onPlay: {
                                    guard let fileURL = clip.recording.fileURL else { return }
                                    audioPlaybackManager.playRecording(id: clip.recording.id, fileURL: fileURL)
                                }
                            )
                            .contextMenu {
                                Button {
                                    selectedClip = clip
                                } label: {
                                    Label("View Details", systemImage: "info.circle")
                                }
                                
                                Button {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        viewModel.selectedSongId = clip.song.id
                                    }
                                } label: {
                                    Label("View Song", systemImage: "music.note.list")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(item: $selectedClip) { clip in
            ClipDetailSheet(clip: clip, viewModel: viewModel, audioPlaybackManager: audioPlaybackManager)
        }
    }
}

// MARK: - Clip Card
struct ClipCard: View {
    let clip: ClipItem
    let isPlaying: Bool
    let onTap: () -> Void
    let onPlay: () -> Void
    let audioPlaybackManager: AudioPlaybackManager
    
    private var artworkImage: UIImage? {
        guard let artworkString = clip.song.artworkURL, !artworkString.isEmpty else { return nil }
        if !artworkString.hasPrefix("http"), let data = Data(base64Encoded: artworkString) {
            return UIImage(data: data)
        }
        return nil
    }
    
    private var artworkURL: URL? {
        guard let artworkString = clip.song.artworkURL, artworkString.hasPrefix("http") else { return nil }
        return URL(string: artworkString)
    }
    
    private var albumGradient: LinearGradient {
        let baseColor: Color
        switch clip.song.albumColor {
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
    
    private var duration: String {
        guard let fileURL = clip.recording.fileURL,
              let dur = audioPlaybackManager.getRecordingDuration(filename: fileURL) else {
            return "--:--"
        }
        return audioPlaybackManager.formatTime(dur)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Play button
                Button(action: onPlay) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: isPlaying ? 0 : 2)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Album artwork
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
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Clip info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(clip.song.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        Text("•")
                            .foregroundStyle(.white.opacity(0.3))
                        
                        Text(clip.part.name)
                            .font(.subheadline)
                            .foregroundStyle(.purple.opacity(0.9))
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 8) {
                        Text(clip.song.artist)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.3))
                        
                        Text(formatDate(clip.recording.date))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.3))
                        
                        Text(duration)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    colors: [.purple.opacity(0.2), .pink.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
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
}

// MARK: - Clip Detail Sheet
struct ClipDetailSheet: View {
    let clip: ClipItem
    @ObservedObject var viewModel: MusicViewModel
    @ObservedObject var audioPlaybackManager: AudioPlaybackManager
    @Environment(\.dismiss) private var dismiss
    
    private var isPlaying: Bool {
        audioPlaybackManager.currentlyPlayingId == clip.recording.id && audioPlaybackManager.isPlaying
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.02, green: 0.04, blue: 0.07)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Play button
                    Button {
                        guard let fileURL = clip.recording.fileURL else { return }
                        audioPlaybackManager.playRecording(id: clip.recording.id, fileURL: fileURL)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                                .offset(x: isPlaying ? 0 : 3)
                        }
                    }
                    
                    // Clip details
                    VStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Text(clip.song.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            
                            Text(clip.song.artist)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                            
                            Text(clip.part.name)
                                .font(.caption)
                                .foregroundStyle(.purple)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(.purple.opacity(0.2))
                                )
                        }
                        
                        // Notes if available
                        if !clip.recording.note.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white.opacity(0.7))
                                
                                Text(clip.recording.note)
                                    .font(.body)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.05))
                            )
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Actions
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            viewModel.selectedSongId = clip.song.id
                            dismiss()
                        }
                    } label: {
                        Text("View Song")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Clip Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.purple)
                }
            }
        }
    }
}

// MARK: - Clips Empty State
struct ClipsEmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundColor(.purple.opacity(0.7))
            
            Text("No Clips Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Record your first musical part to create a clip. Clips are reusable building blocks for your music.")
                .font(.body)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(32)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundColor(.purple.opacity(0.7))
            Text("No Songs Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text("Get started by adding your first song to your library. Tap the record button to start learning!")
                .font(.body)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.purple.opacity(0.25))
                .blur(radius: 6)
        )
        .padding()
    }
}

// MARK: - Sort Bubble Content
struct SortBubbleContent: View {
    @ObservedObject var viewModel: MusicViewModel
    let dismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Title A-Z
            SortOptionButton(
                title: "Title A-Z",
                isSelected: viewModel.sortOption == .titleAsc,
                action: {
                    viewModel.sortOption = .titleAsc
                    dismiss()
                }
            )
            
            // Title Z-A
            SortOptionButton(
                title: "Title Z-A",
                isSelected: viewModel.sortOption == .titleDesc,
                action: {
                    viewModel.sortOption = .titleDesc
                    dismiss()
                }
            )
            
            // Artist A-Z
            SortOptionButton(
                title: "Artist A-Z",
                isSelected: viewModel.sortOption == .artistAsc,
                action: {
                    viewModel.sortOption = .artistAsc
                    dismiss()
                }
            )
            
            // Artist Z-A
            SortOptionButton(
                title: "Artist Z-A",
                isSelected: viewModel.sortOption == .artistDesc,
                action: {
                    viewModel.sortOption = .artistDesc
                    dismiss()
                }
            )
            
            // Date Added
            SortOptionButton(
                title: "Date Added",
                isSelected: viewModel.sortOption == .dateAdded,
                action: {
                    viewModel.sortOption = .dateAdded
                    dismiss()
                }
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.purple.opacity(0.85))
                .shadow(color: Color.pink.opacity(0.6), radius: 8, x: 0, y: 4)
        )
        .frame(maxWidth: 300)
    }
}

// MARK: - Sort Option Button
private struct SortOptionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected
                        ? AnyShapeStyle(LinearGradient(
                            gradient: Gradient(colors: [Color.pink.opacity(0.9), Color.purple.opacity(0.9)]),
                            startPoint: .leading,
                            endPoint: .trailing
                          ))
                        : AnyShapeStyle(Color.purple.opacity(0.4))
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Collection Search Empty State View
struct CollectionSearchEmptyStateView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "magnifyingglass.circle")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundColor(Color.purple.opacity(0.7))
            Text("No Results Found")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text("Try adjusting your search or filter to find what you're looking for.")
                .font(.body)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.purple.opacity(0.3))
                .blur(radius: 5)
        )
        .padding()
    }
}
