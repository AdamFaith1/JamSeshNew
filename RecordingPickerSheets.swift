//
//  RecordingPickerSheets.swift
//  Discography
//
//  Created by Adam Faith on 2025-10-27.
//

//
//  RecordingPickerSheets.swift
//  Discography
//
//  Created by Adam Faith on 2025-10-27.
//

import SwiftUI

// MARK: - Song Picker Sheet (Combined: Collection + iTunes Search)
struct SongPickerSheet: View {
    let songs: [MTSong]
    @Binding var selectedSong: MTSong?
    let onSelectSong: (MTSong) -> Void
    let onSelectNewSong: (SongSuggestion) -> Void // NEW: For iTunes results
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var searchQuery = ""
    @State private var isSearching = false
    @State private var itunesResults: [SongSuggestion] = []
    private let searchService = SongSearchService()
    
    // Debounce timer for search
    @State private var searchTask: Task<Void, Never>?
    
    var filteredExistingSongs: [MTSong] {
        if searchQuery.isEmpty {
            return songs.sorted { $0.title < $1.title }
        }
        return songs.filter {
            $0.title.localizedCaseInsensitiveContains(searchQuery) ||
            $0.artist.localizedCaseInsensitiveContains(searchQuery)
        }.sorted { $0.title < $1.title }
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
                            .foregroundStyle(.purple.opacity(0.6))
                        TextField("Search for a song...", text: $searchQuery)
                            .foregroundStyle(.white)
                            .onChange(of: searchQuery) { oldValue, newValue in
                                handleSearchQueryChange(newValue)
                            }
                        
                        if !searchQuery.isEmpty {
                            if isSearching {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                                    .scaleEffect(0.8)
                            } else {
                                Button {
                                    searchQuery = ""
                                    itunesResults = []
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.3)))
                    .cornerRadius(12)
                    .padding()
                    
                    // Results
                    if searchQuery.isEmpty {
                        // Show all existing songs when not searching
                        existingSongsSection
                    } else {
                        // Show combined results when searching
                        ScrollView {
                            VStack(spacing: 20) {
                                // Existing songs section
                                if !filteredExistingSongs.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Image(systemName: "music.note.list")
                                                .foregroundStyle(.purple)
                                            Text("From Your Collection")
                                                .font(.headline)
                                                .foregroundStyle(.white.opacity(0.9))
                                        }
                                        .padding(.horizontal)
                                        
                                        LazyVStack(spacing: 12) {
                                            ForEach(filteredExistingSongs) { song in
                                                SongPickerRow(
                                                    song: song,
                                                    isSelected: selectedSong?.id == song.id
                                                ) {
                                                    onSelectSong(song)
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // iTunes search results section
                                if !itunesResults.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundStyle(.pink)
                                            Text("Add New Song")
                                                .font(.headline)
                                                .foregroundStyle(.white.opacity(0.9))
                                        }
                                        .padding(.horizontal)
                                        
                                        LazyVStack(spacing: 12) {
                                            ForEach(itunesResults) { suggestion in
                                                NewSongPickerRow(suggestion: suggestion) {
                                                    onSelectNewSong(suggestion)
                                                    dismiss()
                                                }
                                            }
                                        }
                                    }
                                    .padding(.top, 8)
                                }
                                
                                // Empty state
                                if filteredExistingSongs.isEmpty && itunesResults.isEmpty && !isSearching {
                                    VStack(spacing: 16) {
                                        Image(systemName: "music.note.list")
                                            .font(.system(size: 50))
                                            .foregroundStyle(.purple.opacity(0.5))
                                        Text("No results found")
                                            .font(.headline)
                                            .foregroundStyle(.white.opacity(0.6))
                                        Text("Try a different search term")
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 60)
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                }
            }
            .navigationTitle("Select Song")
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
    
    // MARK: - Existing Songs Section (No Search)
    private var existingSongsSection: some View {
        SwiftUI.Group {
            if filteredExistingSongs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 50))
                        .foregroundStyle(.purple.opacity(0.5))
                    Text("No songs yet")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Search to add your first song")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredExistingSongs) { song in
                            SongPickerRow(
                                song: song,
                                isSelected: selectedSong?.id == song.id
                            ) {
                                onSelectSong(song)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: - Handle Search Query Change (Debounced)
    private func handleSearchQueryChange(_ newValue: String) {
        // Cancel previous search task
        searchTask?.cancel()
        
        // Clear iTunes results if search is empty
        if newValue.isEmpty {
            itunesResults = []
            isSearching = false
            return
        }
        
        // Debounce: wait 0.5 seconds before searching
        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                if !Task.isCancelled {
                    await performItunesSearch(query: newValue)
                }
            } catch {
                // Task was cancelled, do nothing
            }
        }
    }
    
    // MARK: - Perform iTunes Search
    private func performItunesSearch(query: String) async {
        await MainActor.run { isSearching = true }
        
        do {
            let results = try await searchService.search(query, limit: 20)
            
            await MainActor.run {
                // Filter out songs that already exist in collection
                let existingSongIds = Set(songs.map { "\($0.title.lowercased())|\($0.artist.lowercased())" })
                itunesResults = results.filter { suggestion in
                    let key = "\(suggestion.title.lowercased())|\(suggestion.artist.lowercased())"
                    return !existingSongIds.contains(key)
                }
                isSearching = false
            }
        } catch {
            print("iTunes search error: \(error)")
            await MainActor.run {
                itunesResults = []
                isSearching = false
            }
        }
    }
}

// MARK: - Song Picker Row (Existing Songs)
struct SongPickerRow: View {
    let song: MTSong
    let isSelected: Bool
    let action: () -> Void
    
