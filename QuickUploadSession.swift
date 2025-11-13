
//
//  QuickUploadSession.swift
//  JamSeshNew
//
//  Quick upload session for bulk recording multiple songs
//

import SwiftUI
import SwiftData
import AVFoundation

// MARK: - Quick Upload Models

struct QUClip: Identifiable, Codable {
    let id: String
    let fileURL: String
    let duration: TimeInterval
    let date: Date
    var isIdentified: Bool = false
    var songId: String?
    var songTitle: String?
    var songArtist: String?
    var partName: String?
    
    init(id: String = UUID().uuidString, fileURL: String, duration: TimeInterval, date: Date = Date()) {
        self.id = id
        self.fileURL = fileURL
        self.duration = duration
        self.date = date
    }
}

struct QUSession: Codable {
    var clips: [QUClip]
    let startDate: Date
    var lastModified: Date
    
    init() {
        self.clips = []
        self.startDate = Date()
        self.lastModified = Date()
    }
}

// MARK: - Session Manager

@MainActor
class QuickUploadSessionManager: ObservableObject {
    @Published var session: QUSession
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var showingReview = false
    
    private let sessionKey = "quick_upload_session"
    private var recordingTimer: Timer?
    
    init() {
        // Load existing session or create new one
        if let data = UserDefaults.standard.data(forKey: sessionKey),
           let savedSession = try? JSONDecoder().decode(QUSession.self, from: data) {
            self.session = savedSession
        } else {
            self.session = QUSession()
        }
    }
    
    func saveSession() {
        session.lastModified = Date()
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: sessionKey)
        }
    }
    
    func clearSession() {
        // Delete all audio files
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for clip in session.clips {
            let url = docs.appendingPathComponent(clip.fileURL)
            try? FileManager.default.removeItem(at: url)
        }
        
        session = QUSession()
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }
    
    func deleteClip(_ clip: QUClip) {
        // Delete file
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(clip.fileURL)
        try? FileManager.default.removeItem(at: url)
        
        // Remove from session
        session.clips.removeAll { $0.id == clip.id }
        saveSession()
    }
    
    func startRecording() {
        isRecording = true
        recordingTime = 0
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingTime += 0.1
        }
    }
    
    func stopRecording(fileURL: String, duration: TimeInterval) {
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        let clip = QUClip(fileURL: fileURL, duration: duration)
        session.clips.insert(clip, at: 0) // Add to beginning
        saveSession()
    }
    
    func updateClipIdentification(clipId: String, songId: String?, songTitle: String?, songArtist: String?, partName: String?) {
        if let index = session.clips.firstIndex(where: { $0.id == clipId }) {
            session.clips[index].isIdentified = true
            session.clips[index].songId = songId
            session.clips[index].songTitle = songTitle
            session.clips[index].songArtist = songArtist
            session.clips[index].partName = partName
            saveSession()
        }
    }
    
    var unidentifiedClips: [QUClip] {
        session.clips.filter { !$0.isIdentified }
    }
    
    var identifiedClips: [QUClip] {
        session.clips.filter { $0.isIdentified }
    }
    
    var progress: Double {
        guard !session.clips.isEmpty else { return 0 }
        return Double(identifiedClips.count) / Double(session.clips.count)
    }
}

// MARK: - Main Quick Upload View

