// iOS16Compat.swift — back-ports of the iOS 17+ SwiftUI APIs the app uses.
// SPDX-License-Identifier: GPL-3.0+
//
// The deployment target is iOS 16.0. Every helper below calls the real SwiftUI
// API on the OS release that has it and falls back to the closest iOS 16
// behaviour otherwise, so iOS 17 and later render exactly as before.
//
// Where the fallback cannot be identical it is called out on the helper.

import SwiftUI

// MARK: - onChange

extension View {
    /// `onChange(of:initial:_:)` with the iOS 17 two-value closure. Backported to iOS 16 by
    /// remembering the previous value.
    @ViewBuilder
    func onChangeCompat<V: Equatable>(
        of value: V,
        initial: Bool = false,
        _ action: @escaping (_ oldValue: V, _ newValue: V) -> Void
    ) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value, initial: initial, action)
        } else {
            self.modifier(OnChangeCompatModifier(value: value, initial: initial, action: action))
        }
    }

    /// `onChange(of:initial:_:)` with the iOS 17 closure that takes no values.
    @ViewBuilder
    func onChangeCompat<V: Equatable>(
        of value: V,
        initial: Bool = false,
        _ action: @escaping () -> Void
    ) -> some View {
        self.onChangeCompat(of: value, initial: initial) { (_: V, _: V) in
            action()
        }
    }
}

private final class OnChangeCompatTracker<V> {
    var last: V
    init(_ value: V) { last = value }
}

private struct OnChangeCompatModifier<V: Equatable>: ViewModifier {
    let value: V
    let initial: Bool
    let action: (V, V) -> Void
    @State private var tracker: OnChangeCompatTracker<V>

    init(value: V, initial: Bool, action: @escaping (V, V) -> Void) {
        self.value = value
        self.initial = initial
        self.action = action
        _tracker = State(initialValue: OnChangeCompatTracker(value))
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: value) { newValue in
                let oldValue = tracker.last
                tracker.last = newValue
                action(oldValue, newValue)
            }
            .onAppear {
                if initial { action(value, value) }
            }
    }
}

// MARK: - Animation

extension Animation {
    /// `Animation.spring(duration:bounce:)` expressed through the iOS 13 spring, which is
    /// the same curve: response is the perceptual duration, damping is `1 - bounce`.
    private static func compatSpring(duration: Double, bounce: Double) -> Animation {
        let damping = bounce >= 0 ? 1 - bounce : 1 / (1 + bounce)
        return .spring(response: max(0.001, duration), dampingFraction: max(0.01, damping))
    }

    /// `Animation.spring(duration:bounce:)` (iOS 17).
    static func springCompat(duration: Double = 0.5, bounce: Double = 0) -> Animation {
        if #available(iOS 17.0, *) {
            return .spring(duration: duration, bounce: bounce)
        }
        return compatSpring(duration: duration, bounce: bounce)
    }

    /// `Animation.smooth(duration:extraBounce:)` (iOS 17).
    static func smoothCompat(duration: Double = 0.5, extraBounce: Double = 0) -> Animation {
        if #available(iOS 17.0, *) {
            return .smooth(duration: duration, extraBounce: extraBounce)
        }
        return compatSpring(duration: duration, bounce: extraBounce)
    }

    /// `Animation.snappy(duration:extraBounce:)` (iOS 17). The preset itself carries 0.15 bounce.
    static func snappyCompat(duration: Double = 0.5, extraBounce: Double = 0) -> Animation {
        if #available(iOS 17.0, *) {
            return .snappy(duration: duration, extraBounce: extraBounce)
        }
        return compatSpring(duration: duration, bounce: 0.15 + extraBounce)
    }
}

// MARK: - View modifiers newer than iOS 16.0

