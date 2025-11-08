//
//  StudioComposer.swift
//  JamSeshNew
//
//  Created by Adam Faith on 2025-11-08.
//

import SwiftUI
import SwiftData

struct StudioComposerView: View {
    @ObservedObject var viewModel: MusicViewModel
    @Environment(\.modelContext) private var modelContext
    
    @State private var composition: Composition?
    @State private var showingClipPicker = false
    @State private var selectedTrackId: String?
    @State private var currentTime: Double = 0
    @State private var isPlaying = false
    @State private var showingSaveDialog = false
    @State private var compositionTitle = ""
    
    @StateObject private var audioMixing = AudioMixingService()
    
    private let timelineScale: CGFloat = 50 // pixels per second
    
    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            HStack {
                Text("Studio")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)
                
                Spacer()
                
                if composition != nil && !(composition?.tracks.isEmpty ?? true) {
                    Button {
                        showingSaveDialog = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down")
                            Text("Export")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [.green, Color(red: 0, green: 0.7, blue: 0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                    }
                }
            }
            .padding()
            .background(Color.black.opacity(0.3))
            
            if composition == nil || composition?.tracks.isEmpty == true {
                // Empty state
                emptyStateView
            } else {
                // Timeline view
                timelineView
            }
        }
        .sheet(isPresented: $showingClipPicker) {
            ClipPickerSheet(
                viewModel: viewModel,
                onSelect: { recording, song, part in
                    addTrack(recording: recording)
                }
            )
        }
        .alert("Export Composition", isPresented: $showingSaveDialog) {
            TextField("Title", text: $compositionTitle)
            Button("Cancel", role: .cancel) { }
            Button("Export") {
                Task {
                    await exportComposition()
                }
            }
        } message: {
            Text("Enter a title for your composition")
        }
        .onAppear {
            if composition == nil {
                composition = Composition(
                    id: UUID().uuidString,
                    title: "New Composition",
                    createdDate: Date(),
                    tracks: [],
                    duration: 60.0
                )
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "waveform.badge.plus")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 12) {
                Text("Create Your First Composition")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Layer and stitch your clips into full songs")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            Button {
                showingClipPicker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("Add First Clip")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: .purple.opacity(0.4), radius: 12)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Timeline View
    private var timelineView: some View {
        VStack(spacing: 0) {
            // Playback controls
            HStack(spacing: 20) {
                Button {
                    currentTime = 0
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Button {
                    isPlaying.toggle()
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
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }
                
                Button {
                    showingClipPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                        Text("Add Track")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.purple)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Timeline
            ScrollView(.horizontal, showsIndicators: true) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        if let comp = composition {
                            ForEach(comp.tracks) { track in
                                TrackRow(
                                    track: track,
                                    composition: comp,
                                    viewModel: viewModel,
                                    timelineScale: timelineScale,
                                    isSelected: selectedTrackId == track.id,
                                    currentTime: currentTime,
                                    onSelect: { selectedTrackId = track.id },
                                    onDelete: { deleteTrack(track) },
                                    onUpdate: { updated in updateTrack(updated) }
                                )
                            }
                        }
                    }
                    .padding()
                }
                .frame(height: 400)
            }
            .background(Color.black.opacity(0.4))
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Track inspector (if selected)
            if let trackId = selectedTrackId,
               let track = composition?.tracks.first(where: { $0.id == trackId }) {
                TrackInspector(
                    track: track,
                    onUpdate: { updated in updateTrack(updated) },
                    onClose: { selectedTrackId = nil }
                )
                .transition(.move(edge: .bottom))
            }
        }
    }
    
    // MARK: - Track Management
    private func addTrack(recording: MTRecording) {
        guard var comp = composition else { return }
        
        let newTrack = CompositionTrack(
            id: UUID().uuidString,
            recordingId: recording.id,
            startTime: 0,
            volume: 1.0,
            isMuted: false,
            trackColor: "purple"
        )
        
        comp.tracks.append(newTrack)
        composition = comp
    }
    
    private func deleteTrack(_ track: CompositionTrack) {
        composition?.tracks.removeAll { $0.id == track.id }
        if selectedTrackId == track.id {
            selectedTrackId = nil
        }
    }
    
    private func updateTrack(_ updated: CompositionTrack) {
        guard let index = composition?.tracks.firstIndex(where: { $0.id == updated.id }) else { return }
        composition?.tracks[index] = updated
    }
    
    private func exportComposition() async {
        guard let comp = composition else { return }
        
        do {
            let outputURL = try await audioMixing.mixComposition(
                tracks: comp.tracks,
                recordings: viewModel.songs.flatMap { $0.parts.flatMap { $0.recordings } },
                duration: comp.duration
            )
            
            // Save to documents
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let finalURL = docs.appendingPathComponent("\(compositionTitle.isEmpty ? "composition" : compositionTitle)_\(UUID().uuidString).m4a")
            
            try FileManager.default.copyItem(at: outputURL, to: finalURL)
            
            viewModel.notificationMessage = "Composition exported successfully!"
        } catch {
            viewModel.notificationMessage = "Failed to export composition: \(error.localizedDescription)"
        }
    }
}

