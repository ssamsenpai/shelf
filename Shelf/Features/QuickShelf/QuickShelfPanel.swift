import AppKit
import Carbon.HIToolbox
import SwiftUI

/// The floating Quick Shelf panel: summoned from any app with the global hotkey,
/// non activating so the frontmost app keeps focus and drags land naturally.
@MainActor
final class QuickShelfController {
    static let shared = QuickShelfController()

    private var panel: NSPanel?
    private var hotKey: GlobalHotKey?
    private var resignObserver: (any NSObjectProtocol)?

    private let panelSize = NSSize(width: 680, height: 480)

    func install() {
        guard hotKey == nil else { return }
        hotKey = GlobalHotKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)) {
            Task { @MainActor in
                QuickShelfController.shared.toggle()
            }
        }
    }

    func toggle() {
        if let panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        let panel = self.panel ?? makePanel()
        self.panel = panel

        // Fresh content each summon: state resets and the appear animation runs.
        let host = NSHostingView(rootView: QuickShelfView { [weak self] in
            self?.hide()
        })
        host.frame = NSRect(origin: .zero, size: panelSize)
        panel.contentView = host

        position(panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.14
            panel.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
            }
        })
    }

    // MARK: Setup

    private func makePanel() -> NSPanel {
        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .modalPanel
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false

        // Clicking anywhere else dismisses, like Spotlight.
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { _ in
            Task { @MainActor in
                QuickShelfController.shared.hide()
            }
        }
        return panel
    }

    /// Upper third of the screen the pointer is on, like Spotlight.
    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) }
            ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }

        let origin = NSPoint(
            x: frame.midX - panelSize.width / 2,
            y: frame.minY + frame.height * 0.68 - panelSize.height / 2
        )
        panel.setFrameOrigin(origin)
    }
}

/// Borderless panels refuse key status unless told otherwise, and the field
/// needs it for typing. Escape closes.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        Task { @MainActor in
            QuickShelfController.shared.hide()
        }
    }
}

/// A Carbon global hotkey. The system API works sandboxed and needs no
/// accessibility permission, unlike event taps.
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let handler: () -> Void

    init?(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        self.handler = handler

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, _, userData in
            guard let userData else { return noErr }
            let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            hotKey.handler()
            return noErr
        }

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        guard InstallEventHandler(
            GetEventDispatcherTarget(), callback, 1, &eventType, selfPointer, &handlerRef
        ) == noErr else { return nil }

        let hotKeyID = EventHotKeyID(signature: OSType(0x5348_4C46), id: 1) // SHLF
        guard RegisterEventHotKey(
            keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef
        ) == noErr else { return nil }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
