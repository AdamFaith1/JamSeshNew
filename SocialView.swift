import SwiftUI
import FirebaseAuth

// MARK: - Main Social View

struct SocialView: View {
    @StateObject private var firebaseService = FirebaseService.shared

    var body: some View {
        ZStack {
            if firebaseService.isAuthenticated {
                AuthenticatedSocialView()
            } else {
                AuthenticationView()
            }
        }
        .animation(.easeInOut, value: firebaseService.isAuthenticated)
    }
}

// MARK: - Authentication View

struct AuthenticationView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "music.note.house.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text(isSignUp ? "Create Account" : "Welcome Back")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)

                    Text(isSignUp ? "Join the jam session" : "Sign in to connect with friends")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 40)

                // Form
                VStack(spacing: 16) {
                    if isSignUp {
                        FormField(
                            icon: "person.fill",
                            placeholder: "Username",
                            text: $username
                        )
                    }

                    FormField(
                        icon: "envelope.fill",
                        placeholder: "Email",
                        text: $email,
                        keyboardType: .emailAddress
                    )

                    FormField(
                        icon: "lock.fill",
                        placeholder: "Password",
                        text: $password,
                        isSecure: true
                    )

                    if isSignUp {
                        FormField(
                            icon: "lock.fill",
                            placeholder: "Confirm Password",
                            text: $confirmPassword,
                            isSecure: true
                        )
                    }

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    // Action Button
                    Button {
                        Task {
                            await handleAuthentication()
                        }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isSignUp ? "Sign Up" : "Sign In")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isLoading || !isFormValid)
                    .opacity(isFormValid ? 1.0 : 0.5)
                    .padding(.top, 8)

                    // Toggle Sign Up / Sign In
                    Button {
                        withAnimation {
                            isSignUp.toggle()
                            errorMessage = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                .foregroundStyle(.white.opacity(0.6))
                            Text(isSignUp ? "Sign In" : "Sign Up")
                                .foregroundStyle(.purple)
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 32)
            }
        }
        .background(Color(red: 0.02, green: 0.04, blue: 0.07))
    }

    private var isFormValid: Bool {
        if isSignUp {
            return !email.isEmpty && !password.isEmpty && !username.isEmpty &&
                   !confirmPassword.isEmpty && password == confirmPassword
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }

    private func handleAuthentication() async {
        isLoading = true
        errorMessage = nil

        do {
            if isSignUp {
                guard password == confirmPassword else {
                    errorMessage = "Passwords don't match"
                    isLoading = false
                    return
                }
                try await firebaseService.signUp(email: email, password: password, username: username)
            } else {
                try await firebaseService.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Form Field Component

struct FormField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(.white)
    }
}

// MARK: - Authenticated Social View

struct AuthenticatedSocialView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var selectedTab: SocialTab = .feed

    enum SocialTab {
        case feed, friends, profile
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Social")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    try? firebaseService.signOut()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding()
            .background(Color(red: 0.08, green: 0.05, blue: 0.12).opacity(0.95))

            // Tab Selector
            HStack(spacing: 0) {
                TabSelectorButton(
                    title: "Feed",
                    icon: "music.note.list",
                    isSelected: selectedTab == .feed
                ) {
                    withAnimation {
                        selectedTab = .feed
                    }
                }

                TabSelectorButton(
                    title: "Friends",
                    icon: "person.2.fill",
                    isSelected: selectedTab == .friends
                ) {
                    withAnimation {
                        selectedTab = .friends
                    }
                }

                TabSelectorButton(
                    title: "Profile",
                    icon: "person.crop.circle",
                    isSelected: selectedTab == .profile
                ) {
                    withAnimation {
                        selectedTab = .profile
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(red: 0.08, green: 0.05, blue: 0.12).opacity(0.5))

            // Content
            ZStack {
                switch selectedTab {
                case .feed:
                    FeedView()
                case .friends:
                    FriendsView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(red: 0.02, green: 0.04, blue: 0.07))
    }
}

// MARK: - Tab Selector Button

struct TabSelectorButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
            .background(
                isSelected ?
                LinearGradient(
                    colors: [.purple.opacity(0.3), .pink.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                ) : nil
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Feed View

struct FeedView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var recordings: [PublicRecording] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    ProgressView()
                        .tint(.purple)
                        .padding()
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(.red.opacity(0.6))
                        Text(errorMessage)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding()
                } else if recordings.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 50))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("No recordings yet")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Add friends to see their public recordings")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(recordings) { recording in
                            RecordingCard(recording: recording)
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            await loadRecordings()
        }
        .refreshable {
            await loadRecordings()
        }
    }

    private func loadRecordings() async {
        isLoading = true
        errorMessage = nil

        do {
            recordings = try await firebaseService.getFriendsRecordings()
        } catch {
            errorMessage = "Failed to load recordings: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

// MARK: - Recording Card

struct RecordingCard: View {
    let recording: PublicRecording

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User info
            HStack(spacing: 8) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(recording.username.prefix(1).uppercased())
                            .foregroundStyle(.white)
                            .font(.headline)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(recording.username)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(timeAgoString(from: recording.createdAt))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()
            }

            // Recording info
            VStack(alignment: .leading, spacing: 6) {
                Text(recording.songTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text("\(recording.artistName) • \(recording.partName)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            // Duration and likes
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.caption)
                    Text(formatDuration(recording.duration))
                        .font(.caption)
                }
                .foregroundStyle(.white.opacity(0.6))

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                    Text("\(recording.likes)")
                        .font(.caption)
                }
                .foregroundStyle(.pink.opacity(0.8))
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func timeAgoString(from date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)

        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(seconds / 86400)
            return "\(days)d ago"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Friends View

struct FriendsView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var friends: [UserProfile] = []
    @State private var searchQuery = ""
    @State private var searchResults: [UserProfile] = []
    @State private var isSearching = false
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.5))

                TextField("Search users...", text: $searchQuery)
                    .foregroundStyle(.white)
                    .onChange(of: searchQuery) { oldValue, newValue in
                        Task {
                            await searchUsers()
                        }
                    }

                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()

            ScrollView {
                VStack(spacing: 16) {
                    if !searchQuery.isEmpty {
                        // Search results
                        if isSearching {
                            ProgressView()
                                .tint(.purple)
                        } else if searchResults.isEmpty {
                            Text("No users found")
                                .foregroundStyle(.white.opacity(0.6))
                                .padding()
                        } else {
                            VStack(spacing: 8) {
                                Text("Search Results")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)

                                ForEach(searchResults) { user in
                                    UserRow(user: user, isFriend: friends.contains(where: { $0.id == user.id }))
                                }
                            }
                        }
                    } else {
                        // Friends list
                        if isLoading {
                            ProgressView()
                                .tint(.purple)
                                .padding()
                        } else if friends.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.white.opacity(0.3))
                                Text("No friends yet")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("Search for users above to add friends")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 60)
                        } else {
                            VStack(spacing: 8) {
                                Text("Your Friends (\(friends.count))")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)

                                ForEach(friends) { friend in
                                    UserRow(user: friend, isFriend: true)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .task {
            await loadFriends()
        }
    }

    private func loadFriends() async {
        guard let userId = firebaseService.currentUser?.uid else { return }

        isLoading = true
        do {
            friends = try await firebaseService.getFriends(userId: userId)
        } catch {
            print("Failed to load friends: \(error)")
        }
        isLoading = false
    }

    private func searchUsers() async {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        do {
            searchResults = try await firebaseService.searchUsers(query: searchQuery)
            // Filter out current user
            if let currentUserId = firebaseService.currentUser?.uid {
                searchResults.removeAll(where: { $0.id == currentUserId })
            }
        } catch {
            print("Search failed: \(error)")
        }
        isSearching = false
    }
}

