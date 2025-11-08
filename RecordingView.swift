//
//  RecordingView.swift
//  Discography
//
//  Created by Adam Faith on 2025-10-27.
//  COMPACT EDITION - Everything fits without scrolling
//

import SwiftUI
import SwiftData

// MARK: - Recording View
struct RecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var viewModel: MusicViewModel
    @StateObject private var audioRecorder = AudioRecorder()
    
    // Recording state
    @State private var recordingPhase: RecordingPhase = .ready
    @State private var hasRecording = false
    @State private var countdownValue: Int = 0
    @State private var isCountingDown = false
    
    // Song/Part selection
    @State private var selectedSong: MTSong?
    @State private var selectedPart: MTSongPart?
    @State private var pendingNewPartName: String? = nil
    @State private var showingSongPicker = false
    @State private var showingPartPicker = false
    @State private var showingNotes = false
    @State private var showingTools = false
    
    // Notes
    @State private var recordingNote = ""
    
    enum RecordingPhase {
        case ready, recording, recorded
    }
    
    var canSave: Bool {
        hasRecording && selectedSong != nil && selectedPart != nil
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.04, blue: 0.07),
                    Color(red: 0.15, green: 0.02, blue: 0.2),
                    Color(red: 0.02, green: 0.04, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Text("Record Part")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button {
                        showingTools = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .disabled(recordingPhase == .recording)
                    .opacity(recordingPhase == .recording ? 0.3 : 1.0)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                
                // Main Content - NO SCROLLVIEW, everything fits
                VStack(spacing: 0) {
                    // Song & Part Selection (Compact)
                    VStack(spacing: 12) {
                        if let song = selectedSong {
                            SelectedSongCardCompact(song: song) {
                                showingSongPicker = true
                            }
                        } else {
                            SongPartSelectorCard(
                                title: "Song",
                                selectedText: nil,
                                placeholder: "Select song",
                                icon: "music.note",
                                gradientColors: [.purple, .pink],
                                isPrimary: true
                            ) {
                                showingSongPicker = true
                            }
                        }
                        
                        if selectedSong != nil {
                            if let part = selectedPart {
                                SelectedPartChipCompact(
                                    part: part,
                                    isPending: pendingNewPartName != nil
                                ) {
                                    showingPartPicker = true
                                }
                            } else {
                                SongPartSelectorCard(
                                    title: "Part",
                                    selectedText: nil,
                                    placeholder: "Select part",
                                    icon: "music.quarternote.3",
                                    gradientColors: [.pink, .orange],
                                    isPrimary: false
                                ) {
                                    showingPartPicker = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // DYNAMIC MIDDLE SECTION - This is where the magic happens!
                    ZStack {
                        // Album art display when song is selected
                        if let song = selectedSong {
                            DynamicVisualSection(
                                song: song,
                                part: selectedPart,
                                isRecording: recordingPhase == .recording,
                                isPending: pendingNewPartName != nil,
                                recordingTime: audioRecorder.recordingTime
                            )
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            // Placeholder when no song selected
                            EmptyStateVisual()
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // BOTTOM SECTION - Record controls
                    VStack(spacing: 12) {
                        // Progress bar (only when recorded, compact)
                        if recordingPhase == .recorded {
                            CompactProgressBar(
                                currentTime: audioRecorder.playbackTime,
                                duration: audioRecorder.recordingDuration,
                                isPlaying: audioRecorder.isPlaying,
                                onSeek: { time in
                                    audioRecorder.seek(to: time)
                                }
                            )
                            .padding(.horizontal, 30)
                            .transition(.opacity)
                            .frame(height: 35)
                        }
                        
                        // Button row
                        HStack(spacing: 16) {
                            // Re-record button (only when recorded - LEFT)
                            if recordingPhase == .recorded {
                                SmallReRecordButton(onTap: handleReRecord)
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                // Empty spacer for symmetry when ready/recording
                                Color.clear
                                    .frame(width: 70, height: 70)
                            }
                            
                            Spacer()
                            
                            // Main center button - changes based on state
                            if recordingPhase == .recorded {
                                // PLAY button when recorded (center)
                                LargePlayButton(
                                    isPlaying: audioRecorder.isPlaying,
                                    onPlay: audioRecorder.playRecording,
                                    onStop: audioRecorder.stopPlaying
                                )
                            } else {
                                // RECORD button when ready/recording (center)
                                CoolRecordButton(
                                    isRecording: audioRecorder.isRecording,
                                    isCountingDown: isCountingDown,
                                    audioLevel: audioRecorder.audioLevel,
                                    onRecord: handleRecord
                                )
                            }
                            
                            Spacer()
                            
                            // Notes button (only when recorded - RIGHT)
                            if recordingPhase == .recorded {
                                SmallNotesButton(
                                    hasNotes: !recordingNote.isEmpty,
                                    onTap: {
                                        showingNotes = true
                                    }
                                )
                                .transition(.scale.combined(with: .opacity))
                            } else {
                                // Empty spacer for symmetry
                                Color.clear
                                    .frame(width: 70, height: 70)
                            }
                        }
                        .frame(height: 90)
                        .padding(.horizontal, 20)
                        
                        // Helper text + recording time
                        VStack(spacing: 4) {
                            if recordingPhase == .recording {
                                Text(formatRecordingTime(audioRecorder.recordingTime))
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.red.opacity(0.9))
                                    .transition(.opacity)
                            }
                            
                            Text(helperText)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .frame(height: 30)
                    }
                    .padding(.bottom, 12)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0),
                                Color.black.opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .bottom)
                    )
                }
                
                // Bottom Action Bar (Compact)
                if recordingPhase == .recorded {
                    CompactBottomBar(
                        canSave: canSave,
                        onDiscard: handleDiscard,
                        onSave: handleSave
                    )
                    .transition(.move(edge: .bottom))
                }
            }
            
            // Countdown overlay
            if isCountingDown {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                CountdownView(countdown: countdownValue)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showingSongPicker) {
            SongPickerSheet(
                songs: viewModel.songs,
                selectedSong: $selectedSong,
                onSelectSong: { song in
                    selectedSong = song
                    selectedPart = nil
                    showingSongPicker = false
                },
                onSelectNewSong: { suggestion in
                    Task {
                        if let existingSong = viewModel.songs.first(where: {
                            $0.title == suggestion.title && $0.artist == suggestion.artist
                        }) {
                            selectedSong = existingSong
                            selectedPart = nil
                            showingSongPicker = false
                            return
                        }
                        
                        await viewModel.addOrUpdateSong(
                            context: modelContext,
                            title: suggestion.title,
                            artist: suggestion.artist,
                            albumColor: .purple,
                            partName: "Intro",
                            partStatus: .learning,
                            artworkURL: suggestion.artworkURL?.absoluteString
                        )
                        
                        if let newSong = viewModel.songs.first(where: {
                            $0.title == suggestion.title && $0.artist == suggestion.artist
                        }) {
                            selectedSong = newSong
                            selectedPart = newSong.parts.first
                        }
                        
                        showingSongPicker = false
                    }
                }
            )
        }
        .sheet(isPresented: $showingPartPicker) {
            if let song = selectedSong {
                PartPickerSheet(
                    song: song,
                    selectedPart: $selectedPart,
                    onSelectPart: { part in
                        selectedPart = part
                        pendingNewPartName = nil
                        showingPartPicker = false
                    },
                    onAddNewPart: { partName in
                        let tempPart = MTSongPart(
                            id: UUID().uuidString,
                            name: partName,
                            status: .learning,
                            recordings: []
                        )
                        selectedPart = tempPart
                        pendingNewPartName = partName
                        showingPartPicker = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingNotes) {
            NotesSheet(note: $recordingNote)
                .presentationDetents([.height(300), .medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingTools) {
            ToolsSheet()
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
        .animation(.easeInOut(duration: 0.2), value: recordingPhase)
        .animation(.easeInOut(duration: 0.2), value: isCountingDown)
    }
    
    // MARK: - Helpers
    private var helperText: String {
        if isCountingDown { return "Get ready..." }
        
        switch recordingPhase {
        case .ready: return "Tap to start recording"
        case .recording: return "Tap to stop"
        case .recorded: return "Play or re-record"
        }
    }
    
    private func formatRecordingTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Actions
    private func handleRecord() {
        if audioRecorder.isRecording {
            _ = audioRecorder.stopRecording()
            withAnimation(.easeInOut(duration: 0.2)) {
                recordingPhase = .recorded
                hasRecording = true
            }
        } else {
            startCountdown()
        }
    }
    
    private func startCountdown() {
        isCountingDown = true
        countdownValue = 3
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            generator.impactOccurred()
            
            if countdownValue > 1 {
                countdownValue -= 1
            } else {
                timer.invalidate()
                
                let finalGenerator = UINotificationFeedbackGenerator()
                finalGenerator.notificationOccurred(.success)
                
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCountingDown = false
                    recordingPhase = .recording
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    audioRecorder.startRecording()
                }
            }
        }
    }
    
    private func handleDiscard() {
        if audioRecorder.isPlaying {
            audioRecorder.stopPlaying()
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            recordingPhase = .ready
            hasRecording = false
            audioRecorder.lastRecordingURL = nil
            audioRecorder.playbackTime = 0
            pendingNewPartName = nil
        }
    }
    
    private func handleReRecord() {
        handleDiscard()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            startCountdown()
        }
    }
    
    private func handleSave() {
        guard let song = selectedSong,
              let part = selectedPart,
              let recordingURL = audioRecorder.lastRecordingURL else { return }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        let recording = MTRecording(
            id: UUID().uuidString,
            type: .audio,
            date: Date(),
            note: recordingNote,
            fileURL: recordingURL.lastPathComponent
        )
        
        Task {
            if let pendingPartName = pendingNewPartName {
                await viewModel.addPart(
                    context: modelContext,
                    to: song,
                    name: pendingPartName,
                    status: .learning
                )
                
                if let updatedSong = viewModel.songs.first(where: { $0.id == song.id }),
                   let createdPart = updatedSong.parts.first(where: { $0.name == pendingPartName }) {
                    await viewModel.saveRecording(
                        context: modelContext,
                        songId: updatedSong.id,
                        partId: createdPart.id,
                        recording: recording
                    )
                }
            } else {
                await viewModel.saveRecording(
                    context: modelContext,
                    songId: song.id,
                    partId: part.id,
                    recording: recording
                )
            }
            
            dismiss()
        }
    }
}

// MARK: - Dynamic Visual Section (Middle of screen)
struct DynamicVisualSection: View {
    let song: MTSong
    let part: MTSongPart?
    let isRecording: Bool
    let isPending: Bool
    let recordingTime: TimeInterval
    
    @State private var pulseScale: CGFloat = 1.0
    
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
        VStack(spacing: 16) {
            Spacer()
            
            // Prominent PART indicator at top
            if let part = part {
                VStack(spacing: 8) {
                    Text("RECORDING")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.5))
                    
                    HStack(spacing: 8) {
                        Image(systemName: "music.quarternote.3")
                            .font(.title2)
                        Text(part.name.uppercased())
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .tracking(1)
                    }
                    .foregroundStyle(
                        LinearGradient(
                            colors: isPending ? [.orange, .yellow] : [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(
                                        LinearGradient(
                                            colors: isPending ?
                                                [.orange.opacity(0.5), .yellow.opacity(0.3)] :
                                                [.purple.opacity(0.5), .pink.opacity(0.3)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                    )
                    
                    if isPending {
                        Text("New part - will be created")
                            .font(.caption2)
                            .foregroundStyle(.orange.opacity(0.8))
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Spacer().frame(height: 8)
            
            // Large album artwork
            ZStack {
                // Main album art
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
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .empty:
                                ZStack {
                                    albumGradient
                                    ProgressView()
                                        .tint(.white)
                                }
                            default:
                                albumGradient
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.system(size: 60))
                                            .foregroundStyle(.white.opacity(0.6))
                                    )
                            }
                        }
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                .scaleEffect(pulseScale)
                
                // Recording indicator overlay
                if isRecording {
                    VStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                            Text("REC")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.black.opacity(0.7))
                        )
                    }
                    .frame(width: 180, height: 180)
                    .padding(.bottom, 12)
                }
            }
            
            // Song info (compact)
            VStack(spacing: 4) {
                Text(song.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(song.artist)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
            .padding(.horizontal, 30)
            
            Spacer()
        }
        .onChange(of: isRecording) { newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                    pulseScale = 1.05
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    pulseScale = 1.0
                }
            }
        }
    }
}

// MARK: - Empty State Visual
struct EmptyStateVisual: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.purple.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                
                Image(systemName: "music.note")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple.opacity(0.4), .pink.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("Select a song to begin")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.6))
                
                Text("Choose from your collection or search for new songs")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}

