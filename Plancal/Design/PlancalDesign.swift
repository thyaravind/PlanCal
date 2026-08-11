import SwiftUI

enum PlancalDesign {
    static let cornerRadius: CGFloat = 22
    static let compactCornerRadius: CGFloat = 15
    static let contentWidth: CGFloat = 880
    static let plannerContentWidth: CGFloat = 1040
    static let pagePadding: CGFloat = 24

    static func tint(for scale: PlanningScale) -> Color {
        switch scale {
        case .daily: .teal
        case .weekly: .blue
        case .monthly: .indigo
        case .quarterly: .purple
        case .yearly: .red
        }
    }
}

struct AtmosphericBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var accent: Color = .accentColor

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(.background)

                if !reduceTransparency {
                    LinearGradient(
                        colors: [
                            accent.opacity(0.075),
                            Color.clear,
                            Color.indigo.opacity(0.035)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Circle()
                        .fill(accent.opacity(0.065))
                        .frame(width: 460, height: 460)
                        .blur(radius: 120)
                        .offset(x: -180, y: -260)

                    Circle()
                        .fill(Color.indigo.opacity(0.045))
                        .frame(width: 380, height: 380)
                        .blur(radius: 130)
                        .offset(x: 220, y: 300)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    private let content: Content
    private let contentPadding: CGFloat

    init(contentPadding: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.contentPadding = contentPadding
        self.content = content()
    }

    var body: some View {
        content
            .padding(contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                let shape = RoundedRectangle(cornerRadius: PlancalDesign.cornerRadius, style: .continuous)
                if reduceTransparency {
                    shape.fill(Color.primary.opacity(0.065))
                } else {
                    shape.fill(.thinMaterial)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: PlancalDesign.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PlancalDesign.cornerRadius, style: .continuous)
                    .strokeBorder(
                        Color.primary.opacity(contrast == .increased ? 0.2 : 0.075),
                        lineWidth: contrast == .increased ? 1.25 : 0.75
                    )
                    .allowsHitTesting(false)
            }
            .shadow(color: Color.black.opacity(0.035), radius: 18, y: 7)
    }
}

extension View {
    @ViewBuilder
    func platformEditorFrame(minWidth: CGFloat, idealWidth: CGFloat, minHeight: CGFloat) -> some View {
        #if os(macOS)
        frame(minWidth: minWidth, idealWidth: idealWidth, minHeight: minHeight)
        #else
        self
        #endif
    }

    func adaptiveNavigationTitle(_ title: String) -> some View {
        modifier(AdaptiveNavigationTitleModifier(title: title))
    }
}

private struct AdaptiveNavigationTitleModifier: ViewModifier {
    let title: String

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        content.navigationTitle("")
        #else
        content.navigationTitle(title)
        #endif
    }
}

struct EmptyStateCard: View {
    let icon: PlancalIcon
    let title: String
    let message: String

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                PlancalGlyph(icon: icon, weight: .duotone, size: 22)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 42, height: 42)
                    .background(Color.accentColor.opacity(0.1), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    if !message.isEmpty {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }
}
