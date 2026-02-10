import SwiftUI

enum Theme {
    static let background = Color(red: 0.07, green: 0.07, blue: 0.07)
    static let panel = Color(red: 0.14, green: 0.14, blue: 0.14)
    static let sidebar = Color(red: 0.09, green: 0.09, blue: 0.09)
    static let card = Color(red: 0.16, green: 0.16, blue: 0.16)
    static let border = Color.white.opacity(0.08)
    static let accent = Color(red: 0.38, green: 0.86, blue: 0.74)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.68)
    static let textTertiary = Color.white.opacity(0.45)
    static let glassTint = Color.white.opacity(0.14)
    static let glassStrongTint = Color.white.opacity(0.22)
    static let glassSidebarTint = Color.white.opacity(0.1)
    static let glassFieldTint = Color.white.opacity(0.12)
    static let sheetTint = Color.white.opacity(0.08)
    static let sheetEdge = Color.white.opacity(0.22)
}

struct BlurBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

extension View {
    @ViewBuilder
    func glassSurface(
        cornerRadius: CGFloat,
        tint: Color = Theme.glassTint,
        interactive: Bool = false,
        fallbackFill: Color = Theme.card,
        fallbackStroke: Color = Theme.border
    ) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            glassEffect(.regular.tint(tint).interactive(interactive), in: .rect(cornerRadius: cornerRadius))
        } else {
            background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fallbackFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(fallbackStroke, lineWidth: 1)
                    )
            )
        }
        #else
        background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(fallbackFill)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(fallbackStroke, lineWidth: 1)
                )
        )
        #endif
    }

    @ViewBuilder
    func glassCapsule(
        tint: Color = Theme.glassTint,
        interactive: Bool = false,
        fallbackFill: Color = Theme.card
    ) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            glassEffect(.regular.tint(tint).interactive(interactive), in: .capsule)
        } else {
            background(
                Capsule()
                    .fill(fallbackFill)
            )
        }
        #else
        background(
            Capsule()
                .fill(fallbackFill)
        )
        #endif
    }

    @ViewBuilder
    func glassCircle(
        tint: Color = Theme.glassTint,
        interactive: Bool = false,
        fallbackFill: Color = Theme.card
    ) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            glassEffect(.regular.tint(tint).interactive(interactive), in: .circle)
        } else {
            background(
                Circle()
                    .fill(fallbackFill)
            )
        }
        #else
        background(
            Circle()
                .fill(fallbackFill)
        )
        #endif
    }

    @ViewBuilder
    func glassButtonStyle(prominent: Bool = false) -> some View {
        buttonStyle(GlassButtonStyle(prominent: prominent))
    }

    @ViewBuilder
    func glassSheetRounded(cornerRadius: CGFloat, tint: Color = Theme.sheetTint) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(0.04))
                )
        } else {
            background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
        #else
        background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        #endif
    }

    @ViewBuilder
    func glassSheetBar(tint: Color = Theme.sheetTint) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            glassEffect(.regular.tint(tint), in: .rect(cornerRadius: 0))
                .background(
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                )
        } else {
            background(.ultraThinMaterial)
        }
        #else
        background(.ultraThinMaterial)
        #endif
    }
}

private struct GlassButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassSurface(
                cornerRadius: 12,
                tint: prominent ? Theme.glassStrongTint : Theme.glassTint,
                interactive: true,
                fallbackFill: prominent ? Theme.accent.opacity(0.2) : Theme.card,
                fallbackStroke: .clear
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}
