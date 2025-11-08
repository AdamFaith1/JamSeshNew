import SwiftUI
import SwiftData
import AVFoundation
internal import Combine
import UIKit

// MARK: - Recording Manager (Kept for backward compatibility with AudioPlaybackManager)
@MainActor
final class RecordingManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingType: MTRecording.RecordingType = .audio
    @Published var currentRecordingDuration: TimeInterval = 0
    @Published var permissionStatus: PermissionStatus = .notDetermined
    @Published var recordingLevel: Float = 0.0

    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var durationTimer: Timer?
    private var currentRecordingURL: URL?

    enum PermissionStatus { case notDetermined, authorized, denied }

    enum RecordingError: LocalizedError {
        case permissionDenied, recordingFailed, fileCreationFailed
        var errorDescription: String? {
            switch self {
            case .permissionDenied: return "Recording permission denied. Please enable microphone access in Settings."
            case .recordingFailed:  return "Recording failed. Please try again."
            case .fileCreationFailed: return "Failed to save recording file."
            }
        }
    }

    override init() {
        super.init()
        configureSessionForRecordAndSpeaker()
        checkPermissions()
    }

    private func configureSessionForRecordAndSpeaker() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord,
                                    mode: .default,
                                    options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            try session.overrideOutputAudioPort(.speaker)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    func requestPermissions() async {
        let session = AVAudioSession.sharedInstance()
        let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            session.requestRecordPermission { cont.resume(returning: $0) }
        }
        permissionStatus = granted ? .authorized : .denied
    }

    func checkPermissions() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted: permissionStatus = .authorized
        case .denied:  permissionStatus = .denied
        case .undetermined: permissionStatus = .notDetermined
        @unknown default: permissionStatus = .notDetermined
        }
    }

    func startAudioRecording() async throws {
        if permissionStatus != .authorized {
            await requestPermissions()
            guard permissionStatus == .authorized else { throw RecordingError.permissionDenied }
        }

        configureSessionForRecordAndSpeaker()

        let url = getDocumentsDirectory().appendingPathComponent("\(UUID().uuidString).m4a")
        currentRecordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let rec = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder = rec
            rec.delegate = self
            rec.isMeteringEnabled = true
            rec.record()

            isRecording = true
            recordingType = .audio
            currentRecordingDuration = 0
            startTimers()
        } catch {
            throw RecordingError.recordingFailed
        }
    }

    func stopAudioRecording() -> URL? {
        audioRecorder?.stop()
        isRecording = false
        stopTimers()
        return currentRecordingURL
    }

    private func startTimers() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.audioRecorder?.updateMeters()
                let level = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
                let normalized = max(0, (level + 60) / 60)
                self.recordingLevel = normalized
            }
        }
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.currentRecordingDuration = self.audioRecorder?.currentTime ?? 0
            }
        }
    }

    private func stopTimers() {
        levelTimer?.invalidate(); levelTimer = nil
        durationTimer?.invalidate(); durationTimer = nil
        recordingLevel = 0
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

extension RecordingManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        isRecording = false
        stopTimers()
    }
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        isRecording = false
        stopTimers()
        print("Audio recording error: \(error?.localizedDescription ?? "Unknown error")")
    }
}

// MARK: - Audio Playback Manager
@MainActor
final class AudioPlaybackManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentlyPlayingId: String?
    @Published var playbackProgress: Double = 0
    @Published var playbackDuration: Double = 0

    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?

    override init() {
        super.init()
    }

    private func configureSessionForSpeakerPlayback() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord,
                                    mode: .default,
                                    options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            try session.overrideOutputAudioPort(.speaker)
        } catch {
            print("Playback session config failed: \(error)")
        }
    }

    func playRecording(id: String, fileURL: String) {
        if currentlyPlayingId == id {
            if isPlaying { pausePlayback() } else { resumePlayback() }
            return
        }

        stopPlayback()
        configureSessionForSpeakerPlayback()

        guard let url = getRecordingURL(filename: fileURL) else {
            print("Could not find recording file: \(fileURL)")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            audioPlayer = player
            player.delegate = self
            player.prepareToPlay()

            playbackDuration = player.duration
            currentlyPlayingId = id

            if player.play() {
                isPlaying = true
                startPlaybackTimer()
            }
        } catch {
            print("Error playing audio: \(error)")
        }
    }

    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        stopPlaybackTimer()
    }

    func resumePlayback() {
        if audioPlayer?.play() == true {
            isPlaying = true
            startPlaybackTimer()
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentlyPlayingId = nil
        playbackProgress = 0
        playbackDuration = 0
        stopPlaybackTimer()
    }

    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let player = self.audioPlayer else { return }
            Task { @MainActor in
                self.playbackProgress = player.duration > 0 ? player.currentTime / player.duration : 0
            }
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func getRecordingURL(filename: String) -> URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func deleteRecording(filename: String) {
        guard let url = getRecordingURL(filename: filename) else { return }
        do { try FileManager.default.removeItem(at: url) }
        catch { print("Error deleting recording file: \(error)") }
    }

    func getRecordingDuration(filename: String) -> TimeInterval? {
        guard let url = getRecordingURL(filename: filename) else { return nil }
        return try? AVAudioPlayer(contentsOf: url).duration
    }

    func formatTime(_ t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

extension AudioPlaybackManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentlyPlayingId = nil
        playbackProgress = 0
        stopPlaybackTimer()
    }
}

