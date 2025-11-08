//
//  LoopEditor.swift
//  JamSeshNew
//
//  Created by Adam Faith on 2025-11-08.
//

import SwiftUI
import AVFoundation

struct LoopEditorSheet: View {
    @Binding var recording: MTRecording
    let onSave: (MTRecording) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var audioMixing = AudioMixingService()
    @StateObject private var audioPlayer = AudioPlaybackManager()
    
    @State private var waveformData: [Float] = []
    @State private var isLoadingWaveform = true
    @State private var duration: Double = 0
    @State private var loopStart: Double
    @State private var loopEnd: Double
    @State private var isPlaying = false
    
    init(recording: Binding<MTRecording>, onSave: @escaping (MTRecording) -> Void) {
        self._recording = recording
        self.onSave = onSave
        _loopStart = State(initialValue: recording.wrappedValue.loopStartTime ?? 0)
        _loopEnd = State(initialValue: recording.wrappedValue.loopEndTime ?? 0)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.02, green: 0.04, blue: 0.07)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Waveform display
                    VStack(spacing: 16) {
                        if isLoadingWaveform {
                            ProgressView("Analyzing audio...")
                                .tint(.purple)
                        } else {
                            WaveformView(
                                waveformData: waveformData,
                                loopStart: $loopStart,
                                loopEnd: $loopEnd,
                                duration: duration
                            )
                            .frame(height: 180)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                    )
                    .padding(.horizontal)
                    
                    // Loop controls
                    VStack(spacing: 16) {
                        LoopTimeControl(
                            label: "Loop Start",
                            time: $loopStart,
                            maxTime: loopEnd,
                            color: .green
                        )
                        
                        LoopTimeControl(
                            label: "Loop End",
                            time: $loopEnd,
                            maxTime: duration,
                            color: .red
                        )
                    }
                    .padding(.horizontal)
                    
                    // Playback controls
                    HStack(spacing: 20) {
                        Button {
                            loopStart = 0
                            loopEnd = duration
                        } label: {
                            Text("Reset")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }
                        
                        Spacer()
                        
                        Button {
                            if isPlaying {
                                audioPlayer.stopPlayback()
                                isPlaying = false
                            } else {
                                playLoop()
                            }
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
                                    .frame(width: 64, height: 64)
                                
                                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            saveLoop()
                        } label: {
                            Text("Save")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [.green, Color(red: 0, green: 0.7, blue: 0)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    
                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle("Edit Loop")
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
        .task {
            await loadWaveform()
        }
    }
    
    private func loadWaveform() async {
        guard let fileURL = recording.fileURL else { return }
        
        waveformData = await audioMixing.generateWaveformData(fileURL: fileURL, sampleCount: 100)
        
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(fileURL)
        
        if let player = try? AVAudioPlayer(contentsOf: url) {
            duration = player.duration
            if loopEnd == 0 {
                loopEnd = duration
            }
        }
        
        isLoadingWaveform = false
    }
    
    private func playLoop() {
        guard let fileURL = recording.fileURL else { return }
        audioPlayer.playRecording(id: recording.id, fileURL: fileURL)
        isPlaying = true
        
        // Stop after loop duration
        let loopDuration = loopEnd - loopStart
        DispatchQueue.main.asyncAfter(deadline: .now() + loopDuration) {
            audioPlayer.stopPlayback()
            isPlaying = false
        }
    }
    
    private func saveLoop() {
        var updatedRecording = recording
        updatedRecording.isLoop = true
        updatedRecording.loopStartTime = loopStart
        updatedRecording.loopEndTime = loopEnd
        
        onSave(updatedRecording)
        dismiss()
    }
}

// MARK: - Waveform View
struct WaveformView: View {
    let waveformData: [Float]
    @Binding var loopStart: Double
    @Binding var loopEnd: Double
    let duration: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Waveform bars
                HStack(spacing: 2) {
                    ForEach(0..<waveformData.count, id: \.self) { index in
                        let normalizedTime = Double(index) / Double(waveformData.count) * duration
                        let isInLoop = normalizedTime >= loopStart && normalizedTime <= loopEnd
                        
                        Rectangle()
                            .fill(isInLoop ? Color.purple : Color.white.opacity(0.3))
                            .frame(width: (geometry.size.width / CGFloat(waveformData.count)) - 2)
                            .frame(height: CGFloat(waveformData[index]) * geometry.size.height * 0.8)
                    }
                }
                .frame(maxHeight: .infinity)
                
                // Loop start marker
                Rectangle()
                    .fill(Color.green)
                    .frame(width: 3)
                    .offset(x: CGFloat(loopStart / duration) * geometry.size.width)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newStart = Double(value.location.x / geometry.size.width) * duration
                                loopStart = max(0, min(newStart, loopEnd - 0.1))
                            }
                    )
                
                // Loop end marker
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 3)
                    .offset(x: CGFloat(loopEnd / duration) * geometry.size.width)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newEnd = Double(value.location.x / geometry.size.width) * duration
                                loopEnd = max(loopStart + 0.1, min(newEnd, duration))
                            }
                    )
            }
        }
    }
}

// MARK: - Loop Time Control
struct LoopTimeControl: View {
    let label: String
    @Binding var time: Double
    let maxTime: Double
    let color: Color
    
    private func formatTime(_ t: Double) -> String {
        String(format: "%d:%02d.%01d", Int(t) / 60, Int(t) % 60, Int((t.truncatingRemainder(dividingBy: 1)) * 10))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
                
                Text(formatTime(time))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(color.opacity(0.2))
                    )
            }
            
            Slider(value: $time, in: 0...maxTime)
                .tint(color)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}