struct QuickUploadView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var viewModel: MusicViewModel
    @StateObject private var sessionManager = QuickUploadSessionManager()
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var showingIdentifySheet = false
    @State private var clipToIdentify: QUClip?
    @State private var showingConfirmFinish = false
    @State private var isProcessing = false
    
    private var canFinish: Bool {
        !sessionManager.session.clips.isEmpty &&
        sessionManager.unidentifiedClips.isEmpty
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.04, blue: 0.07),
                    Color(red: 0.1, green: 0.02, blue: 0.15),
                    Color(red: 0.02, green: 0.04, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar
                QUTopBar(
                    onClose: { dismiss() },
                    onFinish: {
                        if canFinish {
                            showingConfirmFinish = true
                        }
                    },
                    canFinish: canFinish,
                    progress: sessionManager.progress
                )
                
                // Main Content
                if sessionManager.session.clips.isEmpty {
                    // Empty state - first recording
                    QUEmptyState(
                        onStartRecording: handleStartRecording
                    )
                } else {
                    // Clips list with recording controls
                    ScrollView {
                        VStack(spacing: 20) {
                            // Stats header
                            QUStatsHeader(
                                totalClips: sessionManager.session.clips.count,
                                identified: sessionManager.identifiedClips.count,
                                unidentified: sessionManager.unidentifiedClips.count
                            )
                            
                            // Unidentified clips
                            if !sessionManager.unidentifiedClips.isEmpty {
                                QUClipsSection(
                                    title: "Needs Identification",
                                    clips: sessionManager.unidentifiedClips,
                                    onIdentify: { clip in
                                        clipToIdentify = clip
                                        showingIdentifySheet = true
                                    },
                                    onDelete: { clip in
                                        sessionManager.deleteClip(clip)
                                    }
                                )
                            }
                            
                            // Identified clips
                            if !sessionManager.identifiedClips.isEmpty {
                                QUClipsSection(
                                    title: "Identified (\(sessionManager.identifiedClips.count))",
                                    clips: sessionManager.identifiedClips,
                                    onIdentify: { clip in
                                        clipToIdentify = clip
                                        showingIdentifySheet = true
                                    },
                                    onDelete: { clip in
                                        sessionManager.deleteClip(clip)
                                    }
                                )
                            }
                        }
                        .padding()
                        .padding(.bottom, 120) // Space for floating button
                    }
                }
                
                Spacer()
            }
            
            // Recording overlay
            if sessionManager.isRecording {
                QURecordingOverlay(
                    recordingTime: sessionManager.recordingTime,
                    audioLevel: audioRecorder.audioLevel,
                    onStop: handleStopRecording
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Floating record button
            if !sessionManager.isRecording && !sessionManager.session.clips.isEmpty {
                VStack {
                    Spacer()
                    QUFloatingRecordButton(onTap: handleStartRecording)
                        .padding(.bottom, 30)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showingIdentifySheet) {
            if let clip = clipToIdentify {
                QUIdentifySheet(
                    clip: clip,
                    viewModel: viewModel,
                    onIdentify: { updatedClip in
                        sessionManager.updateClipIdentification(
                            clipId: updatedClip.id,
                            songId: updatedClip.songId,
                            songTitle: updatedClip.songTitle,
                            songArtist: updatedClip.songArtist,
                            partName: updatedClip.partName
                        )
                        showingIdentifySheet = false
                    }
                )
            }
        }
        .alert("Finish Session", isPresented: $showingConfirmFinish) {
            Button("Cancel", role: .cancel) { }
            Button("Save All", role: .destructive) {
                Task { await finishSession() }
            }
        } message: {
            Text("Save all \(sessionManager.identifiedClips.count) recordings to your library?")
        }
        .overlay {
            if isProcessing {
                QUProcessingOverlay()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: sessionManager.isRecording)
    }
    
    // MARK: - Actions
    
    private func handleStartRecording() {
        sessionManager.startRecording()
        audioRecorder.startRecording()
    }
    
    private func handleStopRecording() {
        guard let recordingURL = audioRecorder.stopRecording() else { return }
        
        // Get duration
        let duration: TimeInterval
        if let player = try? AVAudioPlayer(contentsOf: recordingURL) {
            duration = player.duration
        } else {
            duration = sessionManager.recordingTime
        }
        
        sessionManager.stopRecording(
            fileURL: recordingURL.lastPathComponent,
            duration: duration
        )
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func finishSession() async {
        isProcessing = true
        
        // Save all identified clips to library
        for clip in sessionManager.identifiedClips {
            guard let songTitle = clip.songTitle,
                  let songArtist = clip.songArtist,
                  let partName = clip.partName else { continue }
            
            // Create recording object
            let recording = MTRecording(
                id: UUID().uuidString,
                type: .audio,
                date: clip.date,
                note: "Quick upload",
                fileURL: clip.fileURL
            )
            
            // Check if song exists
            if let songId = clip.songId,
               let existingSong = viewModel.songs.first(where: { $0.id == songId }) {
                // Add to existing song
                if let existingPart = existingSong.parts.first(where: { $0.name == partName }) {
                    // Add to existing part
                    await viewModel.saveRecording(
                        context: modelContext,
                        songId: existingSong.id,
                        partId: existingPart.id,
                        recording: recording
                    )
                } else {
                    // Create new part
                    await viewModel.addPart(
                        context: modelContext,
                        to: existingSong,
                        name: partName,
                        status: .learning
                    )
                    
                    // Reload to get the new part
                    if let updatedSong = viewModel.songs.first(where: { $0.id == songId }),
                       let newPart = updatedSong.parts.first(where: { $0.name == partName }) {
                        await viewModel.saveRecording(
                            context: modelContext,
                            songId: updatedSong.id,
                            partId: newPart.id,
                            recording: recording
                        )
                    }
                }
            } else {
                // Create new song with part
                await viewModel.addOrUpdateSong(
                    context: modelContext,
                    title: songTitle,
                    artist: songArtist,
                    albumColor: .purple,
                    partName: partName,
                    partStatus: .learning,
                    artworkURL: nil
                )
                
                // Get the newly created song and save recording
                if let newSong = viewModel.songs.first(where: {
                    $0.title == songTitle && $0.artist == songArtist
                }), let newPart = newSong.parts.first(where: { $0.name == partName }) {
                    await viewModel.saveRecording(
                        context: modelContext,
                        songId: newSong.id,
                        partId: newPart.id,
                        recording: recording
                    )
                }
            }
        }
        
        // Clear session
        sessionManager.clearSession()
        
        isProcessing = false
        
        // Dismiss with success feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        dismiss()
    }
}

// MARK: - Top Bar

struct QUTopBar: View {
    let onClose: () -> Void
    let onFinish: () -> Void
    let canFinish: Bool
    let progress: Double
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Close")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white.opacity(0.7))
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text("Quick Upload")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    if progress > 0 {
                        Text("\(Int(progress * 100))% Complete")
                            .font(.caption2)
                            .foregroundStyle(.purple.opacity(0.8))
                    }
                }
                
                Spacer()
                
                Button(action: onFinish) {
                    HStack(spacing: 6) {
                        Text("Finish")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                    }
                    .foregroundStyle(canFinish ? .green : .white.opacity(0.3))
                }
                .disabled(!canFinish)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            // Progress bar
            if progress > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 3)
                        
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress, height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
        .background(Color.black.opacity(0.3))
    }
}

