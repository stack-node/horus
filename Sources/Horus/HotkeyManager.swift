import AppKit
import Carbon.HIToolbox

// MARK: - Slot

enum HotkeySlot: String, CaseIterable {
    case area      = "area"
    case window    = "window"
    case screen    = "screen"
    case quickMenu = "quickmenu"

    var carbonID: UInt32 {
        switch self {
        case .area:      return 1
        case .window:    return 2
        case .screen:    return 3
        case .quickMenu: return 4
        }
    }
}

// MARK: - Hotkey

struct Hotkey {
    let keyCode: UInt32
    let modifiers: NSEvent.ModifierFlags
    let keyCharacter: String

    static let globe = Hotkey(keyCode: UInt32(kVK_Function), modifiers: [], keyCharacter: "Globe")

    var isGlobeOnly: Bool { keyCode == UInt32(kVK_Function) && modifiers.isEmpty }

    var displayString: String {
        if isGlobeOnly { return "🌐" }
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option)  { s += "⌥" }
        if modifiers.contains(.shift)   { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + keyCharacter.uppercased()
    }

    var carbonModifiers: UInt32 {
        var c: UInt32 = 0
        if modifiers.contains(.command) { c |= UInt32(cmdKey) }
        if modifiers.contains(.shift)   { c |= UInt32(shiftKey) }
        if modifiers.contains(.option)  { c |= UInt32(optionKey) }
        if modifiers.contains(.control) { c |= UInt32(controlKey) }
        return c
    }

    func encoded() -> [String: Any] {
        ["kc": keyCode, "mr": modifiers.rawValue, "ch": keyCharacter]
    }

    static func decoded(from dict: [String: Any]) -> Hotkey? {
        guard
            let kc = dict["kc"] as? UInt32,
            let mr = dict["mr"] as? UInt,
            let ch = dict["ch"] as? String
        else { return nil }
        return Hotkey(keyCode: kc, modifiers: .init(rawValue: mr), keyCharacter: ch)
    }
}

// MARK: - Manager

final class HotkeyManager: ObservableObject {
    @Published var assignments: [HotkeySlot: Hotkey] = [:]
    @Published var recordingSlot: HotkeySlot?

    var actions: [HotkeySlot: () -> Void] = [:]

    private var keyMonitor: Any?
    private var flagsMonitor: Any?
    private var globeMonitor: Any?
    private var carbonRefs: [HotkeySlot: EventHotKeyRef] = [:]
    private var carbonHandlerRef: EventHandlerRef?
    private let signature: OSType = 0x484F5253 // "HORS"
    private var prevFlags: NSEvent.ModifierFlags = []

    fileprivate static weak var _current: HotkeyManager?

    init() {
        HotkeyManager._current = self
        installCarbonHandler()
        load()
    }

    // MARK: Recording

    func toggleRecording(for slot: HotkeySlot) {
        recordingSlot == slot ? stopRecording() : startRecording(slot)
    }

    private func startRecording(_ slot: HotkeySlot) {
        stopRecording()
        recordingSlot = slot
        prevFlags = NSEvent.modifierFlags

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
            return nil
        }
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChangedDuringRecording(event)
            return event
        }
    }

    func stopRecording() {
        if let m = keyMonitor   { NSEvent.removeMonitor(m);   keyMonitor   = nil }
        if let m = flagsMonitor { NSEvent.removeMonitor(m);   flagsMonitor = nil }
        recordingSlot = nil
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard let slot = recordingSlot else { return }
        if Int(event.keyCode) == kVK_Escape { stopRecording(); return }

        let mods = event.modifierFlags.intersection([.command, .option, .shift, .control])
        guard !mods.isEmpty else { return }

        let ch = event.charactersIgnoringModifiers ?? "?"
        assign(Hotkey(keyCode: UInt32(event.keyCode), modifiers: mods, keyCharacter: ch), to: slot)
        stopRecording()
    }

    private func handleFlagsChangedDuringRecording(_ event: NSEvent) {
        guard let slot = recordingSlot else { return }

        let current  = event.modifierFlags
        let added    = current.subtracting(prevFlags)
        prevFlags    = current

        // Globe/fn pressed alone — no other standard modifiers active
        if added.contains(.function),
           current.intersection([.command, .option, .shift, .control]).isEmpty {
            assign(.globe, to: slot)
            stopRecording()
        }
    }

    // MARK: Assignment

    private func assign(_ hotkey: Hotkey, to slot: HotkeySlot) {
        // Remove previous registration for this slot
        if let ref = carbonRefs[slot] { UnregisterEventHotKey(ref); carbonRefs[slot] = nil }

        if hotkey.isGlobeOnly {
            assignments[slot] = hotkey
            save()
            updateGlobeMonitor()
        } else {
            var hkID = EventHotKeyID(signature: signature, id: slot.carbonID)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                hotkey.keyCode, hotkey.carbonModifiers,
                hkID, GetApplicationEventTarget(), 0, &ref
            )
            guard status == noErr, let ref else { return }
            carbonRefs[slot] = ref
            assignments[slot] = hotkey
            save()
        }
    }

    // MARK: Globe global monitor

    private func updateGlobeMonitor() {
        let hasGlobe = assignments.values.contains(where: { $0.isGlobeOnly })
        if hasGlobe, globeMonitor == nil {
            globeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                self?.handleGlobalFlagsChanged(event)
            }
        } else if !hasGlobe, let m = globeMonitor {
            NSEvent.removeMonitor(m)
            globeMonitor = nil
        }
    }

    private func handleGlobalFlagsChanged(_ event: NSEvent) {
        let current = event.modifierFlags
        let added   = current.subtracting(prevFlags)
        prevFlags   = current

        guard added.contains(.function),
              current.intersection([.command, .option, .shift, .control]).isEmpty
        else { return }

        for (slot, hotkey) in assignments where hotkey.isGlobeOnly {
            fire(carbonID: slot.carbonID)
        }
    }

    // MARK: Carbon handler

    func fire(carbonID: UInt32) {
        guard let slot = HotkeySlot.allCases.first(where: { $0.carbonID == carbonID }) else { return }
        DispatchQueue.main.async { self.actions[slot]?() }
    }

    private func installCarbonHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                var hkID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil,
                    &hkID
                )
                HotkeyManager._current?.fire(carbonID: hkID.id)
                return noErr
            },
            1, &spec, nil, &carbonHandlerRef
        )
    }

    // MARK: Persistence

    private let storageKey = "HorusHotkeys"

    func load() {
        guard let saved = UserDefaults.standard.dictionary(forKey: storageKey) else { return }
        for slot in HotkeySlot.allCases {
            if let d = saved[slot.rawValue] as? [String: Any], let hk = Hotkey.decoded(from: d) {
                assign(hk, to: slot)
            }
        }
    }

    private func save() {
        var dict: [String: Any] = [:]
        for (slot, hk) in assignments { dict[slot.rawValue] = hk.encoded() }
        UserDefaults.standard.set(dict, forKey: storageKey)
    }
}
