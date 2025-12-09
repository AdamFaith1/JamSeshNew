//
//  GlobalOverlays.swift
//  Discography
//
//  Created by Adam Faith on 2025-10-28.
//

import SwiftUI

// MARK: - Global Overlays View Modifier
extension View {
    /// Add this to your root view to show all app-wide overlays (success, error, info, etc.)
    func showGlobalOverlays(for viewModel: MusicViewModel) -> some View {
        self.modifier(GlobalOverlaysModifier(viewModel: viewModel))
    }
}

// MARK: - Global Overlays Modifier
struct GlobalOverlaysModifier: ViewModifier {
    @ObservedObject var viewModel: MusicViewModel
    @State private var activeOverlay: OverlayType?
    @State private var confetti: [ConfettiPiece] = []
    
    enum OverlayType {
        case success(String)
        case error(String)
        case info(String)
        case warning(String)
    }
    
    struct ConfettiPiece: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var color: Color
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                ZStack {
                    if let overlay = activeOverlay {
                        // Dim background
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                dismissOverlay()
                            }
                        
                        // Confetti (only for success)
                        if case .success = overlay {
                            GeometryReader { geo in
                                ForEach(confetti) { piece in
                                    Circle()
                                        .fill(piece.color)
                                        .frame(width: 8, height: 8)
                                        .position(x: piece.x, y: piece.y)
                                }
                            }
                        }
                        
                        // Overlay card
                        overlayCard(for: overlay)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .allowsHitTesting(activeOverlay != nil)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: activeOverlay != nil)
            )
            .onChange(of: viewModel.notificationMessage) { oldValue, message in
                guard let msg = message else { return }
                handleNotification(msg)
            }
    }
    
    // MARK: - Overlay Card Builder
    @ViewBuilder
    private func overlayCard(for overlay: OverlayType) -> some View {
        VStack(spacing: 16) {
            // Icon
            overlayIcon(for: overlay)
            
            // Title
            Text(overlayTitle(for: overlay))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            // Message
            Text(overlayMessage(for: overlay))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(overlayBackground(for: overlay))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(overlayBorder(for: overlay), lineWidth: 2)
                )
                .shadow(color: overlayShadow(for: overlay), radius: 20)
        )
        .padding(.horizontal, 40)
    }
    
    // MARK: - Icon Builder
    @ViewBuilder
    private func overlayIcon(for overlay: OverlayType) -> some View {
        ZStack {
            Circle()
                .fill(overlayIconGradient(for: overlay))
                .frame(width: 80, height: 80)
            
            Image(systemName: overlayIconName(for: overlay))
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
        }
    }
    
    // MARK: - Overlay Properties
    private func overlayTitle(for overlay: OverlayType) -> String {
        switch overlay {
        case .success: return "Recording Saved!"
        case .error: return "Error"
        case .info: return "Info"
        case .warning: return "Warning"
        }
    }
    
    private func overlayMessage(for overlay: OverlayType) -> String {
        switch overlay {
        case .success(let msg): return msg.replacingOccurrences(of: "Saved recording to ", with: "")
        case .error(let msg): return msg
        case .info(let msg): return msg
        case .warning(let msg): return msg
        }
    }
    
    private func overlayIconName(for overlay: OverlayType) -> String {
        switch overlay {
        case .success: return "checkmark"
        case .error: return "xmark"
        case .info: return "info"
        case .warning: return "exclamationmark"
        }
    }
    
    private func overlayIconGradient(for overlay: OverlayType) -> LinearGradient {
        let colors: [Color]
        switch overlay {
        case .success: colors = [.green, Color(red: 0, green: 0.7, blue: 0)]
        case .error: colors = [.red, Color(red: 0.8, green: 0.1, blue: 0.1)]
        case .info: colors = [.blue, Color(red: 0.1, green: 0.5, blue: 0.9)]
        case .warning: colors = [.orange, Color(red: 0.9, green: 0.5, blue: 0)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private func overlayBackground(for overlay: OverlayType) -> Color {
        Color(red: 0.12, green: 0.02, blue: 0.18)
    }
    
    private func overlayBorder(for overlay: OverlayType) -> Color {
        switch overlay {
        case .success: return .green.opacity(0.4)
        case .error: return .red.opacity(0.4)
        case .info: return .blue.opacity(0.4)
        case .warning: return .orange.opacity(0.4)
        }
    }
    
    private func overlayShadow(for overlay: OverlayType) -> Color {
        switch overlay {
        case .success: return .green.opacity(0.3)
        case .error: return .red.opacity(0.3)
        case .info: return .blue.opacity(0.3)
        case .warning: return .orange.opacity(0.3)
        }
    }
    
    // MARK: - Notification Handler
    private func handleNotification(_ message: String) {
        // Success messages (with confetti)
        if message.contains("Saved recording") {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            activeOverlay = .success(message)
            generateConfetti()
            autoDismiss(after: 2.0)
        }
        // Add part success
        else if message.contains("Added") && message.contains("to") {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            activeOverlay = .success(message)
            generateConfetti()
            autoDismiss(after: 2.0)
        }
        // Created song success
        else if message.contains("Created") && message.contains("with part") {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            activeOverlay = .success(message)
            generateConfetti()
            autoDismiss(after: 2.0)
        }
        // Delete success
        else if message.contains("Deleted") {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            activeOverlay = .info(message)
            autoDismiss(after: 1.5)
        }
        // Error messages
        else if message.contains("Failed") || message.contains("Error") {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            activeOverlay = .error(message)
            autoDismiss(after: 3.0)
        }
        // Warning messages
        else if message.contains("Warning") {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            activeOverlay = .warning(message)
            autoDismiss(after: 2.5)
        }
        // Default info
        else {
            activeOverlay = .info(message)
            autoDismiss(after: 2.0)
        }
    }
    
    // MARK: - Confetti
    private func generateConfetti() {
        confetti.removeAll()
        let colors: [Color] = [.purple, .pink, .orange, .green, .blue, .yellow]
        
        for _ in 0..<40 {
            let piece = ConfettiPiece(
                x: CGFloat.random(in: 50...UIScreen.main.bounds.width - 50),
                y: -50,
                color: colors.randomElement() ?? .purple
            )
            confetti.append(piece)
        }
        
        // Animate confetti falling
        for i in 0..<confetti.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.01) {
                withAnimation(.easeOut(duration: 1.5)) {
                    confetti[i].y = UIScreen.main.bounds.height + 50
                }
            }
        }
    }
    
    // MARK: - Auto Dismiss
    private func autoDismiss(after seconds: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            dismissOverlay()
        }
    }
    
    private func dismissOverlay() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            activeOverlay = nil
        }
    }
}

/*
USAGE:

In ModernTile (where you create viewModel), just add .showGlobalOverlays():

struct ModernTile: View {
    @StateObject private var viewModel = MusicViewModel()
    
    var body: some View {
        MainView(viewModel: viewModel)
            .showGlobalOverlays(for: viewModel)  // ← Add this line!
    }
}

SUPPORTED OVERLAYS:
✅ Success (with confetti):
   - "Saved recording to..."
   - "Added ... to ..."
   - "Created ... with part ..."

ℹ️ Info:
   - "Deleted ..."
   - General messages

❌ Error:
   - "Failed ..."
   - "Error ..."

⚠️ Warning:
   - "Warning ..."

All overlays:
- Show appropriate icon and color
- Include haptic feedback
- Auto-dismiss after appropriate time
- Can be tapped to dismiss early
- Appear over ANY page in the app
*/
