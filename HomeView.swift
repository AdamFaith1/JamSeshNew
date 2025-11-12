//
//  HomeView.swift
//  JamSeshNew
//
//  Created by Adam Faith on 2025-11-09.
//

// HomeView.swift
import SwiftUI
import SwiftData
import AVFoundation

// MARK: - Home View
struct HomeView: View {
    @ObservedObject var viewModel: MusicViewModel
    @Environment(\.modelContext) private var modelContext
    @StateObject private var audioPlayer = AudioPlaybackManager()
    
    @State private var selectedTimeFrame: TimeFrame = .week
    @State private var animateProgress = false
    @State private var pulseAnimation = false
    @State private var showingRecordSheet = false
    
    enum TimeFrame: String, CaseIterable {
        case today = "Today"
        case week = "Week"
        case month = "Month"
        case all = "All Time"
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Header with greeting
                HomeHeaderView()
                    .padding(.horizontal)
                
                // Main Stats Card - Big, satisfying progress visualization
                HeroStatsCard(viewModel: viewModel, animateProgress: $animateProgress)
                    .padding(.horizontal)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.5).delay(0.3)) {
                            animateProgress = true
                        }
                    }
                
                // Activity Heat Map
                ActivityHeatMapCard(viewModel: viewModel, selectedTimeFrame: $selectedTimeFrame)
                    .padding(.horizontal)
                
                // Current Focus - What you're working on
                CurrentFocusCard(viewModel: viewModel, audioPlayer: audioPlayer)
                    .padding(.horizontal)
                
                // Streak Counter
                StreakCard(viewModel: viewModel, pulseAnimation: $pulseAnimation)
                    .padding(.horizontal)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            pulseAnimation = true
                        }
                    }
                
                // Recent Activity Feed
                RecentActivityCard(viewModel: viewModel, audioPlayer: audioPlayer)
                    .padding(.horizontal)
                
                // Circles Placeholder (Social)
                CirclesPreviewCard()
                    .padding(.horizontal)
                
                // Quick Actions
                QuickActionsCard(showingRecordSheet: $showingRecordSheet)
                    .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
            .padding(.top)
        }
        .background(
            ZStack {
                // Dynamic animated background
                DynamicHomeBackground()
            }
            .ignoresSafeArea()
        )
        .sheet(isPresented: $showingRecordSheet) {
            RecordingView(viewModel: viewModel)
        }
    }
}

// MARK: - Dynamic Background
struct DynamicHomeBackground: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.04, blue: 0.07),
                    Color(red: 0.15, green: 0.02, blue: 0.2),
                    Color(red: 0.02, green: 0.04, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated blobs
            ForEach(0..<3) { index in
                MovingBlob(
                    color: [Color.purple, Color.pink, Color.blue][index],
                    size: CGFloat.random(in: 200...400),
                    delay: Double(index) * 2
                )
            }
        }
    }
}

struct MovingBlob: View {
    let color: Color
    let size: CGFloat
    let delay: Double
    
    @State private var position = CGPoint(x: 0, y: 0)
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(0.3), color.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size/2
                )
            )
            .frame(width: size, height: size)
            .scaleEffect(scale)
            .position(position)
            .blur(radius: 40)
            .onAppear {
                position = CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                )
                
                withAnimation(
                    .easeInOut(duration: 20)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    position = CGPoint(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
                    scale = CGFloat.random(in: 0.8...1.2)
                }
            }
    }
}

// MARK: - Header
struct HomeHeaderView: View {
    @State private var currentTime = Date()
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: currentTime)
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Good Night"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Keep the momentum going")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                currentTime = Date()
            }
        }
    }
}

// MARK: - Hero Stats Card
struct HeroStatsCard: View {
    @ObservedObject var viewModel: MusicViewModel
    @Binding var animateProgress: Bool
    
    private var totalRecordings: Int {
        viewModel.songs.flatMap { $0.parts.flatMap { $0.recordings } }.count
    }
    
    private var completedParts: Int {
        viewModel.songs.flatMap { $0.parts }.filter { $0.status == .complete }.count
    }
    
    private var totalParts: Int {
        viewModel.songs.flatMap { $0.parts }.count
    }
    
