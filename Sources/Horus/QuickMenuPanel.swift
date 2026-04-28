import AppKit
import SwiftUI

final class QuickMenuPanel: NSObject {
    private var panel: NSPanel?
    private let screenshots: ScreenshotManager

    var isShown: Bool { panel != nil }

    init(screenshots: ScreenshotManager) {
        self.screenshots = screenshots
    }

    // Called by the popover button — opens centered on screen.
    func show() {
        guard !isShown, let screen = NSScreen.main else { return }
        let center = CGPoint(x: screen.frame.width / 2, y: screen.frame.height / 2)
        open(on: screen, centeredAt: center)
    }

    // Called by the global hotkey — toggles; opens at cursor when showing.
    func toggle() {
        if isShown { dismiss(); return }
        let mouse  = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main!
        let center = CGPoint(
            x: mouse.x - screen.frame.minX,
            y: screen.frame.height - (mouse.y - screen.frame.minY)
        )
        open(on: screen, centeredAt: center)
    }

    func dismiss() {
        panel?.close()
        panel = nil
    }

    // MARK: Private

    private func open(on screen: NSScreen, centeredAt center: CGPoint) {
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let actions = buildActions()
        let hosting = NSHostingView(rootView: QuickMenuView(
            centerPoint: center,
            actions: actions,
            onDismiss: { [weak self] in self?.dismiss() }
        ))
        hosting.frame = screen.frame
        panel.contentView = hosting
        panel.setFrame(screen.frame, display: true)
        panel.orderFront(nil)

        self.panel = panel
    }

    private func buildActions() -> QuickMenuActions {
        // Capture actions need extra time for the menu dismiss animation + panel close.
        func capture(_ block: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { block() }
        }
        return QuickMenuActions(
            area:     { [weak self] in capture { self?.screenshots.captureArea() } },
            window:   { [weak self] in capture { self?.screenshots.captureWindow() } },
            screen:   { [weak self] in capture { self?.screenshots.captureScreen() } },
            copy:     { [weak self] in self?.screenshots.copy() },
            save:     { [weak self] in self?.screenshots.saveAs() },
            annotate: { [weak self] in self?.screenshots.annotate() }
        )
    }
}
