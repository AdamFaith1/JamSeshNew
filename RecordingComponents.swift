//
//  RecordingComponents.swift
//  Discography
//
//  Created by Adam Faith on 2025-10-27.
//

import SwiftUI
import AVFoundation
internal import Combine

// MARK: - Color Extension (Hex Color Support)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Audio Recorder with Real-Time Audio Levels
/// A powerful audio recorder class that tracks recording time and audio levels in real-time
/// Perfect for displaying waveform visualizations and recording feedback
class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var isPlaying = false
    @Published var lastRecordingURL: URL?
    @Published var audioLevel: Float = 0.0 // 0.0 to 1.0 for visualizations
    
    // Playback tracking properties
    @Published var playbackTime: TimeInterval = 0
    @Published var recordingDuration: TimeInterval = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var playbackTimer: Timer?
    private var recordingURL: URL?
    
    override init() {
        super.init()
    }
    
    deinit {
        stopRecordingTimer()
        stopLevelTimer()
        stopPlaybackTimer()
    }
    
    /// Start recording audio
    func startRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(UUID().uuidString).m4a"
        recordingURL = documentsPath.appendingPathComponent(fileName)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isRecording = true
            recordingTime = 0
            
            // Start timers
            startRecordingTimer()
            startLevelTimer()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    /// Update audio level for real-time visualization
    private func updateAudioLevel() {
        audioRecorder?.updateMeters()
        let power = audioRecorder?.averagePower(forChannel: 0) ?? -160
        // Convert from dB (-160 to 0) to 0.0-1.0 scale for easy visualization
        let normalized = max(0, (power + 160) / 160)
        audioLevel = normalized
    }
    
    /// Stop recording and return the file URL
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        stopRecordingTimer()
        stopLevelTimer()
        isRecording = false
        audioLevel = 0.0
        lastRecordingURL = recordingURL
        
        // Calculate recording duration
        updateRecordingDuration()
        
        return recordingURL
    }
    
    /// Play the last recording
    func playRecording() {
        guard let url = lastRecordingURL else { return }
        
        do {
            // Initialize or reuse player
            if audioPlayer == nil || audioPlayer?.url != url {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.delegate = self
                audioPlayer?.prepareToPlay()
            }
            
            audioPlayer?.play()
            isPlaying = true
            
            // Start playback timer
            startPlaybackTimer()
            
        } catch {
            print("Failed to play recording: \(error)")
        }
    }
    
    /// Stop playback
    func stopPlaying() {
        audioPlayer?.pause()
        isPlaying = false
        stopPlaybackTimer()
    }
    
    /// Seek to a specific time in the recording
    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        
        // Validate seek time
        let seekTime = max(0, min(time, player.duration))
        
        // Seek to position
        player.currentTime = seekTime
        playbackTime = seekTime
        
        // Resume playing if it was playing
        if isPlaying {
            player.play()
        }
    }
    
    // MARK: - Duration Calculation
    private func updateRecordingDuration() {
        guard let url = lastRecordingURL else {
            recordingDuration = 0
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            recordingDuration = player.duration
        } catch {
            print("Error getting audio duration: \(error)")
            recordingDuration = 0
        }
    }
    
    // MARK: - Timer Management
    private func startRecordingTimer() {
        stopRecordingTimer()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingTime += 0.1
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func startLevelTimer() {
        stopLevelTimer()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateAudioLevel()
        }
    }
    
    private func stopLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    private func startPlaybackTimer() {
        stopPlaybackTimer()
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self,
                  let player = self.audioPlayer else { return }
            
            self.playbackTime = player.currentTime
            
            // Auto-stop at end
            if player.currentTime >= player.duration {
                self.stopPlaying()
                self.playbackTime = 0
            }
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioRecorder: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            self?.playbackTime = 0
            self?.stopPlaybackTimer()
        }
    }
}

