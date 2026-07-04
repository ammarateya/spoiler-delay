import AppKit
import Combine
import SwiftUI

@main
struct SpoilerDelayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            SettingsView(model: AppRuntime.model)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    private var statusController: StatusPopoverController?
    private var hotKey: GlobalHotKey?

    override init() {
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let model = AppRuntime.model
        statusController = StatusPopoverController(model: model)
        hotKey = GlobalHotKey { [weak self] in self?.statusController?.toggle() }
        model.start()
    }

    func reconfigureHotKey() {
        hotKey?.registerFromDefaults()
    }

    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

@MainActor
final class StatusPopoverController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let model: AppModel
    private var cancellables: Set<AnyCancellable> = []

    init(model: AppModel) {
        self.model = model
        super.init()
        popover.contentSize = NSSize(width: 360, height: 500)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: RootPopoverView(model: model))
        if let button = item.button {
            button.target = self
            button.action = #selector(toggleFromButton)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel("Spoiler Delay")
        }
        model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in self?.updateItem() }
            }
            .store(in: &cancellables)
        updateItem()
    }

    @objc private func toggleFromButton() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggle()
        }
    }

    func toggle() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = item.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateItem() {
        guard let button = item.button else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        button.image = NSImage(systemSymbolName: model.statusSymbol, accessibilityDescription: "Spoiler Delay")?.withSymbolConfiguration(config)
        button.image?.isTemplate = true
        if let session = model.session {
            let remaining = max(0, session.automaticEnd.timeIntervalSinceNow)
            button.title = remaining < 60 * 60 ? " \(DelayMath.format(remaining))" : ""
            button.toolTip = "Protecting \(session.match.title)"
        } else {
            button.title = ""
            button.toolTip = "Spoiler Delay"
        }
    }

    private func showContextMenu() {
        guard let button = item.button else { return }
        let menu = NSMenu()
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Spoiler Delay…", action: #selector(confirmQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
    }

    @objc private func openSettings() {
        AppDelegate.shared?.openSettings()
    }

    @objc private func confirmQuit() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Quit Spoiler Delay?"
        alert.informativeText = "Native Messages notifications are disabled. New replacement alerts will stop until Spoiler Delay is reopened."
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { NSApp.terminate(nil) }
    }
}
