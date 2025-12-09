//
//  GroupsView.swift
//  Discography
//
//  Groups feature - social music groups for collaborative learning
//

import SwiftUI
internal import PhotosUI
import FirebaseAuth

// MARK: - Main Groups View
struct GroupsView: View {
    @StateObject private var firebase = FirebaseService.shared
    @State private var groups: [Group] = []
    @State private var isLoading = false
    @State private var showCreateGroup = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(red: 0.02, green: 0.04, blue: 0.07)
                    .ignoresSafeArea()

                if !firebase.isAuthenticated {
                    // Not signed in state
                    VStack(spacing: 20) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.purple.opacity(0.6))

                        Text("Sign in to join groups")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)

                        Text("Connect with other musicians and share your progress")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button {
                            // Switch to social tab where they can sign in
                        } label: {
                            Text("Go to Social Tab")
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Capsule())
                        }
                    }
                } else if isLoading {
                    ProgressView()
                        .tint(.purple)
                } else if groups.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.purple.opacity(0.6))

                        Text("No groups yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)

                        Text("Create a group to start jamming with friends")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button {
                            showCreateGroup = true
                        } label: {
                            Label("Create Group", systemImage: "plus.circle.fill")
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Capsule())
                        }
                    }
                } else {
                    // Groups list
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(groups) { group in
                                NavigationLink(destination: GroupDetailView(group: group)) {
                                    GroupCard(group: group)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 100)
                    }
                }

                if let error = errorMessage {
                    VStack {
                        Spacer()
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.red.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding()
                    }
                }
            }
            .navigationTitle("Groups")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if firebase.isAuthenticated && !groups.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showCreateGroup = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.purple)
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupView { newGroup in
                    groups.insert(newGroup, at: 0)
                }
            }
            .task {
                await loadGroups()
            }
            .refreshable {
                await loadGroups()
            }
        }
    }

    private func loadGroups() async {
        guard firebase.isAuthenticated else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            groups = try await firebase.getUserGroups()
        } catch {
            errorMessage = "Failed to load groups: \(error.localizedDescription)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                errorMessage = nil
            }
        }
    }
}