// MARK: - Cool Record Button with Animations
struct CoolRecordButton: View {
    let isRecording: Bool
    let isCountingDown: Bool
    let audioLevel: Float
    let onRecord: () -> Void
    
    @State private var pulseAnimation = false
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        Button(action: onRecord) {
            ZStack {
                // Outer animated rings when recording
                if isRecording {
                    ForEach(0..<3) { index in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.red.opacity(0.6), .red.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 2
                            )
                            .scaleEffect(pulseAnimation ? 1.0 + (Double(index) * 0.3) : 1.0)
                            .opacity(pulseAnimation ? 0 : 0.8)
                            .frame(width: 100, height: 100)
                            .animation(
                                .easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.2),
                                value: pulseAnimation
                            )
                    }
                }
                
                // Rotating gradient ring when recording
                if isRecording {
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(
                                colors: [.red, .pink, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 110, height: 110)
                        .rotationEffect(.degrees(rotationAngle))
                        .animation(
                            .linear(duration: 2)
                            .repeatForever(autoreverses: false),
                            value: rotationAngle
                        )
                }
                
                // Pulsing glow based on audio level
                if isRecording {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .red.opacity(Double(audioLevel) * 0.4),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                        .scaleEffect(1.0 + Double(audioLevel) * 0.3)
                        .animation(.easeOut(duration: 0.1), value: audioLevel)
                }
                
                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isRecording ?
                                [.red, Color(red: 0.8, green: 0.1, blue: 0.1)] :
                                [Color(red: 0.6, green: 0.2, blue: 0.8), Color(red: 0.8, green: 0.3, blue: 0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: isRecording ? .red.opacity(0.6) : .purple.opacity(0.5), radius: 15, y: 5)
                
                // Icon
                Image(systemName: isRecording ? "stop.fill" : "waveform")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isCountingDown)
        .opacity(isCountingDown ? 0.5 : 1.0)
        .onChange(of: isRecording) { newValue in
            if newValue {
                pulseAnimation = true
                withAnimation {
                    rotationAngle = 360
                }
            } else {
                pulseAnimation = false
                rotationAngle = 0
            }
        }
    }
}