// MARK: - Empty State

struct QUEmptyState: View {
    let onStartRecording: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.purple.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                
                Image(systemName: "waveform.badge.plus")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Text
            VStack(spacing: 12) {
                Text("Quick Upload Session")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Record multiple songs quickly, then identify them all at once")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Steps
            VStack(alignment: .leading, spacing: 16) {
                QUStepRow(number: "1", text: "Record clips of different songs", icon: "waveform")
                QUStepRow(number: "2", text: "Identify each recording", icon: "music.note.list")
                QUStepRow(number: "3", text: "Save all to your library", icon: "checkmark.circle.fill")
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Start button
            Button(action: onStartRecording) {
                HStack(spacing: 12) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.title2)
                    Text("Start Recording")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .purple.opacity(0.4), radius: 12, y: 6)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
    }
}

struct QUStepRow: View {
    let number: String
    let text: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Text(number)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.purple)
            }
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            
            Spacer()
            
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.purple.opacity(0.5))
        }
    }
}

// MARK: - Stats Header

struct QUStatsHeader: View {
    let totalClips: Int
    let identified: Int
    let unidentified: Int
    
    var body: some View {
        HStack(spacing: 16) {
            QUStatCard(
                title: "Total",
                value: "\(totalClips)",
                icon: "waveform",
                color: .blue
            )
            
            QUStatCard(
                title: "Ready",
                value: "\(identified)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            QUStatCard(
                title: "Pending",
                value: "\(unidentified)",
                icon: "clock.fill",
                color: .orange
            )
        }
    }
}

struct QUStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Clips Section

struct QUClipsSection: View {
    let title: String
    let clips: [QUClip]
    let onIdentify: (QUClip) -> Void
    let onDelete: (QUClip) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
            
            VStack(spacing: 10) {
                ForEach(clips) { clip in
                    QUClipCard(
                        clip: clip,
                        onIdentify: { onIdentify(clip) },
                        onDelete: { onDelete(clip) }
                    )
                }
            }
        }
    }
}

// MARK: - Clip Card

struct QUClipCard: View {
    let clip: QUClip
    let onIdentify: () -> Void
    let onDelete: () -> Void
    
    @StateObject private var audioPlayer = SimpleAudioPlayer()
    