// MARK: - Song detail
struct ModernSongDetailView: View {
    let songId: String
    @ObservedObject var viewModel: MusicViewModel
    @Environment(\.modelContext) private var modelContext
    @StateObject private var audioPlaybackManager = AudioPlaybackManager()

    @State private var showingRecordingView = false
    @State private var showingAddPart = false
    @State private var showingDeleteConfirmation = false
    @State private var dragOffset: CGFloat = 0
    
    @GestureState private var dragState: DragState = .inactive
    @State private var draggedPartId: String?
    @State private var targetDropIndex: Int?

    private var liveSong: MTSong? { viewModel.songs.first { $0.id == songId } }
    
    enum DragState {
        case inactive
        case dragging(translation: CGSize)
        
        var translation: CGSize {
            switch self {
            case .inactive:
                return .zero
            case .dragging(let t):
                return t
            }
        }
        
        var isDragging: Bool {
            switch self {
            case .inactive:
                return false
            case .dragging:
                return true
            }
        }
    }
    
    private func partsWithNumberedDuplicates(_ parts: [MTSongPart]) -> [(part: MTSongPart, displayName: String)] {
        var nameCounts: [String: Int] = [:]
        var nameIndices: [String: Int] = [:]
        
        for part in parts {
            nameCounts[part.name, default: 0] += 1
        }
        
        return parts.map { part in
            let count = nameCounts[part.name] ?? 1
            if count > 1 {
                nameIndices[part.name, default: 0] += 1
                let index = nameIndices[part.name] ?? 1
                return (part, "\(part.name) \(index)")
            } else {
                return (part, part.name)
            }
        }
    }
    
