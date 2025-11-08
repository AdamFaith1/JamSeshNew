//
//  LoopsView.swift
//  JamSesh
//
//  Created by Adam Faith on 2025-11-06.
//
import SwiftUI
import SwiftData

// MARK: - Loops Grid View
// MARK: - Clips Grid View

struct ClipsGridView: View {
    @ObservedObject var viewModel: MusicViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showingFilters = false
    @State private var selectedLoop: MTLoop?
    @State private var selectedLoopForEdit: MTLoop?  // NEW
    
    private var loopCatalog: LoopCatalogService { viewModel.loopCatalog }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search and filters
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Clips")
                            .font(.title2).bold()
                            .foregroundStyle(LinearGradient(colors: [.purple.opacity(0.8), .pink.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                        Text("\(viewModel.loopCatalog.filteredLoops.count) clips • \(viewModel.loopCatalog.availablePartTypes.count) types")
                            .font(.caption).foregroundStyle(.purple.opacity(0.6))
                    }
                    Spacer()
                    
                    // Filter button
                    Button {
                        showingFilters = true
                    } label: {
                        Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.title3)
                            .foregroundStyle(hasActiveFilters ? .pink : .white)
                            .frame(width: 48, height: 48)
                            .background(hasActiveFilters ? Color.pink.opacity(0.2) : Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.purple.opacity(0.6))
                    TextField("Search loops...", text: Binding(get: { loopCatalog.searchQuery }, set: { loopCatalog.searchQuery = $0 }))
                        .foregroundStyle(.white)
                    
                    if !loopCatalog.searchQuery.isEmpty {
                        Button {
                            loopCatalog.searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.purple.opacity(0.3)))
                .cornerRadius(16)
                .padding(.horizontal)
            }
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Active filters chips
            if hasActiveFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let partType = loopCatalog.filterPartType {
                            FilterChip(text: partType, color: .blue) {
                                loopCatalog.filterPartType = nil
                            }
                        }
                        
                        if let key = loopCatalog.filterKey {
                            FilterChip(text: "Key: \(key)", color: .green) {
                                loopCatalog.filterKey = nil
                            }
                        }
                        
                        if let bpmRange = loopCatalog.filterBPMRange {
                            FilterChip(text: "\(bpmRange.lowerBound)-\(bpmRange.upperBound) BPM", color: .orange) {
                                loopCatalog.filterBPMRange = nil
                            }
                        }
                        
                        ForEach(Array(loopCatalog.filterTags), id: \.self) { tag in
                            FilterChip(text: tag, color: .purple) {
                                loopCatalog.filterTags.remove(tag)
                            }
                        }
                        
                        if loopCatalog.showOnlyStarred {
                            FilterChip(text: "Starred", color: .yellow) {
                                loopCatalog.showOnlyStarred = false
                            }
                        }
                        
                        if loopCatalog.showOnlyImported {
                            FilterChip(text: "Imported", color: .pink) {
                                loopCatalog.showOnlyImported = false
                            }
                        }
                        
                        Button {
                            loopCatalog.clearFilters()
                        } label: {
                            Text("Clear All")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.red.opacity(0.3)))
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }
            
            // Loops grid
            if loopCatalog.filteredLoops.isEmpty {
                LoopsEmptyStateView(hasFilters: hasActiveFilters)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: 16, alignment: .top),
                            count: 2
                        ),
                        spacing: 16
                    ) {
                        ForEach(loopCatalog.filteredLoops) { loop in
                            LoopCard(
                                loop: loop,
                                onTap: {
                                    selectedLoop = loop
                                },
                                onToggleStar: {
                                    Task {
                                        await loopCatalog.toggleStar(context: modelContext, loopId: loop.id)
                                    }
                                },
                                onToggleLoop: {
                                    Task {
                                        var updatedLoop = loop
                                        updatedLoop.isLoop = !updatedLoop.isLoop
                                        await loopCatalog.updateLoop(context: modelContext, loop: updatedLoop)
                                    }
                                },
                                onEditLoop: {
                                    selectedLoopForEdit = loop
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            LoopFilterSheet(loopCatalog: loopCatalog)
        }
        .sheet(item: $selectedLoop) { loop in
            LoopDetailSheet(loop: loop, loopCatalog: loopCatalog, viewModel: viewModel)
        }
        .sheet(item: $selectedLoopForEdit) { loop in
            // Convert MTLoop back to recording
            if let recording = viewModel.songs
                .flatMap({ $0.parts.flatMap({ $0.recordings }) })
                .first(where: { $0.id == loop.recordingId }) {
                LoopEditorSheet(recording: .constant(recording)) { updatedRecording in
                    // Save the updated recording with loop points
                    Task {
                        if let song = viewModel.songs.first(where: { song in
                            song.parts.contains(where: { part in
                                part.recordings.contains(where: { $0.id == recording.id })
                            })
                        }),
                        let part = song.parts.first(where: { $0.recordings.contains(where: { $0.id == recording.id }) }) {
                            await viewModel.saveRecording(context: modelContext, songId: song.id, partId: part.id, recording: updatedRecording)
                        }
                    }
                }
            }
        }
    }
    
    private var hasActiveFilters: Bool {
        loopCatalog.filterPartType != nil ||
        loopCatalog.filterBPMRange != nil ||
        loopCatalog.filterKey != nil ||
        !loopCatalog.filterTags.isEmpty ||
        loopCatalog.showOnlyStarred ||
        loopCatalog.showOnlyImported
    }
}

// MARK: - Loop Card
struct LoopCard: View {
    let loop: MTLoop
    let onTap: () -> Void
    let onToggleStar: () -> Void
    let onToggleLoop: () -> Void
    let onEditLoop: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(loop.songTitle)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        Text(loop.songArtist)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button(action: onToggleStar) {
                        Image(systemName: loop.isStarred ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundStyle(loop.isStarred ? .yellow : .white.opacity(0.5))
                    }
                    
                    Button(action: onToggleLoop) {
                        Image(systemName: loop.isLoop ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.triangle.2.circlepath.circle")
                            .font(.caption)
                            .foregroundStyle(loop.isLoop ? .green : .white.opacity(0.5))
                    }
                    
                    if loop.isLoop {
                        Button(action: onEditLoop) {
                            Image(systemName: "waveform.badge.magnifyingglass")
                                .font(.caption)
                                .foregroundStyle(.purple)
                        }
                    }
                }
                
                HStack {
                    Text(loop.partType)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple.opacity(0.6), .pink.opacity(0.6)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    
                    Spacer()
                    
                    Text(formatDuration(loop.lengthSeconds))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                HStack(spacing: 6) {
                    if let bpm = loop.bpm {
                        MetadataChip(icon: "metronome", text: "\(bpm)", color: .orange)
                    }
                    
                    if let key = loop.key {
                        MetadataChip(icon: "music.note", text: key, color: .green)
                    }
                    
                    if loop.isImported {
                        MetadataChip(icon: "square.and.arrow.down", text: "Shared", color: .pink)
                    }
                }
                
                if !loop.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(loop.tags.prefix(2)), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.white.opacity(0.1)))
                        }
                        
                        if loop.tags.count > 2 {
                            Text("+\(loop.tags.count - 2)")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.white.opacity(0.1)))
                        }
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
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
            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Metadata Chip
