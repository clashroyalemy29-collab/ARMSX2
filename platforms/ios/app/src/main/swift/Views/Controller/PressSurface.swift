// PressSurface.swift — visual-only alpha-mask press feedback and UIKit press surface
// SPDX-License-Identifier: GPL-3.0+

import SwiftUI
import UIKit
import Perception

// MARK: - Visual-only alpha-mask press feedback
struct ARMSX2SkinMaskPressEffect: View {
    let button: ARMSX2PadButton
    let skin: VirtualPadSkin
    let descriptor: VPadSkinDescriptor
    let color: Color
    let isPressed: Bool
    let opacity: Double

    private var maskImage: UIImage? {
        let fileName = ControllerAsset.fileName(for: button)
        if let image = ControllerAsset.image(named: fileName, descriptor: descriptor) {
            return image
        }
        if skin != .legacyRefresh,
           let fallback = ControllerAsset.image(named: fileName, skin: .legacyRefresh) {
            return fallback
        }
        return nil
    }

    var body: some View { WithPerceptionTracking { perceptionBodyContent } }

    @MainActor @ViewBuilder private var perceptionBodyContent: some View {
        if isPressed, let image = maskImage {
            Image(uiImage: image)
                .resizable()
                .renderingMode(.template)
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .foregroundStyle(color.opacity(0.34 * opacity))
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .renderingMode(.template)
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFit()
                        .foregroundStyle(color.opacity(0.42 * opacity))
                        .blendMode(.plusLighter)
                }
                .shadow(color: color.opacity(0.42 * opacity), radius: 9)
                .scaleEffect(0.92)
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.06), value: isPressed)
        }
    }
}

@MainActor
enum ARMSX2VirtualPadMaskImageCache {
    private static var cachedImages: [String: UIImage] = [:]
    private static let buttons: [ARMSX2PadButton] = [
        .up, .down, .left, .right,
        .cross, .circle, .square, .triangle,
        .L1, .R1, .L2, .R2,
        .start, .select, .L3, .R3
    ]

    private static func key(button: ARMSX2PadButton, descriptor: VPadSkinDescriptor) -> String {
        let skinKey = descriptor.id
        return "\(skinKey):\(ControllerAsset.fileName(for: button))"
    }

    static func image(for button: ARMSX2PadButton, descriptor: VPadSkinDescriptor) -> UIImage? {
        let cacheKey = key(button: button, descriptor: descriptor)
        if let cached = cachedImages[cacheKey] {
            return cached
        }

        let fileName = ControllerAsset.fileName(for: button)
        let image = ControllerAsset.image(named: fileName, descriptor: descriptor)
            ?? ControllerAsset.image(named: fileName, skin: .legacyRefresh)
        guard let image else {
            return nil
        }

        // preparingForDisplay decodes/prepares the bitmap outside the first real press path when prewarmed.
        let prepared = image.preparingForDisplay() ?? image
        cachedImages[cacheKey] = prepared
        return prepared
    }

    static func prewarm(descriptor: VPadSkinDescriptor) {
        for button in buttons {
            _ = image(for: button, descriptor: descriptor)
        }
    }

    static func releaseForEmulationOnlyMode() {
        cachedImages.removeAll(keepingCapacity: false)
    }
}

enum VirtualPadPressSurfacePolicy {
    /// iOS 27 and later use the UIKit button. So does iOS 16: SwiftUI's DragGesture does not
    /// deliver a second finger there, so pressing X or square while holding the left stick did
    /// nothing. iOS 17 to 26 keep the SwiftUI gesture they have always used.
    static func usesUIKitPressSurface(osMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion) -> Bool {
        osMajorVersion >= 27 || osMajorVersion < 17
    }
}

func ARMSX2UsesUIKitPadPressSurface() -> Bool {
    VirtualPadPressSurfacePolicy.usesUIKitPressSurface()
}

@MainActor
struct UIKitPadPressSurface<Content: View>: UIViewRepresentable {
    let content: Content
    let onPress: (Bool) -> Void

    init(
        onPress: @escaping (Bool) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.onPress = onPress
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(content: content, onPress: onPress)
    }

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
        button.isExclusiveTouch = false
        button.isMultipleTouchEnabled = true