    private func reorderPart(fromIndex: Int, toIndex: Int) {
        guard let song = liveSong else { return }
        guard fromIndex != toIndex else { return }
        guard fromIndex >= 0 && fromIndex < song.parts.count else { return }
        guard toIndex >= 0 && toIndex < song.parts.count else { return }
        
        Task {
            do {
                let descriptor = FetchDescriptor<SDSong>(predicate: #Predicate<SDSong> { $0.id == song.id })
                if let sdSong = try modelContext.fetch(descriptor).first {
                    var updatedParts = sdSong.parts
                    let movedPart = updatedParts.remove(at: fromIndex)
                    updatedParts.insert(movedPart, at: toIndex)
                    sdSong.parts = updatedParts
                    try modelContext.save()
                    
                    if let idx = viewModel.songs.firstIndex(where: { $0.id == song.id }) {
                        var newParts = viewModel.songs[idx].parts
                        let movedMemPart = newParts.remove(at: fromIndex)
                        newParts.insert(movedMemPart, at: toIndex)
                        viewModel.songs[idx].parts = newParts
                    }
                }
            } catch {
                print("Failed to reorder parts: \(error)")
            }
        }
    }

    var body: some View {
        Group {
            if let song = liveSong {
                ZStack {
                    // Background gradient
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
                        // Compact Header
                        HStack(spacing: 12) {
                            Button { viewModel.selectedSongId = nil } label: {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            
                            // Album art (smaller)
                            ZStack {
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.6, green: 0.2, blue: 0.8),
                                        Color(red: 0.8, green: 0.3, blue: 0.5)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                
                                if let artworkURLString = song.artworkURL, !artworkURLString.isEmpty {
                                    if !artworkURLString.hasPrefix("http"),
                                       let data = Data(base64Encoded: artworkURLString),
                                       let image = UIImage(data: data) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                    } else if let url = URL(string: artworkURLString) {
                                        AsyncImage(url: url) { phase in
                                            if case .success(let image) = phase {
                                                image.resizable().scaledToFill()
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            
                            // Song info
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
                            
                            Menu {
                                Button("Delete Song", role: .destructive) {
                                    showingDeleteConfirmation = true
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.3))

                        ScrollView {
                            VStack(spacing: 16) {
                                let numberedParts = partsWithNumberedDuplicates(song.parts)
                                
                                ForEach(numberedParts, id: \.part.id) { item in
                                    let index = numberedParts.firstIndex(where: { $0.part.id == item.part.id }) ?? 0
                                    let isDragged = draggedPartId == item.part.id
                                    let draggedIndex = numberedParts.firstIndex(where: { $0.part.id == draggedPartId })
                                    let targetIndex: Int? = {
                                        guard let draggedIdx = draggedIndex else { return nil }
                                        let cardHeight: CGFloat = 180
                                        let offset = dragState.translation.height
                                        let indexOffset = Int(round(offset / cardHeight))
                                        return max(0, min(numberedParts.count - 1, draggedIdx + indexOffset))
                                    }()
                                    
                                    let itemOffset: CGFloat = {
                                        guard let draggedIdx = draggedIndex,
                                              let targetIdx = targetIndex,
                                              !isDragged else { return 0 }
                                        
                                        if draggedIdx < targetIdx && index > draggedIdx && index <= targetIdx {
                                            return -180
                                        } else if draggedIdx > targetIdx && index < draggedIdx && index >= targetIdx {
                                            return 180
                                        }
                                        return 0
                                    }()
                                    
                                    CleanPartCard(
                                        part: item.part,
                                        displayName: item.displayName,
                                        isExpanded: viewModel.expandedParts.contains(item.part.id),
                                        onToggle: { viewModel.togglePart(item.part.id) },
                                        onRecord: { showingRecordingView = true },
                                        onPlay: { rec in
                                            guard let file = rec.fileURL else { return }
                                            audioPlaybackManager.playRecording(id: rec.id, fileURL: file)
                                        },
                                        onDelete: { rec in
                                            if audioPlaybackManager.currentlyPlayingId == rec.id {
                                                audioPlaybackManager.stopPlayback()
                                            }
                                            Task {
                                                await viewModel.deleteRecording(context: modelContext, songId: song.id, partId: item.part.id, recordingId: rec.id)
                                                if let file = rec.fileURL { audioPlaybackManager.deleteRecording(filename: file) }
                                            }
                                        },
                                        onDeletePart: {
                                            Task { await viewModel.deletePart(context: modelContext, song: song, part: item.part) }
                                        },
                                        audioPlaybackManager: audioPlaybackManager
                                    )
                                    .id(item.part.id)
                                    .opacity(isDragged && dragState.isDragging ? 0.8 : 1.0)
                                    .offset(y: isDragged ? dragState.translation.height : itemOffset)
                                    .scaleEffect(isDragged && dragState.isDragging ? 1.03 : 1.0)
                                    .zIndex(isDragged ? 1000 : Double(index))
                                    .shadow(color: isDragged && dragState.isDragging ? .black.opacity(0.3) : .clear, radius: 12, y: 6)
                                    .gesture(
                                        LongPressGesture(minimumDuration: 0.5)
                                            .sequenced(before: DragGesture())
                                            .updating($dragState) { value, state, _ in
                                                switch value {
                                                case .second(true, let drag):
                                                    state = .dragging(translation: drag?.translation ?? .zero)
                                                default:
                                                    break
                                                }
                                            }
                                            .onChanged { value in
                                                switch value {
                                                case .second(true, let drag):
                                                    if draggedPartId == nil {
                                                        draggedPartId = item.part.id
                                                        let generator = UIImpactFeedbackGenerator(style: .medium)
                                                        generator.impactOccurred()
                                                    }
                                                    if let drag = drag, let draggedIdx = draggedIndex {
                                                        let cardHeight: CGFloat = 180
                                                        let offset = drag.translation.height
                                                        let indexOffset = Int(round(offset / cardHeight))
                                                        targetDropIndex = max(0, min(numberedParts.count - 1, draggedIdx + indexOffset))
                                                    }
                                                default:
                                                    break
                                                }
                                            }
                                            .onEnded { value in
                                                switch value {
                                                case .second(true, _):
                                                    if let draggedIdx = draggedIndex,
                                                       let targetIdx = targetDropIndex {
                                                        reorderPart(fromIndex: draggedIdx, toIndex: targetIdx)
                                                    }
                                                default:
                                                    break
                                                }
                                                draggedPartId = nil
                                                targetDropIndex = nil
                                            }
                                    )
                                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: dragState.translation)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: draggedPartId)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: itemOffset)
                                }

                                // Add New Part Button
                                Button { showingAddPart = true } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [.purple, .pink],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                        
                                        Text("Add New Part")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        
                                        Spacer()
                                    }
                                    .padding(20)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(0.05))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [.purple.opacity(0.4), .pink.opacity(0.3)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 1.5
                                                    )
                                            )
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                                
                                Spacer(minLength: 20)
                            }
                            .padding()
                        }
                    }
                    .offset(x: dragOffset > 0 ? dragOffset : 0)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.width > 0 {
                                    dragOffset = value.translation.width
                                }
                            }
                            .onEnded { value in
                                if value.translation.width > 100 {
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        viewModel.selectedSongId = nil
                                    }
                                    dragOffset = 0
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
                }
                .fullScreenCover(isPresented: $showingRecordingView) {
                    if let currentSong = self.liveSong {
                        RecordingView(viewModel: viewModel)
                    }
                }
                .sheet(isPresented: $showingAddPart) {
                    AddPartView(isPresented: $showingAddPart) { name, status in
                        Task { await viewModel.addPart(context: modelContext, to: song, name: name, status: status) }
                        showingAddPart = false
                    }
                }
                .alert("Delete Song", isPresented: $showingDeleteConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) {
                        Task {
                            await viewModel.deleteSong(context: modelContext, song: song)
                            await MainActor.run { viewModel.selectedSongId = nil }
                        }
                    }
                } message: {
                    Text("Are you sure you want to delete \"\(song.title)\" by \(song.artist)? This will permanently delete the song and all its recordings.")
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 48)).foregroundStyle(.orange)
                    Text("Song not found").font(.headline).foregroundStyle(.white)
                    Button("Back to Collection") { viewModel.selectedSongId = nil }
                        .foregroundStyle(.purple)
                }
                .padding()
            }
        }
    }
}

