import AppKit
import SwiftUI

enum RadialMenuSelection {
    case dismiss
    case area
    case window
    case screen
    case copy
    case save
    case annotate
}

final class RadialMenuManager: NSObject {
    static let shared = RadialMenuManager()

    private var window: NSWindow?
    private var selectionHandler: ((RadialMenuSelection) -> Void)?

    override init() {
        super.init()
    }

    func setSelectionHandler(_ handler: @escaping (RadialMenuSelection) -> Void) {
        selectionHandler = handler
    }

    func present(mode: PresentationMode) {
        dismiss()

        let contentRect = NSRect(x: 0, y: 0, width: 360, height: 360)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = false
        window.isReleasedWhenClosed = false

        let menuView = RadialMenuView(selectionHandler: { [weak self, weak window] selection in
            self?.selectionHandler?(selection)
            window?.orderOut(nil)
        })

        window.contentViewController = NSHostingController(rootView: menuView)

        let position: NSPoint
        switch mode {
        case .atCursor:
            position = NSEvent.mouseLocation
        case .centeredOnMainScreen:
            if let mainScreen = NSScreen.main {
                position = NSPoint(
                    x: mainScreen.frame.midX,
                    y: mainScreen.frame.midY
                )
            } else {
                position = NSEvent.mouseLocation
            }
        }

        window.setFrameOrigin(NSPoint(
            x: position.x - contentRect.width / 2,
            y: position.y - contentRect.height / 2
        ))

        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    func dismiss() {
        window?.orderOut(nil)
        window = nil
    }

    enum PresentationMode {
        case atCursor
        case centeredOnMainScreen
    }
}

struct RadialMenuView: View {
    @State private var hoveredIndex: Int? = nil
    let selectionHandler: (RadialMenuSelection) -> Void

    let items: [(icon: String, label: String, selection: RadialMenuSelection)] = [
        ("rectangle.dashed", "Area", .area),
        ("macwindow", "Window", .window),
        ("display", "Screen", .screen),
        ("doc.on.clipboard", "Copy", .copy),
        ("square.and.arrow.down", "Save", .save),
        ("pencil", "Annotate", .annotate),
    ]

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    selectionHandler(.dismiss)
                }

            ForEach(0..<items.count, id: \.self) { index in
                menuButton(index: index)
            }

            Circle()
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                .frame(width: 220, height: 220)
        }
        .frame(width: 360, height: 360)
    }

    private func menuButton(index: Int) -> some View {
        let item = items[index]
        let isHovered = hoveredIndex == index
        let angle = (CGFloat(index) / CGFloat(items.count)) * .pi * 2 - .pi / 2
        let radius: CGFloat = 110
        let x = cos(angle) * radius
        let y = sin(angle) * radius

        return VStack(spacing: 6) {
            Image(systemName: item.icon)
                .font(.title2)
                .foregroundStyle(.white)
            Text(item.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 70, height: 70)
        .background(
            Circle()
                .fill(isHovered ? Color.accentColor : Color(.sRGB, red: 0.2, green: 0.2, blue: 0.2, opacity: 0.8))
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
        )
        .overlay(
            Circle()
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Circle())
        .onHover { hovering in
            hoveredIndex = hovering ? index : nil
        }
        .onTapGesture {
            selectionHandler(item.selection)
        }
        .offset(x: x, y: y)
    }
}