// MARK: - Large Play Button (Center position when recorded)
struct LargePlayButton: View {
    let isPlaying: Bool
    let onPlay: () -> Void
    let onStop: () -> Void
    
    @State private var pulseAnimation = false
    
    var body: some View {
        Button(action: isPlaying ? onStop : onPlay) {
            ZStack {
                // Outer pulse ring when playing
                if isPlaying {
                    Circle()
                        .stroke(Color.purple.opacity(0.3), lineWidth: 3)
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                        .opacity(pulseAnimation ? 0 : 1)
                        .frame(width: 110, height: 110)
                }
                
                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .purple.opacity(0.5), radius: 15, y: 5)
                
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(.white)
                    .offset(x: isPlaying ? 0 : 3)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .onChange(of: isPlaying) { newValue in
            if newValue {
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    pulseAnimation = true
                }
            } else {
                pulseAnimation = false
            }
        }
    }
}

// MARK: - Small Re-Record Button (Left position when recorded)
struct SmallReRecordButton: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, Color(red: 0.9, green: 0.5, blue: 0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: .orange.opacity(0.3), radius: 10, y: 4)
                
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Small Tools Button (Left position when ready/recording)
struct SmallToolsButton: View {
    let isRecording: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 50, height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isRecording)
        .opacity(isRecording ? 0.3 : 1.0)
    }
}

