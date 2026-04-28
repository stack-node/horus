import SwiftUI

extension Notification.Name {
    static let quickMenuRequested = Notification.Name("quickMenuRequested")
}

// MARK: - Action bag

struct QuickMenuActions {
    var area:     () -> Void = {}
    var window:   () -> Void = {}
    var screen:   () -> Void = {}
    var copy:     () -> Void = {}
    var save:     () -> Void = {}
    var annotate: () -> Void = {}
}

// MARK: - Menu item descriptor

private struct MenuItem {
    let icon:   String
    let label:  String
    let angle:  Double      // degrees, 0 = right, clockwise
    let action: (QuickMenuActions) -> Void
}

private let menuItems: [MenuItem] = [
    MenuItem(icon: "rectangle.dashed",      label: "Area",     angle: -90)  { $0.area() },
    MenuItem(icon: "macwindow",             label: "Window",   angle: -30)  { $0.window() },
    MenuItem(icon: "display",               label: "Screen",   angle:  30)  { $0.screen() },
    MenuItem(icon: "doc.on.clipboard",      label: "Copy",     angle:  90)  { $0.copy() },
    MenuItem(icon: "square.and.arrow.down", label: "Save",     angle: 150)  { $0.save() },
    MenuItem(icon: "pencil",                label: "Annotate", angle: -150) { $0.annotate() },
]

// MARK: - View

struct QuickMenuView: View {
    let centerPoint: CGPoint
    let actions:     QuickMenuActions
    let onDismiss:   () -> Void

    @State private var appeared  = false
    @State private var hovered: String? = nil

    private let outerRadius: CGFloat = 172
    private let orbitRadius: CGFloat = 122
    private let bubbleSize:  CGFloat = 90
    private let centerSize:  CGFloat = 60

    var body: some View {
        ZStack {
            // Tap-outside-to-dismiss backdrop
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            GeometryReader { geo in
                ZStack {
                    satelliteLayer
                    centerButton
                }
                // Outer disc fades/scales in first; satellites animate via per-item offsets.
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.18), value: appeared)
                .position(clamped(centerPoint, in: geo.size))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.64)) {
                appeared = true
            }
        }
    }

    // MARK: Sub-views

    private var outerDisc: some View {
        Circle()
            .fill(Color(white: 0.10, opacity: 0.55))
            .overlay { Circle().strokeBorder(Color.white.opacity(0.13), lineWidth: 0.8) }
            .frame(width: outerRadius * 2, height: outerRadius * 2)
            .shadow(color: .black.opacity(0.35), radius: 50, x: 0, y: 20)
    }

    private var satelliteLayer: some View {
        ForEach(Array(menuItems.enumerated()), id: \.element.label) { index, item in
            let rad = item.angle * .pi / 180
            let tx  = orbitRadius * cos(rad)
            let ty  = orbitRadius * sin(rad)
            let isHovered = hovered == item.label

            Button {
                item.action(actions)
                dismiss()
            } label: {
                VStack(spacing: 6) {
                    DarkGlassBubble(icon: item.icon, size: bubbleSize, hovered: isHovered)
                    Text(item.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 1)
                }
            }
            .buttonStyle(.plain)
            .onHover { over in
                withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                    hovered = over ? item.label : nil
                }
            }
            // Spring out from center with per-item stagger
            .offset(x: appeared ? tx : 0, y: appeared ? ty : 0)
            .scaleEffect(appeared ? 1 : 0.25)
            .animation(
                .spring(response: 0.52, dampingFraction: 0.60)
                    .delay(appeared ? Double(index) * 0.052 : 0),
                value: appeared
            )
        }
    }

    private var centerButton: some View {
        Button(action: dismiss) {
            DarkGlassBubble(icon: "xmark", size: centerSize, dimmed: true, hovered: false)
        }
        .buttonStyle(.plain)
        // Center button pops in slightly after the disc
        .scaleEffect(appeared ? 1 : 0.2)
        .animation(.spring(response: 0.4, dampingFraction: 0.68).delay(0.08), value: appeared)
    }

    // MARK: Helpers

    private func dismiss() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { onDismiss() }
    }

    private func clamped(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let margin = outerRadius + 22
        return CGPoint(
            x: max(margin, min(point.x, size.width  - margin)),
            y: max(margin, min(point.y, size.height - margin))
        )
    }
}

// MARK: - DarkGlassBubble

struct DarkGlassBubble: View {
    let icon:    String
    let size:    CGFloat
    var dimmed:  Bool = false
    var hovered: Bool = false

    var body: some View {
        ZStack {
            // Dark charcoal base
            Circle()
                .fill(Color(white: dimmed ? 0.22 : 0.18, opacity: dimmed ? 0.75 : 0.92))

            // Subtle inner gradient — lighter at top-left
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(hovered ? 0.14 : 0.07),
                            Color.clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )

            // Hairline rim — brighter on top, fades at bottom
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(hovered ? 0.55 : 0.28),
                            Color.white.opacity(0.06),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )

            Image(systemName: icon)
                .font(.system(size: size * 0.30, weight: .medium))
                .foregroundStyle(.white.opacity(dimmed ? 0.45 : 0.90))
        }
        .frame(width: size, height: size)
        .scaleEffect(hovered ? 1.10 : 1)
        .shadow(
            color: .black.opacity(hovered ? 0.50 : 0.30),
            radius: hovered ? 18 : 10,
            x: 0,
            y: hovered ? 8 : 4
        )
    }
}

// MARK: - (legacy alias kept for QuickMenuPanel)
typealias GlassBubble = DarkGlassBubble