// MARK: - Track Row
struct TrackRow: View {
    let track: CompositionTrack
    let composition: Composition
    @ObservedObject var viewModel: MusicViewModel
    let timelineScale: CGFloat
    let isSelected: Bool
    let currentTime: Double
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onUpdate: (CompositionTrack) -> Void
    
    @State private var dragOffset: CGFloat = 0
    
    private var recording: MTRecording? {
        viewModel.songs
            .flatMap { $0.parts.flatMap { $0.recordings } }
            .first { $0.id == track.recordingId }
    }
    
    private var songInfo: (song: MTSong, part: MTSongPart)? {
        for song in viewModel.songs {
            for part in song.parts {
                if part.recordings.contains(where: { $0.id == track.recordingId }) {
                    return (song, part)
                }
            }
        }
        return nil
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Track info
            VStack(alignment: .leading, spacing: 4) {
                if let info = songInfo {
                    Text(info.song.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text(info.part.name)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(width: 120, alignment: .leading)
            
            // Track visualization
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: composition.duration * timelineScale, height: 60)
                
                // Clip
                TrackClip(
                    track: track,
                    recording: recording,
                    timelineScale: timelineScale,
                    isSelected: isSelected
                )
                .offset(x: track.startTime * timelineScale + dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let newStartTime = max(0, track.startTime + (value.translation.width / timelineScale))
                            var updated = track
                            updated.startTime = newStartTime
                            onUpdate(updated)
                            dragOffset = 0
                        }
                )
                .onTapGesture {
                    onSelect()
                }
                
                // Playhead
                Rectangle()
                    .fill(Color.pink)
                    .frame(width: 2)
                    .offset(x: currentTime * timelineScale)
            }
            
            // Mute button
            Button {
                var updated = track
                updated.isMuted.toggle()
                onUpdate(updated)
            } label: {
                Image(systemName: track.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.caption)
                    .foregroundStyle(track.isMuted ? .red : .white.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Delete button
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.purple.opacity(0.2) : Color.clear)
        )
    }
}

// MARK: - Track Clip
struct TrackClip: View {
    let track: CompositionTrack
    let recording: MTRecording?
    let timelineScale: CGFloat
    let isSelected: Bool
    
    private var clipWidth: CGFloat {
        guard let rec = recording, let fileURL = rec.fileURL else { return 100 }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(fileURL)
        
        if let player = try? AVAudioPlayer(contentsOf: url) {
            return player.duration * timelineScale
        }
        return 100
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [.purple.opacity(0.6), .pink.opacity(0.6)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: clipWidth, height: 50)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
            )
            .overlay(
                HStack {
                    if recording?.isLoop == true {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                .padding(6)
            )
    }
}

// MARK: - Track Inspector
struct TrackInspector: View {
    let track: CompositionTrack
    let onUpdate: (CompositionTrack) -> Void
    let onClose: () -> Void
    
    @State private var volume: Float
    
    init(track: CompositionTrack, onUpdate: @escaping (CompositionTrack) -> Void, onClose: @escaping () -> Void) {
        self.track = track
        self.onUpdate = onUpdate
        self.onClose = onClose
        _volume = State(initialValue: track.volume)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Track Settings")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Volume: \(Int(volume * 100))%")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                
                Slider(value: $volume, in: 0...1)
                    .tint(.purple)
                    .onChange(of: volume) { newValue in
                        var updated = track
                        updated.volume = newValue
                        onUpdate(updated)
                    }
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
    }
}

// MARK: - Clip Picker Sheet
struct ClipPickerSheet: View {
    @ObservedObject var viewModel: MusicViewModel
    let onSelect: (MTRecording, MTSong, MTSongPart) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var allRecordings: [(recording: MTRecording, song: MTSong, part: MTSongPart)] {
        var result: [(MTRecording, MTSong, MTSongPart)] = []
        for song in viewModel.songs {
            for part in song.parts {
                for recording in part.recordings {
                    result.append((recording, song, part))
                }
            }
        }
        return result.sorted { $0.recording.date > $1.recording.date }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.02, green: 0.04, blue: 0.07)
                    .ignoresSafeArea()
                
                if allRecordings.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "waveform.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.purple.opacity(0.6))
                        
                        Text("No clips available")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text("Record some clips first")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                } else {
                    List {
                        ForEach(allRecordings, id: \.recording.id) { item in
                            Button {
                                onSelect(item.recording, item.song, item.part)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [.purple, .pink],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 40, height: 40)
                                        
                                        Image(systemName: item.recording.isLoop ? "arrow.triangle.2.circlepath" : "waveform")
                                            .foregroundStyle(.white)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.song.title)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        
                                        HStack(spacing: 6) {
                                            Text(item.part.name)
                                                .font(.caption)
                                                .foregroundStyle(.purple)
                                            
                                            if item.recording.isLoop {
                                                Text("•")
                                                    .foregroundStyle(.white.opacity(0.3))
                                                Text("Loop")
                                                    .font(.caption2)
                                                    .foregroundStyle(.green)
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.05))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Select Clip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.purple)
                }
            }
        }
    }
}