    private var progress: Double {
        guard totalParts > 0 else { return 0 }
        return Double(completedParts) / Double(totalParts)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Circular Progress Ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 20)
                    .frame(width: 200, height: 200)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: animateProgress ? progress : 0)
                    .stroke(
                        AngularGradient(
                            colors: [.purple, .pink, .orange, .purple],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: .purple.opacity(0.5), radius: 10)
                
                // Center content
                VStack(spacing: 8) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Complete")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            
            // Stats grid
            HStack(spacing: 16) {
                StatBox(
                    value: "\(viewModel.songs.count)",
                    label: "Songs",
                    icon: "music.note.list",
                    color: .purple
                )
                
                StatBox(
                    value: "\(totalParts)",
                    label: "Parts",
                    icon: "music.quarternote.3",
                    color: .pink
                )
                
                StatBox(
                    value: "\(totalRecordings)",
                    label: "Recordings",
                    icon: "waveform",
                    color: .orange
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [.purple.opacity(0.3), .pink.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Stat Box
struct StatBox: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    @State private var animateIn = false
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .scaleEffect(animateIn ? 1 : 0)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .scaleEffect(animateIn ? 1 : 0)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.1))
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2)) {
                animateIn = true
            }
        }
    }
}

// MARK: - Activity Heat Map
struct ActivityHeatMapCard: View {
    @ObservedObject var viewModel: MusicViewModel
    @Binding var selectedTimeFrame: HomeView.TimeFrame
    
    private var activityData: [Date: Int] {
        var data: [Date: Int] = [:]
        let calendar = Calendar.current
        
        for song in viewModel.songs {
            for part in song.parts {
                for recording in part.recordings {
                    let startOfDay = calendar.startOfDay(for: recording.date)
                    data[startOfDay, default: 0] += 1
                }
            }
        }
        
        return data
    }
    
    private var last30Days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<30).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }.reversed()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Activity")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Picker("", selection: $selectedTimeFrame) {
                    ForEach(HomeView.TimeFrame.allCases, id: \.self) { frame in
                        Text(frame.rawValue)
                            .tag(frame)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            
            // Heat map grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(last30Days, id: \.self) { date in
                    ActivityCell(
                        date: date,
                        intensity: activityData[date] ?? 0
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct ActivityCell: View {
    let date: Date
    let intensity: Int
    
    @State private var showDetail = false
    
    private var color: Color {
        switch intensity {
        case 0: return Color.white.opacity(0.05)
        case 1: return Color.purple.opacity(0.3)
        case 2: return Color.purple.opacity(0.5)
        case 3: return Color.purple.opacity(0.7)
        default: return Color.purple.opacity(0.9)
        }
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color)
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Text(intensity > 0 ? "\(intensity)" : "")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .opacity(intensity > 0 ? 0.8 : 0)
            )
            .scaleEffect(showDetail ? 1.2 : 1.0)
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    showDetail.toggle()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showDetail = false
                    }
                }
            }
    }
}

// MARK: - Current Focus Card
struct CurrentFocusCard: View {
    @ObservedObject var viewModel: MusicViewModel
    @ObservedObject var audioPlayer: AudioPlaybackManager
    