// MARK: - Group Card
struct GroupCard: View {
    let group: Group
    @State private var memberCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover photo
            if let coverURL = group.coverPhotoURL, let url = URL(string: coverURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.purple.opacity(0.3), .pink.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
                .frame(height: 120)
                .clipped()
            } else {
                ZStack {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.purple.opacity(0.3), .pink.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    Image(systemName: "person.3.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(height: 120)
            }

            // Group info
            VStack(alignment: .leading, spacing: 8) {
                Text(group.name)
                    .font(.headline)
                    .foregroundStyle(.white)

                if let description = group.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    Label("\(memberCount) members", systemImage: "person.2")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))

                    Text("•")
                        .foregroundStyle(.white.opacity(0.3))

                    Text(group.createdDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding()
        }
        .background(Color(red: 0.1, green: 0.08, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .task {
            memberCount = group.memberIds.count
        }
    }
}

// MARK: - Create Group View
struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebase = FirebaseService.shared

    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var isCreating = false
    @State private var errorMessage: String?

    var onGroupCreated: (Group) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.02, green: 0.04, blue: 0.07)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Cover photo picker
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            ZStack {
                                if let photoData = selectedPhotoData,
                                   let uiImage = UIImage(data: photoData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 200)
                                        .clipped()
                                } else {
                                    Rectangle()
                                        .fill(LinearGradient(
                                            colors: [.purple.opacity(0.3), .pink.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .frame(height: 200)

                                    VStack(spacing: 8) {
                                        Image(systemName: "photo.fill")
                                            .font(.system(size: 40))
                                        Text("Add Cover Photo")
                                            .font(.subheadline)
                                    }
                                    .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .onChange(of: selectedPhoto) { newValue in
                            Task {
                                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                    selectedPhotoData = data
                                }
                            }
                        }

                        // Group name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Group Name")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.8))

                            TextField("Enter group name", text: $groupName)
                                .textFieldStyle(CustomTextFieldStyle())
                        }

                        // Group description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description (Optional)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.8))

                            TextField("What's this group about?", text: $groupDescription, axis: .vertical)
                                .lineLimit(3...6)
                                .textFieldStyle(CustomTextFieldStyle())
                        }

                        // Create button
                        Button {
                            Task { await createGroup() }
                        } label: {
                            if isCreating {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                Text("Create Group")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .background(
                            LinearGradient(
                                colors: groupName.isEmpty ? [.gray] : [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(groupName.isEmpty || isCreating)

                        if let error = errorMessage {
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func createGroup() async {
        guard let userId = firebase.currentUser?.uid,
              let username = firebase.currentUserProfile?.username else {
            errorMessage = "You must be signed in to create a group"
            return
        }

        isCreating = true
        defer { isCreating = false }

        do {
            var coverPhotoURL: String?

            // Upload cover photo if selected
            if let photoData = selectedPhotoData {
                let groupId = UUID().uuidString
                let url = try await firebase.uploadGroupCoverPhoto(groupId: groupId, imageData: photoData)
                coverPhotoURL = url.absoluteString

                // Create group with uploaded photo URL
                let group = Group(
                    id: groupId,
                    name: groupName,
                    coverPhotoURL: coverPhotoURL,
                    memberIds: [userId],
                    createdById: userId,
                    description: groupDescription.isEmpty ? nil : groupDescription
                )

                try await firebase.createGroup(group)
                onGroupCreated(group)
            } else {
                // Create group without cover photo
                let group = Group(
                    name: groupName,
                    memberIds: [userId],
                    createdById: userId,
                    description: groupDescription.isEmpty ? nil : groupDescription
                )

                try await firebase.createGroup(group)
                onGroupCreated(group)
            }

            dismiss()
        } catch {
            errorMessage = "Failed to create group: \(error.localizedDescription)"
        }
    }
}

// MARK: - Custom Text Field Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(red: 0.1, green: 0.08, blue: 0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
    }
}

// MARK: - Group Detail View
struct GroupDetailView: View {
    let group: Group
    @StateObject private var firebase = FirebaseService.shared
    @State private var selectedTab: GroupTab = .songlist
    @State private var members: [UserProfile] = []

    enum GroupTab: String, CaseIterable {
        case songlist = "Songs"
        case progress = "Feed"
        case jamlist = "Jam List"
    }

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.04, blue: 0.07)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with cover photo
                GroupHeaderView(group: group, memberCount: members.count)

                // Tab selector
                Picker("View", selection: $selectedTab) {
                    ForEach(GroupTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Tab content
                TabView(selection: $selectedTab) {
                    SharedSonglistView(group: group)
                        .tag(GroupTab.songlist)

                    ProgressFeedView(group: group)
                        .tag(GroupTab.progress)

                    JamListView(group: group, members: members)
                        .tag(GroupTab.jamlist)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMembers()
        }
    }

    private func loadMembers() async {
        do {
            members = try await firebase.getGroupMembers(group: group)
        } catch {
            print("Failed to load members: \(error)")
        }
    }
}

// MARK: - Group Header View
struct GroupHeaderView: View {
    let group: Group
    let memberCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover photo
            if let coverURL = group.coverPhotoURL, let url = URL(string: coverURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.purple.opacity(0.3), .pink.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
                .frame(height: 150)
                .clipped()
            } else {
                ZStack {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.purple.opacity(0.3), .pink.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    Image(systemName: "person.3.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(height: 150)
            }

            // Group info
            VStack(alignment: .leading, spacing: 8) {
                Text(group.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                if let description = group.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Label("\(memberCount) members", systemImage: "person.2")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding()
        }
        .background(Color(red: 0.1, green: 0.08, blue: 0.15))
    }
}

// MARK: - Shared Songlist View
struct SharedSonglistView: View {
    let group: Group
    @StateObject private var firebase = FirebaseService.shared
    @State private var songs: [GroupSong] = []
    @State private var showAddSong = false
    @State private var isLoading = false

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .tint(.purple)
            } else if songs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 50))
                        .foregroundStyle(.purple.opacity(0.6))

                    Text("No songs yet")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Add songs to start building your shared songlist")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button {
                        showAddSong = true
                    } label: {
                        Label("Add Song", systemImage: "plus.circle.fill")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(songs) { song in
                            GroupSongRow(song: song, group: group)
                        }
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !songs.isEmpty {
                Button {
                    showAddSong = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .background(
                            Circle()
                                .fill(Color(red: 0.02, green: 0.04, blue: 0.07))
                                .padding(8)
                        )
                }
                .padding(.trailing, 20)
                .padding(.bottom, 120)
            }
        }
        .sheet(isPresented: $showAddSong) {
            AddSongToGroupView(group: group) { newSong in
                songs.insert(newSong, at: 0)
            }
        }
        .task {
            await loadSongs()
        }
        .refreshable {
            await loadSongs()
        }
    }

    private func loadSongs() async {
        isLoading = true
        defer { isLoading = false }

        do {
            songs = try await firebase.getGroupSongs(groupId: group.id)
        } catch {
            print("Failed to load songs: \(error)")
        }
    }
}

// MARK: - Group Song Row
struct GroupSongRow: View {
    let song: GroupSong
    let group: Group

    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            if let artworkURL = song.artworkURL, let url = URL(string: artworkURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.purple.opacity(0.3))
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Rectangle()
                    .fill(.purple.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundStyle(.white.opacity(0.5))
                    )
            }

            // Song info
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                    Text("\(song.memberProgressIds.count) can play")
                        .font(.caption)
                }
                .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(12)
        .background(Color(red: 0.1, green: 0.08, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Add Song To Group View
struct AddSongToGroupView: View {
    let group: Group
    var onSongAdded: (GroupSong) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebase = FirebaseService.shared
    @StateObject private var searchService = SongSearchService()

    @State private var searchQuery = ""
    @State private var searchResults: [SongSuggestion] = []
    @State private var isSearching = false
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.02, green: 0.04, blue: 0.07)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.white.opacity(0.6))

                        TextField("Search for songs...", text: $searchQuery)
                            .foregroundStyle(.white)
                            .onChange(of: searchQuery) { newValue in
                                Task { await performSearch(query: newValue) }
                            }

                        if !searchQuery.isEmpty {
                            Button {
                                searchQuery = ""
                                searchResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }
                    .padding()
                    .background(Color(red: 0.1, green: 0.08, blue: 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()

                    // Results
                    if isSearching {
                        ProgressView()
                            .tint(.purple)
                            .frame(maxHeight: .infinity)
                    } else if searchResults.isEmpty && !searchQuery.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.4))
                            Text("No results found")
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(maxHeight: .infinity)
                    } else if searchResults.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.4))
                            Text("Search for songs to add")
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(searchResults) { suggestion in
                                    SongSuggestionRow(suggestion: suggestion) {
                                        Task { await addSong(suggestion) }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
            .navigationTitle("Add Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func performSearch(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            searchResults = try await searchService.search(query, limit: 20)
        } catch {
            print("Search failed: \(error)")
            searchResults = []
        }
    }

    private func addSong(_ suggestion: SongSuggestion) async {
        guard let userId = firebase.currentUser?.uid else { return }

        isAdding = true
        defer { isAdding = false }

        let groupSong = GroupSong(
            groupId: group.id,
            title: suggestion.title,
            artist: suggestion.artist,
            artworkURL: suggestion.artworkURL?.absoluteString,
            addedById: userId
        )

        do {
            try await firebase.addSongToGroup(groupSong)
            onSongAdded(groupSong)
            dismiss()
        } catch {
            print("Failed to add song: \(error)")
        }
    }
}