    // Helper to get artwork image from base64 or URL
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
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Album artwork or color indicator
                ZStack {
                    songColorGradient
                    
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
                                Image(systemName: "music.note")
                                    .foregroundStyle(.white)
                            }
                        }
                    } else {
                        Image(systemName: "music.note")
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                
                // Song info
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(song.artist)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                    
                    // Parts count
                    HStack(spacing: 4) {
                        Image(systemName: "music.quarternote.3")
                            .font(.caption2)
                        Text("\(song.parts.count) part\(song.parts.count == 1 ? "" : "s")")
                            .font(.caption)
                    }
                    .foregroundStyle(.purple.opacity(0.8))
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isSelected ? 0.1 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ?
                                    LinearGradient(
                                        colors: [.green.opacity(0.5), .green.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(
                                        colors: [.purple.opacity(0.2), .pink.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var songColorGradient: LinearGradient {
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
}

// MARK: - New Song Picker Row (iTunes Results)
struct NewSongPickerRow: View {
    let suggestion: SongSuggestion
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Album artwork
                if let artworkURL = suggestion.artworkURL {
                    AsyncImage(url: artworkURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            placeholderArtwork
                        case .empty:
                            ZStack {
                                Color.purple.opacity(0.2)
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                            }
                        @unknown default:
                            placeholderArtwork
                        }
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                } else {
                    placeholderArtwork
                }
                
                // Song info
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(suggestion.artist)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                    
                    if !suggestion.album.isEmpty {
                        Text(suggestion.album)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Add icon
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [.pink.opacity(0.3), .purple.opacity(0.2)],
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
    
    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [.pink.opacity(0.5), .purple.opacity(0.5)],
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
}

// MARK: - Part Picker Sheet
struct PartPickerSheet: View {
    let song: MTSong
    @Binding var selectedPart: MTSongPart?
    let onSelectPart: (MTSongPart) -> Void
    let onAddNewPart: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddPart = false
    @State private var newPartName = ""

    let standardParts = ["Chords", "Intro", "Riff", "Bridge", "Solo", "Outro",
                         "Verse", "Chorus", "Vocals", "Lead Guitar", "Rhythm Guitar", "Bass", "Drums", "Keys"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.02, green: 0.04, blue: 0.07)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Song context card
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(songColorGradient)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .foregroundStyle(.white)
                                        .font(.caption)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(song.title)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(song.artist)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                        )
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Existing parts
                        if !song.parts.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Existing Parts")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding(.horizontal)
                                
                                ForEach(song.parts) { part in
                                    PartPickerRow(
                                        part: part,
                                        isSelected: selectedPart?.id == part.id,
                                        isExisting: true
                                    ) {
                                        onSelectPart(part)
                                    }
                                }
                            }
                        }
                        
                        // Add new part section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Add New Part")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal)
                            
                            ForEach(standardParts, id: \.self) { partName in
                                // Skip if part already exists
                                if !song.parts.contains(where: { $0.name == partName }) {
                                    Button {
                                        onAddNewPart(partName)
                                    } label: {
                                        HStack {
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundStyle(.purple)
                                            Text(partName)
                                                .foregroundStyle(.white)
                                            Spacer()
                                        }
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.05))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                                                )
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                            
                            // Custom part name
                            Button {
                                showingAddPart = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.pink)
                                    Text("Custom Part Name")
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [.pink.opacity(0.3), .purple.opacity(0.2)],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Select Part")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.purple)
                }
            }
            .alert("Add Custom Part", isPresented: $showingAddPart) {
                TextField("Part name", text: $newPartName)
                Button("Cancel", role: .cancel) {
                    newPartName = ""
                }
                Button("Add") {
                    if !newPartName.isEmpty {
                        onAddNewPart(newPartName)
                        newPartName = ""
                    }
                }
            } message: {
                Text("Enter a name for the new part")
            }
        }
    }
    
    private var songColorGradient: LinearGradient {
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
}

// MARK: - Part Picker Row
struct PartPickerRow: View {
    let part: MTSongPart
    let isSelected: Bool
    let isExisting: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                // Status indicator
                Image(systemName: part.status == .complete ? "checkmark.circle.fill" : "clock.fill")
                    .foregroundStyle(part.status == .complete ? .green : .orange)
                
                Text(part.name)
                    .foregroundStyle(.white)
                
                Spacer()
                
                // Recording count
                if !part.recordings.isEmpty {
                    Text("\(part.recordings.count)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                        )
                }
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isSelected ? 0.1 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ?
                                    LinearGradient(
                                        colors: [.green.opacity(0.5), .green.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(
                                        colors: [.purple.opacity(0.2), .pink.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal)
    }
}
