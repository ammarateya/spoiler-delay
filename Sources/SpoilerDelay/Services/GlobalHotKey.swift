import Carbon
import Foundation

@MainActor
final class GlobalHotKey {
    private var reference: EventHotKeyRef?
    private var handlerReference: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return noErr }
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard id.signature == OSType(0x5350444C) else { return noErr } // SPDL
            let instance = Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in instance.action() }
            return noErr
        }, 1, &eventType, pointer, &handlerReference)
        registerFromDefaults()
    }

    func registerFromDefaults() {
        if let reference { UnregisterEventHotKey(reference) }
        reference = nil
        guard UserDefaults.standard.object(forKey: "hotKeyEnabled") as? Bool ?? true else { return }

        let key = UserDefaults.standard.string(forKey: "hotKeyLetter") ?? "S"
        let keyCode: UInt32 = ["S": 1, "D": 2, "P": 35, "M": 46][key] ?? 1
        var modifiers: UInt32 = 0
        if UserDefaults.standard.object(forKey: "hotKeyOption") as? Bool ?? true { modifiers |= UInt32(optionKey) }
        if UserDefaults.standard.object(forKey: "hotKeyShift") as? Bool ?? true { modifiers |= UInt32(shiftKey) }
        if UserDefaults.standard.bool(forKey: "hotKeyControl") { modifiers |= UInt32(controlKey) }
        if UserDefaults.standard.bool(forKey: "hotKeyCommand") { modifiers |= UInt32(cmdKey) }
        let id = EventHotKeyID(signature: OSType(0x5350444C), id: 1)
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &reference)
    }
}