// MARK: - Song Suggestion Row
struct SongSuggestionRow: View {
    let suggestion: SongSuggestion
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Artwork
                if let artworkURL = suggestion.artworkURL {
                    AsyncImage(url: artworkURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(.purple.opacity(0.3))
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Rectangle()
                        .fill(.purple.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundStyle(.white.opacity(0.5))
                        )
                }

                // Song info
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(suggestion.artist)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))

                    if !suggestion.album.isEmpty {
                        Text(suggestion.album)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.purple)
            }
            .padding(12)
            .background(Color(red: 0.1, green: 0.08, blue: 0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Progress Feed View
struct ProgressFeedView: View {
    let group: Group
    @StateObject private var firebase = FirebaseService.shared
    @State private var progressUpdates: [GroupProgress] = []
    @State private var showAddProgress = false
    @State private var isLoading = false

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .tint(.purple)
            } else if progressUpdates.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 50))
                        .foregroundStyle(.purple.opacity(0.6))

                    Text("No progress updates yet")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Share your progress to inspire others")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button {
                        showAddProgress = true
                    } label: {
                        Label("Post Update", systemImage: "plus.circle.fill")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(progressUpdates) { progress in
                            ProgressUpdateCard(progress: progress)
                        }
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !progressUpdates.isEmpty {
                Button {
                    showAddProgress = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .background(
                            Circle()
                                .fill(Color(red: 0.02, green: 0.04, blue: 0.07))
                                .padding(8)
                        )
                }
                .padding(.trailing, 20)
                .padding(.bottom, 120)
            }
        }
        .sheet(isPresented: $showAddProgress) {
            AddProgressView(group: group) { newProgress in
                progressUpdates.insert(newProgress, at: 0)
            }
        }
        .task {
            await loadProgress()
        }
        .refreshable {
            await loadProgress()
        }
    }

    private func loadProgress() async {
        isLoading = true
        defer { isLoading = false }

        do {
            progressUpdates = try await firebase.getGroupProgress(groupId: group.id)
        } catch {
            print("Failed to load progress: \(error)")
        }
    }
}

