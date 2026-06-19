//
//  TabButton.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-24.
//

import AppKit
import SwiftUI

struct TabButton: View {
    let label: String
    let icon: String
    let selected: Bool
    let onClick: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onClick) {
            Image(systemName: icon)
                .padding(.horizontal, 8)
                .frame(maxHeight: .infinity)
                .contentShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
        .background {
            // Subtle highlight on hover (only when not the active tab) so the
            // button reads as clickable. Fills the full tab height to match the
            // active-tab background.
            Capsule()
                .fill(Color.white)
                .opacity(isHovering && !selected ? 0.2 : 0)
        }
        .scaleEffect(isHovering && !selected ? 1.08 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

#Preview {
    TabButton(label: "Home", icon: "tray.fill", selected: true) {
        print("Tapped")
    }
}
