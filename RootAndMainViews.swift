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


// MARK: - Main View
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
                
                // Tab content
                TabContent(
                    viewModel: viewModel,
                    showingDeleteConfirmation: $showingDeleteConfirmation,
                    songToDelete: $songToDelete
                )
                
                // Custom bottom tab bar with elevated record button
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

struct TabContent: View {
    @ObservedObject var viewModel: MusicViewModel
    @Binding var showingDeleteConfirmation: Bool
    @Binding var songToDelete: MTSong?
    
    var body: some View {
        ZStack {
            switch viewModel.activeTab {
            case .home:
                HomeView(viewModel: viewModel)
                
            case .collection:
                if viewModel.songs.isEmpty {
                    EmptyStateView()
                } else {
                    if viewModel.collectionViewMode == .albums {
                        SongsGridView(
                            viewModel: viewModel,
                            showingDeleteConfirmation: $showingDeleteConfirmation,
                            songToDelete: $songToDelete
                        )
                    } else {
                        ClipsListView(viewModel: viewModel)
                    }
                }
                
            case .social:
                SocialView()

            case .groups:
                GroupsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Placeholder Views
struct StudioPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "slider.horizontal.3")
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
            
            Text("Mix and layer your clips into new compositions")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding()
    }
}

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