// MARK: - Progress Update Card
struct ProgressUpdateCard: View {
    let progress: GroupProgress
    @StateObject private var firebase = FirebaseService.shared
    @State private var hasReacted: [String: Bool] = [:]

    let reactionEmojis = ["👍", "🔥", "🎸", "❤️", "🎵"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                Circle()
                    .fill(LinearGradient(
                        colors: [.purple.opacity(0.6), .pink.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(progress.postedByUsername.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(progress.postedByUsername)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    Text(progress.postedDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()
            }

            // Song info
            HStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.caption)
                    .foregroundStyle(.purple)

                Text("\(progress.songTitle) - \(progress.songArtist)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(red: 0.15, green: 0.12, blue: 0.2))
            .clipShape(Capsule())

            // Progress text
            Text(progress.progressText)
                .font(.body)
                .foregroundStyle(.white)

            // Reactions
            HStack(spacing: 8) {
                ForEach(reactionEmojis, id: \.self) { emoji in
                    let count = progress.reactionCounts[emoji] ?? 0
                    let isReacted = hasReacted[emoji] ?? false

                    Button {
                        Task { await toggleReaction(emoji: emoji) }
                    } label: {
                        HStack(spacing: 4) {
                            Text(emoji)
                                .font(.body)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(isReacted ? .purple : .white.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            isReacted ?
                                Color.purple.opacity(0.3) :
                                Color(red: 0.15, green: 0.12, blue: 0.2)
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(isReacted ? Color.purple : Color.clear, lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(red: 0.1, green: 0.08, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .task {
            await checkReactions()
        }
    }

    private func checkReactions() async {
        for emoji in reactionEmojis {
            if let reaction = try? await firebase.hasUserReacted(progressId: progress.id, emoji: emoji) {
                hasReacted[emoji] = true
            }
        }
    }

    private func toggleReaction(emoji: String) async {
        guard let userId = firebase.currentUser?.uid else { return }

        do {
            if hasReacted[emoji] == true {
                // Remove reaction
                if let reaction = try await firebase.hasUserReacted(progressId: progress.id, emoji: emoji) {
                    try await firebase.removeReaction(reaction)
                    hasReacted[emoji] = false
                }
            } else {
                // Add reaction
                let reaction = GroupReaction(
                    progressId: progress.id,
                    userId: userId,
                    emoji: emoji
                )
                try await firebase.addReaction(reaction)
                hasReacted[emoji] = true
            }
        } catch {
            print("Failed to toggle reaction: \(error)")
        }
    }
}

// MARK: - Add Progress View
struct AddProgressView: View {
    let group: Group
    var onProgressAdded: (GroupProgress) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebase = FirebaseService.shared
    @State private var selectedSong: GroupSong?
    @State private var progressText = ""
    @State private var groupSongs: [GroupSong] = []
    @State private var isPosting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.02, green: 0.04, blue: 0.07)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Song picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Select Song")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.8))

                            if groupSongs.isEmpty {
                                Text("No songs in this group yet")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color(red: 0.1, green: 0.08, blue: 0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                Menu {
                                    ForEach(groupSongs) { song in
                                        Button {
                                            selectedSong = song
                                        } label: {
                                            Text("\(song.title) - \(song.artist)")
                                        }
                                    }
                                } label: {
                                    HStack {
                                        if let song = selectedSong {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(song.title)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                Text(song.artist)
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.7))
                                            }
                                        } else {
                                            Text("Choose a song...")
                                                .foregroundStyle(.white.opacity(0.6))
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.down")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.6))
                                    }
                                    .padding()
                                    .background(Color(red: 0.1, green: 0.08, blue: 0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(.white)
                                }
                            }
                        }

                        // Progress text
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Progress")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.8))

                            TextField("What did you accomplish?", text: $progressText, axis: .vertical)
                                .lineLimit(3...8)
                                .textFieldStyle(CustomTextFieldStyle())
                        }

                        // Post button
                        Button {
                            Task { await postProgress() }
                        } label: {
                            if isPosting {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                Text("Post Update")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .background(
                            LinearGradient(
                                colors: (selectedSong != nil && !progressText.isEmpty) ? [.purple, .pink] : [.gray],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(selectedSong == nil || progressText.isEmpty || isPosting)

                        if let error = errorMessage {
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Post Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadGroupSongs()
            }
        }
    }

    private func loadGroupSongs() async {
        do {
            groupSongs = try await firebase.getGroupSongs(groupId: group.id)
        } catch {
            print("Failed to load songs: \(error)")
        }
    }

    private func postProgress() async {
        guard let song = selectedSong,
              let userId = firebase.currentUser?.uid,
              let username = firebase.currentUserProfile?.username else {
            errorMessage = "Missing required information"
            return
        }

        isPosting = true
        defer { isPosting = false }

        let progress = GroupProgress(
            groupId: group.id,
            songId: song.id,
            songTitle: song.title,
            songArtist: song.artist,
            postedById: userId,
            postedByUsername: username,
            progressText: progressText
        )

        do {
            try await firebase.addProgressUpdate(progress)
            onProgressAdded(progress)
            dismiss()
        } catch {
            errorMessage = "Failed to post progress: \(error.localizedDescription)"
        }
    }
}

// MARK: - Jam List View
struct JamListView: View {
    let group: Group
    let members: [UserProfile]

    @StateObject private var firebase = FirebaseService.shared
    @State private var jamSongs: [JamListSong] = []
    @State private var isLoading = false
    @State private var minimumMembers = 2 // Minimum number of members who can play a song

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .tint(.purple)
            } else {
                VStack(spacing: 0) {
                    // Filter control
                    VStack(spacing: 8) {
                        HStack {
                            Text("Show songs that")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))

                            Spacer()

                            Picker("Members", selection: $minimumMembers) {
                                Text("2+ can play").tag(2)
                                Text("3+ can play").tag(3)
                                Text("All can play").tag(members.count)
                            }
                            .pickerStyle(.menu)
                            .tint(.purple)
                        }

                        Divider()
                            .background(.white.opacity(0.2))
                    }
                    .padding()
                    .background(Color(red: 0.1, green: 0.08, blue: 0.15))

                    if filteredJamSongs.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 50))
                                .foregroundStyle(.purple.opacity(0.6))

                            Text("No jam songs found")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Text("Add songs and share progress to build your jam list")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredJamSongs) { song in
                                    JamSongRow(song: song, totalMembers: members.count)
                                }
                            }
                            .padding()
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
        }
        .task {
            await loadJamSongs()
        }
        .onChange(of: minimumMembers) { _ in
            // Filter will update automatically via computed property
        }
    }

    private var filteredJamSongs: [JamListSong] {
        jamSongs.filter { $0.memberCount >= minimumMembers }
    }

    private func loadJamSongs() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Get all group songs
            let groupSongs = try await firebase.getGroupSongs(groupId: group.id)

            // Build jam list - songs with progress from multiple members
            var jamList: [JamListSong] = []

            for song in groupSongs {
                let memberCount = song.memberProgressIds.count
                if memberCount >= 2 {
                    let jamSong = JamListSong(
                        id: song.id,
                        title: song.title,
                        artist: song.artist,
                        artworkURL: song.artworkURL,
                        memberCount: memberCount
                    )
                    jamList.append(jamSong)
                }
            }

            // Sort by member count (most popular first)
            jamSongs = jamList.sorted { $0.memberCount > $1.memberCount }
        } catch {
            print("Failed to load jam songs: \(error)")
        }
    }
}

// MARK: - Jam Song Row
struct JamSongRow: View {
    let song: JamListSong
    let totalMembers: Int

    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            if let artworkURL = song.artworkURL, let url = URL(string: artworkURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.purple.opacity(0.3))
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Rectangle()
                    .fill(.purple.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundStyle(.white.opacity(0.5))
                    )
            }

            // Song info
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("\(song.memberCount) of \(totalMembers) can play")
                        .font(.caption)
                }
                .foregroundStyle(.green.opacity(0.8))
            }

            Spacer()

            // Progress indicator
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 3)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: Double(song.memberCount) / Double(totalMembers))
                    .stroke(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                Text("\(Int((Double(song.memberCount) / Double(totalMembers)) * 100))%")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
        }
        .padding(12)
        .background(Color(red: 0.1, green: 0.08, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