// MARK: - Tools Sheet
struct ToolsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var metronomeEnabled = false
    @State private var showLyrics = false
    @State private var showLayers = false
    
    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.04, blue: 0.07)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Recording Tools")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Tool options
                VStack(spacing: 0) {
                    ToolRow(
                        icon: "metronome",
                        title: "Metronome",
                        subtitle: "Coming soon",
                        color: .green,
                        isEnabled: false
                    )
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.leading, 70)
                    
                    ToolRow(
                        icon: "text.alignleft",
                        title: "Lyrics",
                        subtitle: "Coming soon",
                        color: .blue,
                        isEnabled: false
                    )
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.leading, 70)
                    
                    ToolRow(
                        icon: "waveform.badge.plus",
                        title: "Layer Recordings",
                        subtitle: "Coming soon",
                        color: .purple,
                        isEnabled: false
                    )
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Tool Row
struct ToolRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isEnabled: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
            
            if !isEnabled {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

// MARK: - Small Notes Button
struct SmallNotesButton: View {
    let hasNotes: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, Color(red: 0.2, green: 0.4, blue: 0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: .blue.opacity(0.3), radius: 10, y: 4)
                
                ZStack {
                    Image(systemName: "note.text")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white)
                    
                    // Badge indicator if has notes
                    if hasNotes {
                        VStack {
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(.green)
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Circle()
                                            .stroke(.white, lineWidth: 2)
                                    )
                            }
                            Spacer()
                        }
                        .frame(width: 70, height: 70)
                        .offset(x: 8, y: -8)
                    }
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Notes Sheet
struct NotesSheet: View {
    @Binding var note: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.02, green: 0.04, blue: 0.07)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Recording Notes")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            
                            Text("Add practice notes, feedback, or reminders")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Text editor
                    TextEditor(text: $note)
                        .foregroundStyle(.white)
                        .scrollContentBackground(.hidden)
                        .background(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                        .cornerRadius(16)
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 20)
                        .focused($isFocused)
                    
                    // Quick actions
                    if note.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Notes")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.7))
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    QuickNoteButton(text: "Good take! ✓") {
                                        note = "Good take! ✓"
                                    }
                                    QuickNoteButton(text: "Need to practice tempo") {
                                        note = "Need to practice tempo"
                                    }
                                    QuickNoteButton(text: "Almost there") {
                                        note = "Almost there"
                                    }
                                    QuickNoteButton(text: "Ready to record final") {
                                        note = "Ready to record final"
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                    }
                    
                    // Done button
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.blue, Color(red: 0.2, green: 0.4, blue: 0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}