// MARK: - Recording Button with Pulsing Effect
/// A beautiful record button with pulsing animation when recording
struct SimpleRecordButton: View {
    let isRecording: Bool
    let onTap: () -> Void
    @State private var pulseAnimation = false
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Outer pulse ring when recording
                if isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 4)
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                        .opacity(pulseAnimation ? 0 : 1)
                        .frame(width: 80, height: 80)
                }
                
                // Main button
                Circle()
                    .fill(isRecording ? Color.red : Color.white)
                    .frame(width: 70, height: 70)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                    )
                    .shadow(color: isRecording ? .red.opacity(0.5) : .black.opacity(0.3),
                            radius: 10)
            }
        }
        .onChange(of: isRecording) { newValue in
            if newValue {
                withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    pulseAnimation = true
                }
            } else {
                pulseAnimation = false
            }
        }
    }
}

// MARK: - Audio Waveform Visualizer
/// Real-time waveform visualization bars
struct WaveformVisualizer: View {
    let audioLevel: Float
    let barCount: Int = 20
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3)
                    .frame(height: barHeight(for: index))
                    .animation(.easeOut(duration: 0.1), value: audioLevel)
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let normalizedIndex = CGFloat(index) / CGFloat(barCount)
        let symmetricIndex = abs(normalizedIndex - 0.5) * 2
        let randomFactor = CGFloat.random(in: 0.7...1.0)
        let baseHeight: CGFloat = 10
        let maxHeight: CGFloat = 60
        
        let height = baseHeight + (CGFloat(audioLevel) * (1 - symmetricIndex) * randomFactor * (maxHeight - baseHeight))
        return max(baseHeight, height)
    }
}

// MARK: - Recording Timer Display
/// Displays recording time in MM:SS format
struct RecordingTimerView: View {
    let time: TimeInterval
    
    var formattedTime: String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            
            Text(formattedTime)
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.3))
        )
    }
}

// MARK: - Part Selector Component
/// Dropdown selector for choosing which song part to record
struct PartSelector: View {
    let song: MTSong
    @Binding var selectedPart: MTSongPart?
    let onAddPart: (String) -> MTSongPart
    @State private var isExpanded = false
    
    let standardParts = ["Intro", "Verse", "Chorus", "Bridge", "Solo", "Outro",
                         "Vocals", "Lead Guitar", "Rhythm Guitar", "Bass", "Drums", "Keys"]
    
    var body: some View {
        VStack(spacing: 10) {
            // Selected part display
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(selectedPart?.name ?? "Select a part...")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(selectedPart == nil ? .white.opacity(0.4) : .white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            // Part options dropdown
            if isExpanded {
                ScrollView {
                    VStack(spacing: 8) {
                        // Existing parts
                        if !song.parts.isEmpty {
                            ForEach(song.parts) { part in
                                PartOptionButton(
                                    title: part.name,
                                    isSelected: selectedPart?.id == part.id,
                                    isExisting: true
                                ) {
                                    selectedPart = part
                                    withAnimation(.spring(response: 0.3)) {
                                        isExpanded = false
                                    }
                                }
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.2))
                                .padding(.vertical, 6)
                        }
                        
                        // Add new part options
                        ForEach(standardParts, id: \.self) { partName in
                            PartOptionButton(
                                title: partName,
                                isSelected: false,
                                isExisting: false
                            ) {
                                let newPart = onAddPart(partName)
                                selectedPart = newPart
                                withAnimation(.spring(response: 0.3)) {
                                    isExpanded = false
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
                .padding(.top, 6)
            }
        }
    }
}

// MARK: - Part Option Button
private struct PartOptionButton: View {
    let title: String
    let isSelected: Bool
    let isExisting: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isExisting ? .white : .white.opacity(0.7))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.pink)
                } else if !isExisting {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.purple.opacity(0.6))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isExisting ? Color.white.opacity(0.1) : Color.white.opacity(0.05))
            )
        }
    }
}

// MARK: - Action Buttons (Play, Save, Discard, Re-record)
struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
                
                Text(label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(color.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(color.opacity(0.4), lineWidth: 2)
                    )
            )
        }
    }
}


