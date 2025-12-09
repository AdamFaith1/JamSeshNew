//
//  AudioMixingService.swift
//  JamSeshNew
//
//  Created by Adam Faith on 2025-11-08.
//

import AVFoundation
import SwiftUI
internal import Combine

@MainActor
final class AudioMixingService: NSObject, ObservableObject {
    @Published var isPlayingBackingTrack = false
    
    private var backingPlayer: AVAudioPlayer?
    private var recorder: AVAudioRecorder?
    private var trackPlayers: [String: AVAudioPlayer] = [:]
    
    // Play a clip as backing track during recording
    func startBackingTrack(fileURL: String, loop: Bool = false) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(fileURL)
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Backing track file not found")
            return
        }
        
        do {
            backingPlayer = try AVAudioPlayer(contentsOf: url)
            backingPlayer?.numberOfLoops = loop ? -1 : 0
            backingPlayer?.volume = 0.7
            backingPlayer?.prepareToPlay()
            backingPlayer?.play()
            isPlayingBackingTrack = true
        } catch {
            print("Failed to play backing track: \(error)")
        }
    }
    
    func stopBackingTrack() {
        backingPlayer?.stop()
        backingPlayer = nil
        isPlayingBackingTrack = false
    }
    
    // Mix multiple audio files into one composition
    func mixComposition(tracks: [CompositionTrack], recordings: [MTRecording], duration: Double) async throws -> URL {
        let composition = AVMutableComposition()
        
        for track in tracks where !track.isMuted {
            guard let recording = recordings.first(where: { $0.id == track.recordingId }),
                  let fileURL = recording.fileURL else { continue }
            
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = docs.appendingPathComponent(fileURL)

            let asset = AVURLAsset(url: url)
            
            let compositionTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            
            guard let assetTrack = try? await asset.loadTracks(withMediaType: .audio).first else { continue }
            
            let startTime = CMTime(seconds: track.startTime, preferredTimescale: 600)
            let assetDuration = try await asset.load(.duration)
            
            // Handle looping if recording is marked as loop
            if recording.isLoop {
                let loopStart = recording.loopStartTime ?? 0
                let loopEnd = recording.loopEndTime ?? assetDuration.seconds
                let loopDuration = loopEnd - loopStart
                
                var currentTime = track.startTime
                while currentTime < duration {
                    let timeRange = CMTimeRange(
                        start: CMTime(seconds: loopStart, preferredTimescale: 600),
                        duration: CMTime(seconds: min(loopDuration, duration - currentTime), preferredTimescale: 600)
                    )
                    
                    try? compositionTrack?.insertTimeRange(
                        timeRange,
                        of: assetTrack,
                        at: CMTime(seconds: currentTime, preferredTimescale: 600)
                    )
                    
                    currentTime += loopDuration
                }
            } else {
                let timeRange = CMTimeRange(start: .zero, duration: assetDuration)
                try? compositionTrack?.insertTimeRange(timeRange, of: assetTrack, at: startTime)
            }
            
            // Apply volume
            let volumeParams = AVMutableAudioMixInputParameters(track: compositionTrack)
            volumeParams.setVolume(track.volume, at: .zero)
            
            let audioMix = AVMutableAudioMix()
            audioMix.inputParameters = [volumeParams]
        }
        
        // Export
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("composition_\(UUID().uuidString).m4a")
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "AudioMixing", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw NSError(domain: "AudioMixing", code: -2, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
        }
        
        return outputURL
    }
    
    // Get waveform data for visualization
    func generateWaveformData(fileURL: String, sampleCount: Int = 100) async -> [Float] {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(fileURL)
        
        guard let file = try? AVAudioFile(forReading: url) else {
            return Array(repeating: 0, count: sampleCount)
        }
        
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return Array(repeating: 0, count: sampleCount)
        }
        
        try? file.read(into: buffer)
        
        guard let floatData = buffer.floatChannelData?[0] else {
            return Array(repeating: 0, count: sampleCount)
        }
        
        let samplesPerBin = Int(frameCount) / sampleCount
        var waveformData: [Float] = []
        
        for i in 0..<sampleCount {
            let startIndex = i * samplesPerBin
            let endIndex = min(startIndex + samplesPerBin, Int(frameCount))
            
            var sum: Float = 0
            for j in startIndex..<endIndex {
                sum += abs(floatData[j])
            }
            
            waveformData.append(sum / Float(samplesPerBin))
        }
        
        return waveformData
    }
    func playMultipleTracks(tracks: [(id: String, fileURL: String, volume: Float, loop: Bool, startTime: Double)]) {
        // Stop any existing playback
        stopAllTracks()
        
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Get the device current time once for synchronization
        let baseTime = AVAudioSession.sharedInstance().outputLatency + ProcessInfo.processInfo.systemUptime
        
        for track in tracks {
            let url = docs.appendingPathComponent(track.fileURL)
            
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("❌ Track file not found: \(url.path)")
                continue
            }
            
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.numberOfLoops = track.loop ? -1 : 0
                player.volume = track.volume
                player.prepareToPlay()
                
                // Schedule all tracks relative to the same base time
                // Add small buffer (0.1s) to ensure all players are prepared
                let playTime = baseTime + 0.1 + track.startTime
                player.play(atTime: playTime)
                
                trackPlayers[track.id] = player
                print("✅ Scheduled track: \(track.id) at +\(track.startTime)s")
            } catch {
                print("❌ Failed to play track: \(error)")
            }
        }
    }

    func stopAllTracks() {
        for player in trackPlayers.values {
            player.stop()
        }
        trackPlayers.removeAll()
    }
}
