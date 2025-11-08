import SwiftUI
import SwiftData
import Photos
import UIKit
internal import PhotosUI

// MARK: - Root
struct ModernTile: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = MusicViewModel()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red:0.02, green:0.04, blue:0.07),
                                    Color(red:0.15, green:0.02, blue:0.2),
                                    Color(red:0.02, green:0.04, blue:0.07)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            if let selectedSongId = viewModel.selectedSongId {
                ModernSongDetailView(songId: selectedSongId, viewModel: viewModel)
                    .transition(.move(edge: .trailing))
            } else {
                MainView(viewModel: viewModel)
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut, value: viewModel.selectedSongId)
        .showGlobalOverlays(for: viewModel)  // ← Global overlays for success/error/info messages
        .task {
            await viewModel.loadSongs(context: modelContext)
            await viewModel.configureAudioSession()
        }
    }
}


// MARK: - Main View (Replace your existing MainView with this)
struct MainView: View {
    @ObservedObject var viewModel: MusicViewModel
    @State private var showingDeleteConfirmation = false
    @State private var songToDelete: MTSong?
    @State private var showingSortBubble = false
    @State private var showingRecordSheet = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                
                if viewModel.activeTab == .collection {
                    HeaderView(
                        viewModel: viewModel,
                        showingSortBubble: $showingSortBubble
                    )
                }
                // Header with search and controls (NEW)
                // Tab content
                TabContent(
                    viewModel: viewModel,
                    showingDeleteConfirmation: $showingDeleteConfirmation,
                    songToDelete: $songToDelete
                )
                
                // Custom bottom tab bar with elevated record button (NEW)
                CustomTabBar(
                    activeTab: $viewModel.activeTab,
                    showingRecordSheet: $showingRecordSheet
                )
            }
            .sheet(isPresented: $showingRecordSheet) {
                RecordingView(viewModel: viewModel)
            }
        }
        .confirmationDialog(
            "Delete Song?",
            isPresented: $showingDeleteConfirmation,
            presenting: songToDelete
        ) { song in
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteSong(context: modelContext, song: song)
                }
            }
        } message: { song in
            Text("Are you sure you want to delete \"\(song.title)\"?")
        }
    }
}

// MARK: - Tab Content (handles switching between tabs)
// MARK: - Tab Content (handles switching between tabs)
struct TabContent: View {
    @ObservedObject var viewModel: MusicViewModel
    @Binding var showingDeleteConfirmation: Bool
    @Binding var songToDelete: MTSong?
    
    var body: some View {
        ZStack {
            switch viewModel.activeTab {
            case .home:
                HomePlaceholderView()
                
            case .collection:
                if viewModel.songs.isEmpty {
                    EmptyStateView()
                } else {
                    SongsGridView(
                        viewModel: viewModel,
                        showingDeleteConfirmation: $showingDeleteConfirmation,
                        songToDelete: $songToDelete
                    )
                }
                
            case .clips:
                // Clips view has its own header, no need for HeaderView
                ClipsGridView(viewModel: viewModel)
                
            case .social:
                SocialPlaceholderView()
            case .studio:
                StudioPlaceholderView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Recording Sheet View (Placeholder for now)
struct RecordingSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
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
                
                VStack(spacing: 24) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    VStack(spacing: 12) {
                        Text("Recording View")
                            .font(.title)
                            .bold()
                            .foregroundStyle(.white)
                        
                        Text("This is where you'll build your recording UI")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.purple, .pink],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }
                    .padding(.top, 20)
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
    }
}

// MARK: - Placeholder Views
struct StudioPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.house")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple.opacity(0.6), .pink.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Studio Coming Soon")
                .font(.title2)
                .bold()
                .foregroundStyle(.white)
            
            Text("Build your own compositions and mashups")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct JamPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.wave.2")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple.opacity(0.6), .pink.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Jam Sessions Coming Soon")
                .font(.title2)
                .bold()
                .foregroundStyle(.white)
            
            Text("Discover songs to play with friends")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Placeholder Views
struct HomePlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "house.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple.opacity(0.6), .pink.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Home Coming Soon")
                .font(.title2)
                .bold()
                .foregroundStyle(.white)
            
            Text("Your personalized dashboard")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct SocialPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.wave.2")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple.opacity(0.6), .pink.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Social Coming Soon")
                .font(.title2)
                .bold()
                .foregroundStyle(.white)
            
            Text("Connect and jam with friends")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