        button.addTarget(context.coordinator, action: #selector(Coordinator.touchDown), for: [.touchDown, .touchDragEnter])
        button.addTarget(context.coordinator, action: #selector(Coordinator.touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])

        let hostedView = context.coordinator.hostingController.view!
        hostedView.backgroundColor = .clear
        hostedView.isUserInteractionEnabled = false
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hostedView)
        NSLayoutConstraint.activate([
            hostedView.topAnchor.constraint(equalTo: button.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            hostedView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: button.trailingAnchor)
        ])

        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {
        context.coordinator.onPress = onPress
        context.coordinator.hostingController.rootView = content
    }

    // Release the button's target/action pairs and detach the hosted view when SwiftUI
    // removes this representable (e.g. a control hidden through a visibility edit). Without
    // this, the retained UIHostingController and stale UIControl targets survive the view
    // removal and can corrupt touch dispatch after the pad is rebuilt.
    static func dismantleView(_ uiView: UIButton, coordinator: Coordinator) {
        uiView.removeTarget(coordinator, action: nil, for: .allEvents)
        coordinator.hostingController.willMove(toParent: nil)
        coordinator.hostingController.view?.removeFromSuperview()
        coordinator.hostingController.removeFromParent()
        coordinator.releasePress()
    }

    @MainActor
    final class Coordinator: NSObject {
        let hostingController: UIHostingController<Content>
        var onPress: (Bool) -> Void
        private var isPressed = false

        init(content: Content, onPress: @escaping (Bool) -> Void) {
            self.hostingController = UIHostingController(rootView: content)
            self.onPress = onPress
        }

        @objc func touchDown() {
            guard !isPressed else {
                return
            }

            isPressed = true
            onPress(true)
        }

        @objc func touchUp() {
            releasePress()
        }

        func releasePress() {
            guard isPressed else {
                return
            }

            isPressed = false
            onPress(false)
        }
    }
}

// MARK: - UIKit single-finger drag (analog stick)

/// Tracks one finger with UIKit touches and reports its translation from where it landed.
///
/// A SwiftUI `DragGesture` on the stick cancels the touches that UIKit buttons in the same
/// hosting view receive, and on iOS 16 it also swallows a second finger. Tracking the stick with
/// plain touches leaves SwiftUI with no recognised gesture, so the buttons keep working while the
/// stick is held. Used wherever `ARMSX2UsesUIKitPadPressSurface()` is true.
@MainActor
struct UIKitPadDragSurface: UIViewRepresentable {
    let onChanged: (CGSize) -> Void
    let onEnded: () -> Void

    func makeUIView(context: Context) -> DragView {
        let view = DragView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true
        view.isExclusiveTouch = false
        view.onChanged = onChanged
        view.onEnded = onEnded
        return view
    }

    func updateUIView(_ view: DragView, context: Context) {
        view.onChanged = onChanged
        view.onEnded = onEnded
    }

    static func dismantleUIView(_ view: DragView, coordinator: ()) {
        view.finish()
    }

    final class DragView: UIView {
        var onChanged: ((CGSize) -> Void)?
        var onEnded: (() -> Void)?
        private var tracked: UITouch?
        private var start: CGPoint = .zero

        // The stick is a circle; corners of its square frame belong to whatever is behind.
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            let radius = min(bounds.width, bounds.height) / 2
            return hypot(point.x - bounds.midX, point.y - bounds.midY) <= radius
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard tracked == nil, let touch = touches.first else { return }
            tracked = touch
            start = touch.location(in: self)
            onChanged?(.zero)
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let tracked, touches.contains(tracked) else { return }
            let point = tracked.location(in: self)
            onChanged?(CGSize(width: point.x - start.x, height: point.y - start.y))
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let tracked, touches.contains(tracked) else { return }
            finish()
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let tracked, touches.contains(tracked) else { return }
            finish()
        }

        func finish() {
            guard tracked != nil else { return }
            tracked = nil
            onEnded?()
        }
    }
}

/// Stick input: UIKit touches where the UIKit press surface is used, the SwiftUI gesture otherwise.
struct PadStickInput: ViewModifier {
    let onChanged: (CGSize) -> Void
    let onEnded: () -> Void

    func body(content: Content) -> some View {
        if ARMSX2UsesUIKitPadPressSurface() {
            content.overlay(UIKitPadDragSurface(onChanged: onChanged, onEnded: onEnded))
        } else {
            content.simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { onChanged($0.translation) }
                    .onEnded { _ in onEnded() }
            )
        }
    }
}