    private var formattedDuration: String {
        let minutes = Int(clip.duration) / 60
        let seconds = Int(clip.duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: clip.date)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Play button
                Button(action: {
                    if audioPlayer.isPlaying {
                        audioPlayer.stop()
                    } else {
                        audioPlayer.play(fileURL: clip.fileURL)
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: audioPlayer.isPlaying ?
                                        [.purple, .pink] :
                                        [Color.white.opacity(0.15), Color.white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .offset(x: audioPlayer.isPlaying ? 0 : 2)
                    }
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    if clip.isIdentified, let title = clip.songTitle {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            
                            Text(title)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        
                        HStack(spacing: 4) {
                            if let artist = clip.songArtist {
                                Text(artist)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            
                            if let partName = clip.partName {
                                Text("•")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.3))
                                
                                Text(partName)
                                    .font(.caption)
                                    .foregroundStyle(.purple)
                            }
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            
                            Text("Tap to identify")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        
                        Text("Recorded at \(formattedTime)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.caption2)
                        Text(formattedDuration)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.purple.opacity(0.8))
                }
                
                Spacer()
                
                // Action button
                Button(action: onIdentify) {
                    Image(systemName: clip.isIdentified ? "pencil" : "music.note.list")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(clip.isIdentified ? .white.opacity(0.6) : .purple)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(clip.isIdentified ? 0.1 : 0.15))
                        )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
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
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        clip.isIdentified ?
                            Color.green.opacity(0.3) :
                            Color.orange.opacity(0.3),
                        lineWidth: 1
                    )
            )
            .contextMenu {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Floating Record Button

struct QUFloatingRecordButton: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .font(.title2)
                Text("Record Another")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .purple.opacity(0.5), radius: 15, y: 8)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Recording Overlay

struct QURecordingOverlay: View {
    let recordingTime: TimeInterval
    let audioLevel: Float
    let onStop: () -> Void
    
    @State private var pulseAnimation = false
    
    private var formattedTime: String {
        let minutes = Int(recordingTime) / 60
        let seconds = Int(recordingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 30) {
                // Recording indicator
                HStack(spacing: 12) {
                    Circle()
                        .fill(.red)
                        .frame(width: 12, height: 12)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    
                    Text("RECORDING")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        pulseAnimation = true
                    }
                }
                
                // Time display
                Text(formattedTime)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                
                // Audio level visualization
                HStack(spacing: 4) {
                    ForEach(0..<20, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(
                                width: 4,
                                height: CGFloat.random(in: 20...60) * CGFloat(audioLevel)
                            )
                            .opacity(Double(audioLevel) * 0.8 + 0.2)
                    }
                }
                .frame(height: 60)
                
                // Stop button
                Button(action: onStop) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.red, Color(red: 0.8, green: 0.1, blue: 0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: .red.opacity(0.5), radius: 15, y: 8)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white)
                            .frame(width: 24, height: 24)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                
                Text("Tap to stop recording")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.8),
                                Color.black.opacity(0.6)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(
                                LinearGradient(
                                    colors: [.red.opacity(0.5), .red.opacity(0.2)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 2
                            )
                    )
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Identify Sheet

struct QUIdentifySheet: View {
    let clip: QUClip
    @ObservedObject var viewModel: MusicViewModel
    let onIdentify: (QUClip) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSong: MTSong?
    @State private var selectedPartName: String = ""
    @State private var showingSongPicker = false
    @State private var customSongTitle: String = ""
    @State private var customSongArtist: String = ""
    
    private var canSave: Bool {
        if let song = selectedSong {
            return !selectedPartName.isEmpty
        } else {
            return !customSongTitle.isEmpty && !customSongArtist.isEmpty && !selectedPartName.isEmpty
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.02, green: 0.04, blue: 0.07)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Preview
                        QUClipPreview(clip: clip)
                        
                        // Song selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Song")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            if let song = selectedSong {
                                HStack(spacing: 12) {
                                    AlbumArtView(song: song, size: 50)
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(song.title)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                        
                                        Text(song.artist)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.6))
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: { selectedSong = nil }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.white.opacity(0.6))
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.green.opacity(0.15))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            } else {
                                Button(action: { showingSongPicker = true }) {
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                        Text("Select existing song")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                    }
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.08))
                                    )
                                }
                                
                                Text("OR")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.4))
                                    .frame(maxWidth: .infinity)
                                
                                VStack(spacing: 12) {
                                    TextField("Song title", text: $customSongTitle)
                                        .textFieldStyle(QUTextFieldStyle())
                                    
                                    TextField("Artist", text: $customSongArtist)
                                        .textFieldStyle(QUTextFieldStyle())
                                }
                            }
                        }
                        
                        // Part selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Part")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            if let song = selectedSong {
                                // Show existing parts + custom option
                                VStack(spacing: 8) {
                                    ForEach(song.parts) { part in
                                        Button(action: { selectedPartName = part.name }) {
                                            HStack {
                                                Image(systemName: selectedPartName == part.name ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(selectedPartName == part.name ? .green : .white.opacity(0.3))
                                                
                                                Text(part.name)
                                                    .foregroundStyle(.white)
                                                
                                                Spacer()
                                            }
                                            .padding(12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color.white.opacity(selectedPartName == part.name ? 0.15 : 0.05))
                                            )
                                        }
                                    }
                                    
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                    
                                    TextField("Or enter new part name", text: $selectedPartName)
                                        .textFieldStyle(QUTextFieldStyle())
                                }
                            } else {
                                TextField("Part name (e.g., Intro, Verse, Chorus)", text: $selectedPartName)
                                    .textFieldStyle(QUTextFieldStyle())
                            }
                        }
                        
                        // Save button
                        Button(action: handleSave) {
                            Text("Save")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: canSave ? [.green, Color(red: 0, green: 0.7, blue: 0)] : [.gray, .gray],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(14)
                        }
                        .disabled(!canSave)
                        .opacity(canSave ? 1.0 : 0.5)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Identify Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingSongPicker) {
                QUSongPickerSheet(
                    songs: viewModel.songs,
                    onSelect: { song in
                        selectedSong = song
                        showingSongPicker = false
                    }
                )
            }
        }
    }
    
    private func handleSave() {
        var updatedClip = clip
        
        if let song = selectedSong {
            updatedClip.songId = song.id
            updatedClip.songTitle = song.title
            updatedClip.songArtist = song.artist
        } else {
            updatedClip.songTitle = customSongTitle
            updatedClip.songArtist = customSongArtist
        }
        
        updatedClip.partName = selectedPartName
        
        onIdentify(updatedClip)
        dismiss()
    }
}

