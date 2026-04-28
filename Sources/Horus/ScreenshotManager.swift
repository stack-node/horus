import AppKit
import Foundation
import UniformTypeIdentifiers

final class ScreenshotManager: ObservableObject {
    @Published var lastScreenshotURL: URL?

    // MARK: - Capture

    func captureArea(completion: (() -> Void)? = nil) {
        run(["-i", newSaveURL().path], completion: completion)
    }

    func captureWindow(completion: (() -> Void)? = nil) {
        run(["-i", "-W", newSaveURL().path], completion: completion)
    }

    func captureScreen(completion: (() -> Void)? = nil) {
        run([newSaveURL().path], completion: completion)
    }

    // MARK: - Quick Menu Actions

    func copy() {
        guard let url = lastScreenshotURL, let img = NSImage(contentsOf: url) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([img])
    }

    func saveAs() {
        guard let url = lastScreenshotURL else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = url.lastPathComponent
        panel.directoryURL = url.deletingLastPathComponent()
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        try? FileManager.default.copyItem(at: url, to: dest)
    }

    func revealInFinder() {
        guard let url = lastScreenshotURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func delete() {
        guard let url = lastScreenshotURL else { return }
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        lastScreenshotURL = nil
    }

    func share(from view: NSView) {
        guard let url = lastScreenshotURL else { return }
        let picker = NSSharingServicePicker(items: [url])
        picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
    }

    func annotate() {
        guard let url = lastScreenshotURL else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Private

    private func newSaveURL() -> URL {
        let base = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Horus")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return dir.appendingPathComponent("Screenshot \(df.string(from: Date())).png")
    }

    private func run(_ args: [String], completion: (() -> Void)?) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = args
        task.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                if process.terminationStatus == 0, let path = args.last {
                    self?.lastScreenshotURL = URL(fileURLWithPath: path)
                }
                completion?()
            }
        }
        try? task.run()
    }
}
