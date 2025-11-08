// CustomTabBar.swift

import SwiftUI

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var activeTab: MusicViewModel.Tab
    @Binding var showingRecordSheet: Bool
    @Namespace private var animation
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main tab bar background
            HStack(spacing: 0) {
                // Home Tab
                TabButton(
                    icon: "house.fill",
                    title: "Home",
                    isActive: activeTab == .home,
                    namespace: animation
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        activeTab = .home
                    }
                }
                
                // Collection Tab
                TabButton(
                    icon: "square.stack.3d.up.fill",
                    title: "Collection",
                    isActive: activeTab == .collection,
                    namespace: animation
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        activeTab = .collection
                    }
                }
                
                // Spacer for center button
                Spacer()
                    .frame(width: 100)
                
                // Studio Tab
                TabButton(
                    icon: "slider.horizontal.3",
                    title: "Studio",
                    isActive: activeTab == .studio,
                    namespace: animation
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        activeTab = .studio
                    }
                }
                
                // Social Tab
                TabButton(
                    icon: "person.2.fill",
                    title: "Social",
                    isActive: activeTab == .social,
                    namespace: animation
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        activeTab = .social
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .background(
                ZStack {
                    // Blur effect
                    Color(red: 0.08, green: 0.05, blue: 0.12)
                        .opacity(0.95)
                    
                    // Top border gradient
                    LinearGradient(
                        colors: [.purple.opacity(0.3), .pink.opacity(0.2)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .top)
                }
            )
            .overlay(
                // Cutout for center button
                Circle()
                    .fill(Color(red: 0.02, green: 0.04, blue: 0.07))
                    .frame(width: 76, height: 76)
                    .offset(y: -24)
            )
            
            // Elevated Record Button
            TabBarRecordButton(showingRecordSheet: $showingRecordSheet)
                .offset(y: -42)
        }
        .frame(height: 90)
    }
}

// MARK: - Tab Bar Record Button
struct TabBarRecordButton: View {
    @Binding var showingRecordSheet: Bool
    @State private var isPressed = false
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showingRecordSheet = true
            }
        } label: {
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .pink.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .blur(radius: 10)
                
                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 68, height: 68)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .purple.opacity(0.5), radius: 15, y: 5)
                    .scaleEffect(isPressed ? 0.92 : 1.0)
                
                // Icon
                VStack(spacing: 2) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                    Text("Record")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .buttonStyle(RecordButtonStyle(isPressed: $isPressed))
    }
}

// MARK: - Record Button Style
struct RecordButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { newValue in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = newValue
                }
            }
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    if isActive {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.purple.opacity(0.2), .pink.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 32)
                            .matchedGeometryEffect(id: "TAB_INDICATOR", in: namespace)
                    }
                    
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundStyle(
                            isActive ?
                                LinearGradient(
                                    colors: [.purple.opacity(0.9), .pink.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [.white.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                }
                .frame(height: 32)
                
                Text(title)
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? .white : .white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
        }
    }
}
