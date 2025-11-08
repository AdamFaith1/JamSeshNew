//
//  HeaderView.swift
//  Discography
//
//  Created by Adam Faith on 2025-10-27.
//

import SwiftUI

// MARK: - Header View
struct HeaderView: View {
    @ObservedObject var viewModel: MusicViewModel
    @Binding var showingSortBubble: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Title and controls
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.activeTab == .collection ? "My Music" :
                         viewModel.activeTab == .clips ? "Loop Catalog" :
                         viewModel.activeTab == .studio ? "Studio" : "Jam")
                        .font(.title2).bold()
                        .foregroundStyle(LinearGradient(colors: [.purple.opacity(0.8), .pink.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                    
                    if viewModel.activeTab == .collection {
                        Text("\(viewModel.filteredSongs.count) songs • \(viewModel.filteredSongs.filter{$0.isFullyLearned}.count) ready")
                            .font(.caption).foregroundStyle(.purple.opacity(0.6))
                    } else if viewModel.activeTab == .clips {
                        Text("\(viewModel.loopCatalog.filteredLoops.count) loops • \(viewModel.loopCatalog.availablePartTypes.count) types")
                            .font(.caption).foregroundStyle(.purple.opacity(0.6))
                    }
                }
                Spacer()
                
                // Sort button (available on both Collection and Loops)
                SortButton(viewModel: viewModel, showingSortBubble: $showingSortBubble)
                
                // Grid toggle button (only on Collection)
                if viewModel.activeTab == .collection {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.gridColumns = viewModel.gridColumns == 2 ? 3 : 2
                        }
                    } label: {
                        Image(systemName: viewModel.gridColumns == 2 ? "square.grid.2x2" : "square.grid.3x2")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.top)
    }
}

// MARK: - Sort Button
struct SortButton: View {
    @ObservedObject var viewModel: MusicViewModel
    @Binding var showingSortBubble: Bool
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showingSortBubble.toggle()
            }
        } label: {
            Image(systemName: viewModel.sortOption != .recentlyUpdated ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(viewModel.sortOption != .recentlyUpdated ?
                            AnyShapeStyle(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)) :
                                AnyShapeStyle(Color.white.opacity(0.1))
                )
                .clipShape(Circle())
                .shadow(color: viewModel.sortOption != .recentlyUpdated ? .purple.opacity(0.3) : .clear, radius: 8)
        }
        .overlay(alignment: .topTrailing) {
            // Sort bubble - positioned to appear above tiles
            if showingSortBubble {
                VStack(spacing: 0) {
                    Spacer().frame(height: 56)
                    
                    VStack(spacing: 0) {
                        // Small triangle pointer
                        Triangle()
                            .fill(Color(red: 0.15, green: 0.02, blue: 0.2).opacity(0.95))
                            .frame(width: 20, height: 10)
                            .offset(x: 14)
                        
                        // Bubble content
                        SortBubbleContent(viewModel: viewModel, dismiss: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingSortBubble = false
                            }
                        })
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(red: 0.15, green: 0.02, blue: 0.2).opacity(0.98))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(
                                            LinearGradient(
                                                colors: [.purple.opacity(0.5), .pink.opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                                .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
                        )
                    }
                    .frame(width: 200)
                    .offset(x: -8, y: 0)
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8, anchor: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.8, anchor: .top).combined(with: .opacity)
                ))
                .zIndex(1000) // Ensure it appears above everything
            }
        }
    }
    
    // MARK: - Triangle Shape
    struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}