// MARK: - Clean Part Card (New simplified design)
struct CleanPartCard: View {
    let part: MTSongPart
    let displayName: String
    let isExpanded: Bool
    let onToggle: () -> Void
    let onRecord: () -> Void
    let onPlay: (MTRecording) -> Void
    let onDelete: (MTRecording) -> Void
    let onDeletePart: () -> Void
    @ObservedObject var audioPlaybackManager: AudioPlaybackManager
    
    @State private var showingDeletePartAlert = false
    @State private var showingDeleteRecordingAlert = false
    @State private var recordingToDelete: MTRecording?

    private var isComplete: Bool { part.status == .complete }
    private var statusColor: Color { isComplete ? .green : .orange }
    
    private var mostRecentRecording: MTRecording? {
        part.recordings.sorted(by: { $0.date > $1.date }).first
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with part name and status
            HStack(spacing: 12) {
                // Status indicator circle
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                    .shadow(color: statusColor.opacity(0.5), radius: 4)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 6) {
                        Text(isComplete ? "Complete" : "Learning")
                            .font(.caption)
                            .foregroundStyle(statusColor.opacity(0.9))
                        
                        if !part.recordings.isEmpty {
                            Text("•")
                                .foregroundStyle(.white.opacity(0.3))
                            Text("\(part.recordings.count) recording\(part.recordings.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                
                Spacer()
                
                Menu {
                    Button("Delete Part", role: .destructive) {
                        showingDeletePartAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 32, height: 32)
                }
            }
            .padding(20)
            
            // Action buttons
            VStack(spacing: 12) {
                // Play most recent (if exists)
                if let recent = mostRecentRecording, let fileURL = recent.fileURL {
                    Button {
                        audioPlaybackManager.playRecording(id: recent.id, fileURL: fileURL)
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.pink, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 56, height: 56)
                                
                                Image(systemName: audioPlaybackManager.currentlyPlayingId == recent.id && audioPlaybackManager.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .offset(x: audioPlaybackManager.currentlyPlayingId == recent.id && audioPlaybackManager.isPlaying ? 0 : 2)
                            }
                            .shadow(color: .pink.opacity(0.4), radius: 8, y: 4)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Most Recent")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                
                                Text(formatRecordingDate(recent.date))
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.06))
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                
                // Record new button
                Button(action: onRecord) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [statusColor, statusColor.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: "waveform")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: statusColor.opacity(0.4), radius: 8, y: 4)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Record")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            Text("Add new take")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                
                // View history button (if recordings exist)
                if !part.recordings.isEmpty {
                    Button(action: onToggle) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.caption)
                            
                            Text(isExpanded ? "Hide History" : "View History")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(part.recordings.count)")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                            
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        }
                        .foregroundStyle(.purple.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.purple.opacity(0.1))
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            // Recording history (expanded)
            if isExpanded && !part.recordings.isEmpty {
                VStack(spacing: 0) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    VStack(spacing: 10) {
                        let sortedRecordings = part.recordings.sorted(by: { $0.date > $1.date })
                        ForEach(sortedRecordings) { rec in
                            MinimalRecordingRow(
                                recording: rec,
                                isCurrentlyPlaying: audioPlaybackManager.currentlyPlayingId == rec.id && audioPlaybackManager.isPlaying,
                                onPlay: { onPlay(rec) },
                                onDelete: {
                                    recordingToDelete = rec
                                    showingDeleteRecordingAlert = true
                                },
                                audioPlaybackManager: audioPlaybackManager
                            )
                        }
                    }
                    .padding(20)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(statusColor.opacity(0.2), lineWidth: 1)
                )
        )
        .alert("Delete Part", isPresented: $showingDeletePartAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDeletePart()
            }
        } message: {
            Text("Are you sure you want to delete this part? All recordings for this part will be permanently deleted.")
        }
        .alert("Delete Recording", isPresented: $showingDeleteRecordingAlert) {
            Button("Cancel", role: .cancel) {
                recordingToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let recording = recordingToDelete {
                    onDelete(recording)
                }
                recordingToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this recording?")
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isExpanded)
    }
}