struct MetadataChip: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(text)
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.2))
        )
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let text: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.caption2)
                .foregroundStyle(.white)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.4))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.6), lineWidth: 1)
                )
        )
    }
}

// MARK: - Empty State
struct LoopsEmptyStateView: View {
    let hasFilters: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: hasFilters ? "line.3.horizontal.decrease.circle" : "waveform.circle")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundColor(.purple.opacity(0.7))
            
            Text(hasFilters ? "No Matching Loops" : "No Loops Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text(hasFilters ? "Try adjusting your filters" : "Record your first take to create a loop")
                .font(.body)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(32)
    }
}

// MARK: - Loop Filter Sheet
struct LoopFilterSheet: View {
    @ObservedObject var loopCatalog: LoopCatalogService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.02, green: 0.04, blue: 0.07)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Part Type Filter
                        FilterSection(title: "Part Type") {
                            FlowLayout(spacing: 8) {
                                ForEach(loopCatalog.availablePartTypes, id: \.self) { partType in
                                    FilterToggleButton(
                                        title: partType,
                                        isSelected: loopCatalog.filterPartType == partType,
                                        color: .blue
                                    ) {
                                        loopCatalog.filterPartType = (loopCatalog.filterPartType == partType) ? nil : partType
                                    }
                                }
                            }
                        }
                        
                        // Key Filter
                        if !loopCatalog.availableKeys.isEmpty {
                            FilterSection(title: "Key") {
                                FlowLayout(spacing: 8) {
                                    ForEach(loopCatalog.availableKeys, id: \.self) { key in
                                        FilterToggleButton(
                                            title: key,
                                            isSelected: loopCatalog.filterKey == key,
                                            color: .green
                                        ) {
                                            loopCatalog.filterKey = (loopCatalog.filterKey == key) ? nil : key
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Tags Filter
                        if !loopCatalog.availableTags.isEmpty {
                            FilterSection(title: "Tags") {
                                FlowLayout(spacing: 8) {
                                    ForEach(loopCatalog.availableTags, id: \.self) { tag in
                                        FilterToggleButton(
                                            title: tag,
                                            isSelected: loopCatalog.filterTags.contains(tag),
                                            color: .purple
                                        ) {
                                            if loopCatalog.filterTags.contains(tag) {
                                                loopCatalog.filterTags.remove(tag)
                                            } else {
                                                loopCatalog.filterTags.insert(tag)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Special Filters
                        FilterSection(title: "Special") {
                            VStack(spacing: 12) {
                                Toggle("Starred Only", isOn: Binding(get: { loopCatalog.showOnlyStarred }, set: { loopCatalog.showOnlyStarred = $0 }))
                                    .tint(.yellow)
                                
                                Toggle("Imported Only", isOn: Binding(get: { loopCatalog.showOnlyImported }, set: { loopCatalog.showOnlyImported = $0 }))
                                    .tint(.pink)
                            }
                            .foregroundStyle(.white)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Filter Loops")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear All") {
                        loopCatalog.clearFilters()
                    }
                    .foregroundStyle(.red)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.purple)
                }
            }
        }
    }
}

// MARK: - Filter Section
struct FilterSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Filter Toggle Button
struct FilterToggleButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .white : color)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? color : color.opacity(0.2))
                        .overlay(
                            Capsule()
                                .stroke(color.opacity(0.5), lineWidth: isSelected ? 2 : 1)
                        )
                )
        }
    }
}

