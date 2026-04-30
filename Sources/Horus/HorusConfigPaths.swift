import Foundation

/// All Horus configuration files live under `~/.config/stacknode/horus/`.
enum HorusConfigPaths {
    static let relativeDirectory = ".config/stacknode/horus"

    static var directoryURL: URL {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(relativeDirectory, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        return url
    }

    static var hotkeysURL: URL {
        directoryURL.appendingPathComponent("hotkeys.plist", isDirectory: false)
    }
}
