import SwiftUI

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(Theme.accent)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        .glassSurface(cornerRadius: 14, tint: Theme.glassTint, interactive: false, fallbackFill: Theme.card, fallbackStroke: .clear)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }
}

struct PillToggle: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassCapsule(
                    tint: isSelected ? Theme.glassStrongTint : Theme.glassTint,
                    interactive: true,
                    fallbackFill: isSelected ? Theme.card.opacity(0.9) : Color.white.opacity(0.05)
                )
        }
        .buttonStyle(.plain)
    }
}

struct DayToggle: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .frame(width: 28, height: 28)
                .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textTertiary)
                .glassCircle(
                    tint: isSelected ? Theme.glassStrongTint : Theme.glassTint,
                    interactive: true,
                    fallbackFill: isSelected ? Theme.card.opacity(0.9) : Color.white.opacity(0.05)
                )
        }
        .buttonStyle(.plain)
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.bold())
            .foregroundStyle(Theme.textSecondary)
    }
}

struct ErrorToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.red)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassSurface(cornerRadius: 12, tint: Theme.glassStrongTint, interactive: false, fallbackFill: Theme.card, fallbackStroke: .clear)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

struct FieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(10)
            .glassSurface(
                cornerRadius: 10,
                tint: Theme.glassFieldTint,
                interactive: true,
                fallbackFill: Color.white.opacity(0.05),
                fallbackStroke: Theme.border
            )
    }
}

extension View {
    func fieldBackground() -> some View {
        modifier(FieldBackground())
    }
}
