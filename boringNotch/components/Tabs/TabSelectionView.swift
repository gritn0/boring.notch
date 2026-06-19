//
//  TabSelectionView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-25.
//

import Defaults
import SwiftUI

struct TabModel: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let view: NotchViews
}

extension TabModel {
    /// Tabs shown on the left of the notch.
    @MainActor static var leading: [TabModel] {
        var tabs = [TabModel(label: "Home", icon: "house.fill", view: .home)]
        if Defaults[.showCalendar] {
            tabs.append(TabModel(label: "Calendar", icon: "calendar", view: .calendar))
        }
        return tabs
    }

    /// Tabs shown on the right of the notch.
    @MainActor static var trailing: [TabModel] {
        var tabs: [TabModel] = []
        if Defaults[.showMirror] && WebcamManager.shared.cameraAvailable {
            tabs.append(TabModel(label: "Mirror", icon: "web.camera", view: .mirror))
        }
        if Defaults[.boringShelf] {
            tabs.append(TabModel(label: "Shelf", icon: "tray.fill", view: .shelf))
        }
        return tabs
    }
}

struct TabSelectionView: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Namespace var animation
    let tabs: [TabModel]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                    TabButton(label: tab.label, icon: tab.icon, selected: coordinator.currentView == tab.view) {
                        withAnimation(.smooth) {
                            coordinator.currentView = tab.view
                        }
                    }
                    .frame(height: 26)
                    .foregroundStyle(tab.view == coordinator.currentView ? .white : .gray)
                    .background {
                        if tab.view == coordinator.currentView {
                            Capsule()
                                .fill(coordinator.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                        } else {
                            Capsule()
                                .fill(coordinator.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                                .hidden()
                        }
                    }
            }
        }
        .clipShape(Capsule())
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}