// MARK: - Flow Layout (for wrapping tags)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize
        var positions: [CGPoint]
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var size: CGSize = .zero
            var lineHeight: CGFloat = 0
            var x: CGFloat = 0
            var y: CGFloat = 0
            
            for subview in subviews {
                let subviewSize = subview.sizeThatFits(.unspecified)
                
                if x + subviewSize.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, subviewSize.height)
                x += subviewSize.width + spacing
                size.width = max(size.width, x - spacing)
            }
            
            size.height = y + lineHeight
            self.size = size
            self.positions = positions
        }
    }
}

// MARK: - Loop Detail Sheet (placeholder for future)
struct LoopDetailSheet: View {
    let loop: MTLoop
    @ObservedObject var loopCatalog: LoopCatalogService
    @ObservedObject var viewModel: MusicViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.02, green: 0.04, blue: 0.07)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Song info
                        VStack(spacing: 8) {
                            Text(loop.songTitle)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            
                            Text(loop.songArtist)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                            
                            Text(loop.partType)
                                .font(.caption)
                                .foregroundStyle(.purple)
                        }
                        
                        // Metadata
                        VStack(alignment: .leading, spacing: 16) {
                            if let bpm = loop.bpm {
                                MetadataRow(label: "BPM", value: "\(bpm)", icon: "metronome")
                            }
                            
                            if let key = loop.key {
                                MetadataRow(label: "Key", value: key, icon: "music.note")
                            }
                            
                            MetadataRow(label: "Duration", value: formatDuration(loop.lengthSeconds), icon: "clock")
                            MetadataRow(label: "Created", value: formatDate(loop.dateCreated), icon: "calendar")
                            
                            if loop.isImported, let sharedBy = loop.sharedBy {
                                MetadataRow(label: "Shared by", value: sharedBy, icon: "person")
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                        )
                        
                        // Future: Play button, waveform, trim controls, etc.
                        Text("🎸 Player & editing tools coming soon!")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                            .padding()
                    }
                    .padding()
                }
            }
            .navigationTitle("Loop Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.purple)
                }
            }
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Metadata Row
struct MetadataRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.purple.opacity(0.7))
                .frame(width: 24)
            
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
    }
}