    private var recentSongs: [MTSong] {
        viewModel.songs.sorted { song1, song2 in
            let date1 = song1.parts.flatMap { $0.recordings }.map { $0.date }.max() ?? Date.distantPast
            let date2 = song2.parts.flatMap { $0.recordings }.map { $0.date }.max() ?? Date.distantPast
            return date1 > date2
        }.prefix(3).map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(.pink)
                Text("Current Focus")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            
            if recentSongs.isEmpty {
                EmptyFocusView()
            } else {
                ForEach(recentSongs) { song in
                    FocusSongRow(song: song, viewModel: viewModel)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [.pink.opacity(0.1), .purple.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

struct FocusSongRow: View {
    let song: MTSong
    @ObservedObject var viewModel: MusicViewModel
    
    private var progress: Double {
        let completed = song.parts.filter { $0.status == .complete }.count
        guard song.parts.count > 0 else { return 0 }
        return Double(completed) / Double(song.parts.count)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Album art
            if let artworkURLString = song.artworkURL, !artworkURLString.isEmpty {
                if !artworkURLString.hasPrefix("http"),
                   let data = Data(base64Encoded: artworkURLString),
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundStyle(.white)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                HStack(spacing: 4) {
                    ProgressView(value: progress)
                        .tint(.pink)
                        .frame(width: 80)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.pink)
                }
            }
            
            Spacer()
            
            Button {
                viewModel.selectedSongId = song.id
                viewModel.activeTab = .collection
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(.pink)
                    .font(.title3)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct EmptyFocusView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.title)
                .foregroundStyle(.pink.opacity(0.5))
            Text("Start practicing to see your focus")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Streak Card
struct StreakCard: View {
    @ObservedObject var viewModel: MusicViewModel
    @Binding var pulseAnimation: Bool
    
    private var currentStreak: Int {
        // Calculate consecutive days with recordings
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        let allRecordings = viewModel.songs
            .flatMap { $0.parts.flatMap { $0.recordings } }
            .map { calendar.startOfDay(for: $0.date) }
        
        while allRecordings.contains(currentDate) {
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? Date()
        }
        
        return streak
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .shadow(color: .orange.opacity(0.5), radius: pulseAnimation ? 15 : 10)
                
                Image(systemName: "flame.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(currentStreak) Day Streak")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Keep it going!")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Streak calendar preview
            HStack(spacing: 2) {
                ForEach(0..<7) { day in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(day < currentStreak ? Color.orange : Color.white.opacity(0.1))
                        .frame(width: 4, height: 30)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [.orange.opacity(0.2), .yellow.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
    }
}

// MARK: - Recent Activity Card
struct RecentActivityCard: View {
    @ObservedObject var viewModel: MusicViewModel
    @ObservedObject var audioPlayer: AudioPlaybackManager
    
    private var recentRecordings: [(recording: MTRecording, song: MTSong, part: MTSongPart)] {
        var recordings: [(recording: MTRecording, song: MTSong, part: MTSongPart)] = []
        
        for song in viewModel.songs {
            for part in song.parts {
                for recording in part.recordings {
                    recordings.append((recording: recording, song: song, part: part))
                }
            }
        }
        
        return recordings
            .sorted(by: { lhs, rhs in lhs.recording.date > rhs.recording.date })
            .prefix(5)
            .map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.blue)
                Text("Recent Activity")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    viewModel.activeTab = .collection
                    viewModel.collectionViewMode = .clips
                } label: {
                    Text("See All")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            
            if recentRecordings.isEmpty {
                Text("No recordings yet")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(recentRecordings, id: \.recording.id) { item in
                    ActivityRow(
                        recording: item.recording,
                        song: item.song,
                        part: item.part,
                        audioPlayer: audioPlayer
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct ActivityRow: View {
    let recording: MTRecording
    let song: MTSong
    let part: MTSongPart
    @ObservedObject var audioPlayer: AudioPlaybackManager
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: recording.date, relativeTo: Date())
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                if let fileURL = recording.fileURL {
                    audioPlayer.playRecording(id: recording.id, fileURL: fileURL)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: audioPlayer.currentlyPlayingId == recording.id && audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(song.title) - \(part.name)")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(timeAgo)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
            
            if recording.isLoop {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }
}

// MARK: - Circles Preview Card (Social placeholder)
struct CirclesPreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.2.circle")
                    .foregroundStyle(.green)
                Text("Your Circles")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("Coming Soon")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.2))
                    )
            }
            
            HStack(spacing: 16) {
                ForEach(0..<3) { _ in
                    VStack(spacing: 8) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.green.opacity(0.3), .blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.white.opacity(0.5))
                            )
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 50, height: 6)
                    }
                }
                
                Spacer()
            }
            
            Text("Share and discover with friends")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [.green.opacity(0.1), .blue.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

// MARK: - Quick Actions Card
struct QuickActionsCard: View {
    @Binding var showingRecordSheet: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            QuickActionButton(
                icon: "waveform.circle.fill",
                label: "Record",
                color: .purple
            ) {
                showingRecordSheet = true
            }
            
            QuickActionButton(
                icon: "music.note.list",
                label: "Browse",
                color: .pink
            ) {
                // Navigate to collection
            }
            
            QuickActionButton(
                icon: "slider.horizontal.3",
                label: "Studio",
                color: .blue
            ) {
                // Navigate to studio
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