// MARK: - Minimal Recording Row

struct MinimalRecordingRow: View {
    let recording: MTRecording
    let isCurrentlyPlaying: Bool
    let onPlay: () -> Void
    let onDelete: () -> Void
    let audioPlaybackManager: AudioPlaybackManager
    
    @State private var showingLoopEditor = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.6), .pink.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: isCurrentlyPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: isCurrentlyPlaying ? 0 : 1)
                }
            }
            .scaleEffect(isCurrentlyPlaying ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isCurrentlyPlaying)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(formatRecordingDate(recording.date))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                    
                    if let fileURL = recording.fileURL,
                       let duration = audioPlaybackManager.getRecordingDuration(filename: fileURL) {
                        Text("•")
                            .foregroundStyle(.white.opacity(0.3))
                        Text(audioPlaybackManager.formatTime(duration))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    
                    if recording.isLoop {
                        Text("•")
                            .foregroundStyle(.white.opacity(0.3))
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
                
                if !recording.note.isEmpty {
                    Text(recording.note)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if recording.isLoop {
                Button {
                    showingLoopEditor = true
                } label: {
                    Image(systemName: "waveform.badge.magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.purple)
                        .frame(width: 32, height: 32)
                }
            }
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.7))
                    .frame(width: 32, height: 32)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
        .sheet(isPresented: $showingLoopEditor) {
            LoopEditorSheet(recording: .constant(recording)) { updatedRecording in
                // Note: You'll need to pass an update callback from parent
            }
        }
    }
}

// MARK: - Add Part View
struct AddPartView: View {
    @Binding var isPresented: Bool
    let onSave: (String, MTSongPart.PartStatus) -> Void