// MARK: - User Row

struct UserRow: View {
    let user: UserProfile
    let isFriend: Bool
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var isProcessing = false

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .overlay(
                    Text(user.username.prefix(1).uppercased())
                        .foregroundStyle(.white)
                        .font(.headline)
                )

            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.username)
                    .font(.headline)
                    .foregroundStyle(.white)

                if let bio = user.bio {
                    Text(bio)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Add/Remove button
            Button {
                Task {
                    await toggleFriend()
                }
            } label: {
                if isProcessing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: isFriend ? "person.fill.checkmark" : "person.fill.badge.plus")
                        .font(.title3)
                }
            }
            .foregroundStyle(isFriend ? .green : .purple)
            .disabled(isProcessing)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func toggleFriend() async {
        isProcessing = true
        do {
            if isFriend {
                try await firebaseService.removeFriend(friendId: user.id)
            } else {
                try await firebaseService.addFriend(friendId: user.id)
            }
        } catch {
            print("Failed to toggle friend: \(error)")
        }
        isProcessing = false
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var userRecordings: [PublicRecording] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile header
                VStack(spacing: 16) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .overlay(
                            Text(firebaseService.currentUserProfile?.username.prefix(1).uppercased() ?? "?")
                                .foregroundStyle(.white)
                                .font(.system(size: 40, weight: .bold))
                        )

                    Text(firebaseService.currentUserProfile?.username ?? "Loading...")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text(firebaseService.currentUserProfile?.email ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))

                    // Stats
                    HStack(spacing: 40) {
                        VStack(spacing: 4) {
                            Text("\(firebaseService.currentUserProfile?.friendIds.count ?? 0)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Text("Friends")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        VStack(spacing: 4) {
                            Text("\(userRecordings.count)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Text("Recordings")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                .padding(.top, 32)

                // User's recordings
                if isLoading {
                    ProgressView()
                        .tint(.purple)
                } else if userRecordings.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "waveform.circle")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("No public recordings yet")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.top, 40)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Public Recordings")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal)

                        ForEach(userRecordings) { recording in
                            RecordingCard(recording: recording)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.bottom, 100)
        }
        .task {
            await loadUserRecordings()
        }
    }

    private func loadUserRecordings() async {
        guard let userId = firebaseService.currentUser?.uid else { return }

        isLoading = true
        do {
            userRecordings = try await firebaseService.getUserRecordings(userId: userId)
        } catch {
            print("Failed to load recordings: \(error)")
        }
        isLoading = false
    }
}