// MARK: - Quick Note Button
struct QuickNoteButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Compact Progress Bar
struct CompactProgressBar: View {
    let currentTime: TimeInterval
    let duration: TimeInterval
    let isPlaying: Bool
    let onSeek: (TimeInterval) -> Void
    
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    
    private var progress: Double {
        guard duration > 0 else { return 0 }
        return isDragging ? dragProgress : currentTime / duration
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // Time labels (compact)
            HStack {
                Text(formatTime(isDragging ? dragProgress * duration : currentTime))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
                
                Text(formatTime(duration))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 6)
                    
                    Circle()
                        .fill(.white)
                        .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
                        .shadow(color: .purple.opacity(0.5), radius: 4)
                        .offset(x: geometry.size.width * progress - (isDragging ? 8 : 6))
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let newProgress = max(0, min(1, value.location.x / geometry.size.width))
                            dragProgress = newProgress
                            
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                        .onEnded { value in
                            isDragging = false
                            let newProgress = max(0, min(1, value.location.x / geometry.size.width))
                            let newTime = newProgress * duration
                            onSeek(newTime)
                            
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        }
                )
            }
            .frame(height: 16)
        }
    }
}

// MARK: - Countdown View
struct CountdownView: View {
    let countdown: Int
    @State private var scale: CGFloat = 0.5
    
    var body: some View {
        Text("\(countdown)")
            .font(.system(size: 120, weight: .bold, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [.white, .purple.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 1.2
                }
                withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                    scale = 1.0
                }
            }
            .onChange(of: countdown) { _ in
                scale = 0.5
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 1.2
                }
                withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                    scale = 1.0
                }
            }
    }
}

// MARK: - Compact Bottom Bar
struct CompactBottomBar: View {
    let canSave: Bool
    let onDiscard: () -> Void
    let onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.1))
            
            HStack(spacing: 10) {
                Button(action: onDiscard) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                        Text("Discard")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.red.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.red.opacity(0.4), lineWidth: 1.5)
                            )
                    )
                }
                
                Button(action: onSave) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                        Text("Save")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: canSave ? [.green, Color(red: 0, green: 0.7, blue: 0)] : [.gray, .gray],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: canSave ? .green.opacity(0.3) : .clear, radius: 8)
                }
                .disabled(!canSave)
                .opacity(canSave ? 1.0 : 0.5)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.black.opacity(0.3))
    }
}

// MARK: - Compact Song Card
struct SelectedSongCardCompact: View {
    let song: MTSong
    let action: () -> Void
    
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
        Button(action: action) {
            HStack(spacing: 12) {
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
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text(song.artist)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    colors: [.green.opacity(0.4), .green.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Compact Part Chip
struct SelectedPartChipCompact: View {
    let part: MTSongPart
    let isPending: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isPending ? "clock.badge.exclamationmark" : (part.status == .complete ? "checkmark.circle.fill" : "clock.fill"))
                    .foregroundStyle(isPending ? .orange : (part.status == .complete ? .green : .orange))
                    .font(.title3)
                
                Text(part.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Spacer()
                
                if isPending {
                    Text("New")
                        .font(.caption2)
                        .foregroundStyle(.orange.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.orange.opacity(0.2)))
                }
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    colors: isPending ?
                                        [.orange.opacity(0.3), .orange.opacity(0.2)] :
                                        [.green.opacity(0.3), .green.opacity(0.2)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Song/Part Selector Card
struct SongPartSelectorCard: View {
    let title: String
    let selectedText: String?
    let placeholder: String
    let icon: String
    let gradientColors: [Color]
    var isPrimary: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradientColors.map { $0.opacity(0.2) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Text(selectedText ?? placeholder)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(selectedText != nil ? .white : .white.opacity(0.4))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
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
                                    colors: gradientColors.map { $0.opacity(0.3) },
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
}
