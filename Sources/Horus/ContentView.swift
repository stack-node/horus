import SwiftUI

struct ContentView: View {
    @EnvironmentObject var hotkeyManager: HotkeyManager

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            captureButtons
            Divider()
            recentCaptures
            Divider()
            footer
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
    }

    private var header: some View {
        HStack {
            Image(systemName: "camera.on.rectangle")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Horus")
                .font(.headline.weight(.semibold))
            Spacer()
            Button {
                // settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var captureButtons: some View {
        VStack(spacing: 8) {
            CaptureButton(
                icon: "rectangle.dashed",
                title: "Capture Area",
                subtitle: "Select a region",
                hotkeyLabel: hotkeyManager.assignments[.area]?.displayString,
                isRecording: hotkeyManager.recordingSlot == .area,
                onHotkeyTap: { hotkeyManager.toggleRecording(for: .area) }
            )
            CaptureButton(
                icon: "macwindow",
                title: "Capture Window",
                subtitle: "Click a window",
                hotkeyLabel: hotkeyManager.assignments[.window]?.displayString,
                isRecording: hotkeyManager.recordingSlot == .window,
                onHotkeyTap: { hotkeyManager.toggleRecording(for: .window) }
            )
            CaptureButton(
                icon: "display",
                title: "Capture Screen",
                subtitle: "Full display",
                hotkeyLabel: hotkeyManager.assignments[.screen]?.displayString,
                isRecording: hotkeyManager.recordingSlot == .screen,
                onHotkeyTap: { hotkeyManager.toggleRecording(for: .screen) }
            )
            CaptureButton(
                icon: "filemenu.and.selection",
                title: "Quick Menu",
                subtitle: "Pick from recent captures",
                hotkeyLabel: hotkeyManager.assignments[.quickMenu]?.displayString,
                isRecording: hotkeyManager.recordingSlot == .quickMenu,
                onHotkeyTap: { hotkeyManager.toggleRecording(for: .quickMenu) }
            ) {
                NotificationCenter.default.post(name: .quickMenuRequested, object: nil)
            }
        }
        .padding(12)
    }

    private var recentCaptures: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recents")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<5) { _ in
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.quaternary)
                            .frame(width: 80, height: 52)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Copy Last") {}
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Open Folder") {}
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - CaptureButton

private struct CaptureButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let hotkeyLabel: String?
    let isRecording: Bool
    let onHotkeyTap: () -> Void
    var action: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            HotkeyBadge(hotkey: hotkeyLabel, isRecording: isRecording)
                .onTapGesture { onHotkeyTap() }

            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.separator, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - HotkeyBadge

private struct HotkeyBadge: View {
    let hotkey: String?
    let isRecording: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isRecording ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isRecording ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.12),
                            style: StrokeStyle(lineWidth: 1, dash: isRecording ? [] : [3, 2])
                        )
                )

            if isRecording {
                Text("type keys")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            } else if let hotkey {
                Text(hotkey)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "keyboard")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 44, height: 44)
    }
}
