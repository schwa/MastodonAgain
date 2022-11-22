import Everything
import SwiftUI

struct ActionButtonStyle: ButtonStyle {
    @Environment(\.isSelected)
    var isSelected

    @Environment(\.isHighlighted)
    var isHighlighted

    @Environment(\.altBadge)
    var altBadge

    @Environment(\.isInflight)
    var isInProgress // TODO: Rename

    func makeBody(configuration: Configuration) -> some View {
        // There's never a designer around when you want one.
        let foregroundColor: Color
        switch (isHighlighted, isSelected, configuration.isPressed) {
        case (true, true, _):
            foregroundColor = .yellow // TODO: What if your accent color is also yellow?
        case (_, _, true):
            foregroundColor = .accentColor
        case (true, _, _):
            foregroundColor = .accentColor
        default:
            foregroundColor = .secondary
        }
        return ZStack {
            ProgressView().controlSize(.small)
                .hidden(!isInProgress)
            configuration.label
                .labelStyle(_LabelStyle())
                .padding(2)
                .foregroundColor(foregroundColor)
                .background((configuration.isPressed ? .thickMaterial : nil))
                .cornerRadius(2)
                .hidden(isInProgress)
        }
    }

    struct _LabelStyle: LabelStyle {
        @Environment(\.isSelected)
        var isSelected

        @Environment(\.isHighlighted)
        var isHighlighted

        @Environment(\.altBadge)
        var altBadge

        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: 1) {
                configuration.icon
                altBadge.map { Text($0) }
                    .font(.caption)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: -

struct AltBadgeKey: EnvironmentKey {
    static var defaultValue: String?
}

extension EnvironmentValues {
    var altBadge: String? {
        get {
            self[AltBadgeKey.self]
        }
        set {
            self[AltBadgeKey.self] = newValue
        }
    }
}

struct AltBadgeModifier: ViewModifier {
    let value: String?
    func body(content: Content) -> some View {
        content.environment(\.altBadge, value)
    }
}

extension View {
    /// Like .badge() but takes a string. Use `@Environment(\.altBadge)` to inspect this value
    func altBadge(_ value: String?) -> some View {
        modifier(AltBadgeModifier(value: value))
    }

    func altBadge(_ value: Int?) -> some View {
        altBadge(value.map { "\($0, format: .number)" })
    }
}

// MARK: -

struct IsHighlightedKey: EnvironmentKey {
    static var defaultValue = false
}

extension EnvironmentValues {
    var isHighlighted: Bool {
        get {
            self[IsHighlightedKey.self]
        }
        set {
            self[IsHighlightedKey.self] = newValue
        }
    }
}

struct IsHighlightedModifier: ViewModifier {
    let value: Bool
    func body(content: Content) -> some View {
        content.environment(\.isHighlighted, value)
    }
}

extension View {
    /// Expresses a desire to highlight this view in someway. Use `@Environment(\.isHighlighted)` to inspect this value
    func highlighted(value: Bool) -> some View {
        self.modifier(IsHighlightedModifier(value: value))
    }
}

// MARK: -

struct IsInflightKey: EnvironmentKey {
    static var defaultValue = false
}

extension EnvironmentValues {
    var isInflight: Bool {
        get {
            self[IsInflightKey.self]
        }
        set {
            self[IsInflightKey.self] = newValue
        }
    }
}

struct IsInflightModifier: ViewModifier {
    let value: Bool
    func body(content: Content) -> some View {
        content.environment(\.isInflight, value)
    }
}

extension View {
    /// Expresses that this view is doing something asynchronous. Use `@Environment(\.isInflight)` to inspect this value
    func inflight(value: Bool) -> some View {
        modifier(IsInflightModifier(value: value))
    }
}

// MARK: -

extension View {
    @ViewBuilder
    func background(_ material: Material?) -> some View {
        if let material {
            background(material)
        }
        else {
            self
        }
    }
}
