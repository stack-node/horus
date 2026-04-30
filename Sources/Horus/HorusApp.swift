import AppKit
import SwiftUI

extension Notification.Name {
    static let quickMenuRequested = Notification.Name("quickMenuRequested")
}

@main
struct HorusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let hotkeyManager = HotkeyManager()
    private let screenshotManager = ScreenshotManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ContentView().environmentObject(hotkeyManager)
        )
        self.popover = popover

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera.on.rectangle", accessibilityDescription: "Horus")
            button.action = #selector(togglePopover)
            button.target = self
        }
        self.statusItem = statusItem

        NotificationCenter.default.addObserver(
            self, selector: #selector(showQuickMenu),
            name: .quickMenuRequested, object: nil
        )

        RadialMenuManager.shared.setSelectionHandler { [weak self] selection in
            guard let self else { return }
            switch selection {
            case .dismiss:
                break
            case .area:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { self.screenshotManager.captureArea() }
            case .window:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { self.screenshotManager.captureWindow() }
            case .screen:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { self.screenshotManager.captureScreen() }
            case .copy:
                self.screenshotManager.copy()
            case .save:
                self.screenshotManager.saveAs()
            case .annotate:
                self.screenshotManager.annotate()
            }
        }

        hotkeyManager.actions[.area] = { [weak self] in self?.triggerCapture(.area) }
        hotkeyManager.actions[.window] = { [weak self] in self?.triggerCapture(.window) }
        hotkeyManager.actions[.screen] = { [weak self] in self?.triggerCapture(.screen) }
        hotkeyManager.actions[.quickMenu] = { RadialMenuManager.shared.present(mode: .atCursor) }
    }

    // MARK: - Private

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func showQuickMenu() {
        popover?.performClose(nil)
        RadialMenuManager.shared.present(mode: .centeredOnMainScreen)
    }

    private func triggerCapture(_ slot: HotkeySlot) {
        popover?.performClose(nil)
        // Give the popover time to fully close before the capture overlay appears.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            switch slot {
            case .area:      self.screenshotManager.captureArea()
            case .window:    self.screenshotManager.captureWindow()
            case .screen:    self.screenshotManager.captureScreen()
            case .quickMenu: break
            }
        }
    }
}
