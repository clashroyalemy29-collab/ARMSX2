// ShaderSettingsView.swift — the RetroArch shader chain as its own settings page
// SPDX-License-Identifier: GPL-3.0+

import SwiftUI
import Perception

struct ShaderSettingsView: View {
    @State private var settings = SettingsStore.shared
    @Environment(\.menuControllerInputRouter) private var controllerInput
    @Environment(\.menuBackgroundHost) private var backgroundHost
    @State private var selectedCategoryID = "shaders"
    @State private var detailPresented = false
    @State private var controllerTargetOrder: [String] = []
    @State private var ownsFrozenBackground = false

    var body: some View { WithPerceptionTracking { perceptionBodyContent } }

    @MainActor @ViewBuilder private var perceptionBodyContent: some View {
        ShaderWorkspaceView(
            enabled: $settings.shaderChainEnabled,
            presetRef: $settings.shaderChainPresetRef,
            settings: settings,
            controllerInput: controllerInput,
            savesToRunningGame: false,
            onLivePreviewChange: nil,
            selectedCategoryID: $selectedCategoryID,
            detailPresented: $detailPresented,
            reportedControllerTargetOrder: $controllerTargetOrder
        )
        .controllerAccessibilityTargetOrder(effectiveControllerTargetOrder)
        .navigationTitle(settings.localized("Shaders"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(detailPresented)
        .toolbar {
            if detailPresented {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        detailPresented = false
                    } label: {
                        Label(
                            settings.localized("Back"),
                            systemImage: "chevron.left"
                        )
                    }
                    .controllerAccessibilityActionTarget(
                        id: "shader-settings.back",
                        label: settings.localized("Back")
                    ) {
                        detailPresented = false
                    }
                }
            }
        }
        .animation(.smoothCompat(duration: 0.28), value: controllerTargetOrder)
        .onAppear {
            guard !ownsFrozenBackground else { return }
            ownsFrozenBackground = true
            backgroundHost?.beginFrozenPresentation()
        }
        .onDisappear {
            guard ownsFrozenBackground else { return }
            ownsFrozenBackground = false
            backgroundHost?.endFrozenPresentation()
        }
    }

    private var effectiveControllerTargetOrder: [String] {
        (detailPresented ? ["shader-settings.back"] : [])
            + controllerTargetOrder
    }
}