extension View {
    /// `focusEffectDisabled()` (iOS 17). iOS 16 has no focus effect to disable.
    @ViewBuilder
    func focusEffectDisabledCompat() -> some View {
        if #available(iOS 17.0, *) {
            self.focusEffectDisabled()
        } else {
            self
        }
    }

    /// `buttonRepeatBehavior(.enabled / .disabled)` (iOS 17). iOS 16 buttons do not repeat.
    @ViewBuilder
    func buttonRepeatCompat(_ isEnabled: Bool) -> some View {
        if #available(iOS 17.0, *) {
            self.buttonRepeatBehavior(isEnabled ? .enabled : .disabled)
        } else {
            self
        }
    }

    /// `contentMargins(_:_:for: .scrollContent)` (iOS 17). On iOS 16 scroll content has no
    /// extra margin, which is what every zero-margin call site wants; the few non-zero
    /// margins rely on the surrounding safe-area inset there.
    @ViewBuilder
    func contentMarginsCompat(_ edges: Edge.Set = .all, _ length: CGFloat?) -> some View {
        if #available(iOS 17.0, *) {
            self.contentMargins(edges, length, for: .scrollContent)
        } else {
            self
        }
    }

    /// `scrollBounceBehavior(.always, axes:)` (iOS 16.4).
    @ViewBuilder
    func scrollBounceAlwaysCompat(axes: Axis.Set = [.vertical]) -> some View {
        if #available(iOS 16.4, *) {
            self.scrollBounceBehavior(.always, axes: axes)
        } else {
            self
        }
    }

    /// `presentationBackground(.clear)` (iOS 16.4). Sheets keep the system material on
    /// 16.0 to 16.3.
    @ViewBuilder
    func presentationBackgroundClearCompat() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackground(.clear)
        } else {
            self
        }
    }

    /// `scrollTargetLayout()` (iOS 17). Only meaningful together with scroll position
    /// tracking, which iOS 16 does not have.
    @ViewBuilder
    func scrollTargetLayoutCompat() -> some View {
        if #available(iOS 17.0, *) {
            self.scrollTargetLayout()
        } else {
            self
        }
    }

    /// `scrollPosition(id:anchor:)` (iOS 17). On iOS 16 the binding stays `nil`.
    @ViewBuilder
    func scrollPositionCompat<ID: Hashable>(id: Binding<ID?>, anchor: UnitPoint? = nil) -> some View {
        if #available(iOS 17.0, *) {
            self.scrollPosition(id: id, anchor: anchor)
        } else {
            self
        }
    }

    /// `contentTransition(.symbolEffect(.replace))` (iOS 17). iOS 16 swaps the symbol
    /// without the replace animation.
    @ViewBuilder
    func symbolReplaceTransitionCompat() -> some View {
        if #available(iOS 17.0, *) {
            self.contentTransition(.symbolEffect(.replace))
        } else {
            self
        }
    }

    /// `contentTransition(.symbolEffect)` (iOS 17, automatic variant).
    @ViewBuilder
    func symbolAutomaticTransitionCompat() -> some View {
        if #available(iOS 17.0, *) {
            self.contentTransition(.symbolEffect)
        } else {
            self
        }
    }

    /// `symbolEffect(.bounce, value:)` (iOS 17). iOS 16 shows the symbol without the bounce.
    @ViewBuilder
    func symbolBounceCompat<V: Equatable>(value: V) -> some View {
        if #available(iOS 17.0, *) {
            self.symbolEffect(.bounce, value: value)
        } else {
            self
        }
    }

    /// Two-finger pinch that reports the scale factor. `MagnifyGesture` is iOS 17,
    /// `MagnificationGesture` is its iOS 13 predecessor.
    @ViewBuilder
    func simultaneousPinchCompat(
        onChanged: @escaping (CGFloat) -> Void,
        onEnded: @escaping (CGFloat) -> Void
    ) -> some View {
        if #available(iOS 17.0, *) {
            self.simultaneousGesture(
                MagnifyGesture()
                    .onChanged { onChanged($0.magnification) }
                    .onEnded { onEnded($0.magnification) }
            )
        } else {
            self.simultaneousGesture(
                MagnificationGesture()
                    .onChanged { onChanged($0) }
                    .onEnded { onEnded($0) }
            )
        }
    }
}

// MARK: - ContentUnavailableView

/// `ContentUnavailableView(_:systemImage:description:)` (iOS 17) with an iOS 16 look-alike.
struct ContentUnavailableCompat: View {
    private let title: String
    private let systemImage: String
    private let description: Text?

    init(_ title: String, systemImage: String, description: Text? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    var body: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView(title, systemImage: systemImage, description: description)
        } else {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                if let description {
                    description
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }
}