    @State private var newPartName = "Intro"
    @State private var newPartStatus: MTSongPart.PartStatus = .learning

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.02, green: 0.04, blue: 0.07),
                                    Color(red: 0.15, green: 0.02, blue: 0.2),
                                    Color(red: 0.02, green: 0.04, blue: 0.07)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { isPresented = false } label: {
                        HStack(spacing: 8) { Image(systemName: "xmark"); Text("Cancel") }.foregroundStyle(.purple)
                    }
                    Spacer()
                    Text("Add Part").font(.headline).foregroundStyle(.white)
                    Spacer()
                    Button("Add") { onSave(newPartName, newPartStatus) }
                        .foregroundStyle(.green).fontWeight(.semibold)
                }
                .padding()
                .background(Color.purple.opacity(0.05))
                .overlay(Rectangle().fill(Color.purple.opacity(0.2)).frame(height: 1), alignment: .bottom)

                ScrollView {
                    VStack(spacing: 32) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SELECT PART TYPE").font(.caption).fontWeight(.bold).foregroundStyle(.purple.opacity(0.8))
                            let names = StandardSongPart.displayNames
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    ForEach(Array(names.prefix(3)), id: \.self) { title in
                                        SongPartTypeButton(title: title, isSelected: newPartName == title) {
                                            newPartName = title
                                        }
                                    }
                                }
                                HStack(spacing: 8) {
                                    ForEach(Array(names.dropFirst(3)), id: \.self) { title in
                                        SongPartTypeButton(title: title, isSelected: newPartName == title) {
                                            newPartName = title
                                        }
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("PROGRESS STATUS").font(.caption).fontWeight(.bold).foregroundStyle(.purple.opacity(0.8))
                            HStack(spacing: 12) {
                                Button {
                                    newPartStatus = .learning
                                } label: {
                                    VStack(spacing: 12) {
                                        Image(systemName: "clock.fill").font(.system(size: 32))
                                        Text("Learning").fontWeight(.bold)
                                    }
                                    .foregroundStyle(newPartStatus == .learning ? .white : .orange)
                                    .frame(maxWidth: .infinity).padding(.vertical, 24)
                                    .background(newPartStatus == .learning ? AnyView(LinearGradient(colors: [.orange, Color(red: 1, green: 0.4, blue: 0)], startPoint: .leading, endPoint: .trailing)) : AnyView(Color.orange.opacity(0.1)))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.4), lineWidth: newPartStatus == .learning ? 3 : 1))
                                    .cornerRadius(16)
                                }
                                Button {
                                    newPartStatus = .complete
                                } label: {
                                    VStack(spacing: 12) {
                                        Image(systemName: "checkmark.circle.fill").font(.system(size: 32))
                                        Text("Complete").fontWeight(.bold)
                                    }
                                    .foregroundStyle(newPartStatus == .complete ? .white : .green)
                                    .frame(maxWidth: .infinity).padding(.vertical, 24)
                                    .background(newPartStatus == .complete ? AnyView(LinearGradient(colors: [.green, Color(red: 0, green: 0.7, blue: 0)], startPoint: .leading, endPoint: .trailing)) : AnyView(Color.green.opacity(0.1)))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.4), lineWidth: newPartStatus == .complete ? 3 : 1))
                                    .cornerRadius(16)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("PREVIEW").font(.caption).fontWeight(.bold).foregroundStyle(.purple.opacity(0.8))
                            HStack(spacing: 12) {
                                Image(systemName: newPartStatus == .complete ? "checkmark.circle.fill" : "clock.fill")
                                    .font(.title2).foregroundStyle(.white)
                                    .frame(width: 48, height: 48)
                                    .background(newPartStatus == .complete ?
                                                LinearGradient(colors: [.green, Color(red: 0, green: 0.7, blue: 0)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                                LinearGradient(colors: [.orange, Color(red: 1, green: 0.4, blue: 0)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .cornerRadius(12)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(newPartName).font(.headline).fontWeight(.black).foregroundStyle(.white)
                                    Text(newPartStatus == .complete ? "Complete" : "Learning")
                                        .font(.caption).fontWeight(.bold)
                                        .foregroundStyle(newPartStatus == .complete ? .green : .orange)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(newPartStatus == .complete ?
                                        LinearGradient(colors: [.green.opacity(0.2), .green.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                        LinearGradient(colors: [.orange.opacity(0.2), .orange.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(newPartStatus == .complete ? Color.green.opacity(0.4) : Color.orange.opacity(0.4), lineWidth: 2))
                        }
                    }
                    .padding(24)
                }
            }
        }
    }
}

// MARK: - Part Type Button
struct SongPartTypeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body).fontWeight(.semibold)
                .foregroundStyle(isSelected ? .white : .purple.opacity(0.8))
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(isSelected ? AnyView(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)) : AnyView(Color.purple.opacity(0.1)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.4), lineWidth: isSelected ? 2 : 1))
                .cornerRadius(12)
        }
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Shared Date Formatting Helpers
fileprivate func formatRecordingDate(_ date: Date) -> String {
    let calendar = Calendar.current
    let now = Date()

    if calendar.isDateInToday(date) {
        return "Today"
    } else if calendar.isDateInYesterday(date) {
        return "Yesterday"
    } else if calendar.isDate(date, equalTo: now, toGranularity: .year) {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    } else {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

fileprivate func formatRecordingTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
}
