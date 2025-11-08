//
//  SharedComponents.swift
//  Discography
//
//  Created by Adam Faith on 2025-10-27.
//

import SwiftUI

// MARK: - Labeled Text Field
struct LabeledField: View {
    let label: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2)
                .bold()
                .foregroundStyle(.purple.opacity(0.6))
            
            TextField("Enter \(label.lowercased())", text: $text)
                .foregroundStyle(.white)
                .padding()
                .background(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.3))
                )
                .cornerRadius(12)
        }
    }
}

// MARK: - Progress Choice Button
struct ProgressChoice: View {
    let title: String
    let system: String
    let selected: Bool
    let onTap: () -> Void
    let activeGradient: [Color]
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: system)
                Text(title).bold()
            }
            .font(.caption)
            .foregroundStyle(selected ? .white : (title == "Complete" ? .green : .orange))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        selected ?
                            AnyShapeStyle(
                                LinearGradient(
                                    colors: activeGradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            ) :
                            AnyShapeStyle(
                                (title == "Complete" ? Color.green : Color.orange).opacity(0.1)
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        (title == "Complete" ? Color.green : Color.orange).opacity(0.4),
                        lineWidth: selected ? 2 : 1
                    )
            )
        }
    }
}

// MARK: - Part Type Button
struct PartTypeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .bold()
                .foregroundStyle(isSelected ? .white : .purple.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isSelected ?
                                AnyShapeStyle(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                ) :
                                AnyShapeStyle(Color.white.opacity(0.05))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ?
                                Color.clear :
                                Color.purple.opacity(0.3),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