// MARK: - Clip Preview

struct QUClipPreview: View {
    let clip: QUClip
    @StateObject private var audioPlayer = SimpleAudioPlayer()
    
    private var formattedDuration: String {
        let minutes = Int(clip.duration) / 60
        let seconds = Int(clip.duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Preview Recording")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            
            Button(action: {
                if audioPlayer.isPlaying {
                    audioPlayer.stop()
                } else {
                    audioPlayer.play(fileURL: clip.fileURL)
                }
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: audioPlayer.isPlaying ? [.purple, .pink] : [Color.white.opacity(0.15), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: audioPlayer.isPlaying ? 0 : 3)
                }
            }
            
            Text(formattedDuration)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Song Picker Sheet

struct QUSongPickerSheet: View {
    let songs: [MTSong]
    let onSelect: (MTSong) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    private var filteredSongs: [MTSong] {
        if searchText.isEmpty {
            return songs
        } else {
            return songs.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.artist.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.02, green: 0.04, blue: 0.07)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.white.opacity(0.5))
                        
                        TextField("Search songs", text: $searchText)
                            .foregroundStyle(.white)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                    .padding()
                    
                    // Songs list
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredSongs) { song in
                                Button(action: { onSelect(song) }) {
                                    HStack(spacing: 12) {
                                        AlbumArtView(song: song, size: 50)
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(song.title)
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white)
                                            
                                            Text(song.artist)
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.6))
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.3))
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.05))
                                    )
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Select Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Text Field Style

struct QUTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundStyle(.white)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Processing Overlay

struct QUProcessingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Saving recordings...")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text("This may take a moment")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Simple Audio Player

class SimpleAudioPlayer: ObservableObject {
    @Published var isPlaying = false
    private var player: AVAudioPlayer?
    
    func play(fileURL: String) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(fileURL)
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
            isPlaying = true
            
            // Stop when finished
            DispatchQueue.main.asyncAfter(deadline: .now() + (player?.duration ?? 0)) { [weak self] in
                self?.isPlaying = false
            }
        } catch {
            print("Error playing audio: \(error)")
        }
    }
    
    func stop() {
        player?.stop()
        isPlaying = false
    }
}
