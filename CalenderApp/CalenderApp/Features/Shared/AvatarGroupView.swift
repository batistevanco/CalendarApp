//
//  AvatarGroupView.swift
//  CalenderApp
//
//  Premium overlapping avatars for event attendees. Uses unique, consistent
//  gradients based on initials to make avatars look lively and high-fidelity.
//

import SwiftUI

struct AvatarView: View {
    let name: String
    var size: CGFloat = 28

    private var initials: String {
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        if parts.isEmpty { return "?" }
        if parts.count == 1 { return String(parts[0].prefix(1)) }
        return "\(parts[0].prefix(1))\(parts[1].prefix(1))"
    }

    private var gradient: LinearGradient {
        let colors = [
            [Color(hex: 0x5B6CFF), Color(hex: 0x8A98FF)],
            [Color(hex: 0x2F97FF), Color(hex: 0x6BB1FF)],
            [Color(hex: 0x34C759), Color(hex: 0x6EDB89)],
            [Color(hex: 0xFF9500), Color(hex: 0xFFB446)],
            [Color(hex: 0xFF453A), Color(hex: 0xFF7D75)],
            [Color(hex: 0xAF52DE), Color(hex: 0xC885E8)],
            [Color(hex: 0xFF4F81), Color(hex: 0xFF83A5)]
        ]
        let hash = abs(name.hashValue)
        let idx = hash % colors.count
        return LinearGradient(colors: colors[idx], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        Text(initials.uppercased())
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(gradient)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color(.systemBackground), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }
}

struct AvatarGroupView: View {
    let names: [String]
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: -size * 0.32) {
            ForEach(Array(names.prefix(3).enumerated()), id: \.offset) { index, name in
                AvatarView(name: name, size: size)
                    .zIndex(Double(3 - index))
            }
            if names.count > 3 {
                Text("+\(names.count - 3)")
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(.secondaryLabel))
                    .frame(width: size, height: size)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 1.5)
                    )
                    .zIndex(0)
            }
        }
    }
}
