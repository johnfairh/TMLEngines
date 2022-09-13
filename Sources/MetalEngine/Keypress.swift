//
//  Keypress.swift
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

import AppKit

///
/// Keypress module to track and report which keys are currently held down.
///
/// Won't work if we have multiple MetalView's in the same window.
final class Keypress: NSResponder {
    private var observer: NSObjectProtocol?
    // Keys that are currently held down.  Letters are always upper case to match the traditional keycap.
    // Just trying to satisfy the interface...
    private var keysDown: Set<VirtualKey>

    override init() {
        keysDown = []
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    func set(window: NSWindow) {
        guard observer == nil else {
            return
        }
        window.makeFirstResponder(self)

        observer = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification,
                                                          object: window, queue: nil) { [weak self] _ in
            self?.focusLost()
        }
    }

    deinit {
        observer.map { NotificationCenter.default.removeObserver($0) }
    }

    override func keyDown(with event: NSEvent) {
        if let key = VirtualKey(keyEvent: event) {
            keysDown.insert(key)
        }
    }

    override func keyUp(with event: NSEvent) {
        if let key = VirtualKey(keyEvent: event) {
            keysDown.remove(key)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        func mod(_ modifier: NSEvent.ModifierFlags, _ vk: VirtualKey) {
            if event.modifierFlags.contains(modifier) {
                keysDown.insert(vk)
            } else {
                keysDown.remove(vk)
            }
        }
        mod(.shift, .shift)
        mod(.control, .control)
    }

    func focusLost() {
        print(keysDown)
        keysDown = []
    }
}

import Carbon.HIToolbox

private let macVkToVK: [Int : VirtualKey] = [
    kVK_Delete : .backspace,
    kVK_Return : .enter,
    kVK_Tab : .tab,
    kVK_Escape : .escape,
    kVK_LeftArrow : .left,
    kVK_RightArrow : .right,
    kVK_UpArrow: .up,
    kVK_DownArrow: .down
]

extension VirtualKey {
    init?(keyEvent: NSEvent) {
        if let special = macVkToVK[Int(keyEvent.keyCode)] {
            self = special
            return
        }
        guard let character = keyEvent.charactersIgnoringModifiers?.first else {
            return nil
        }
        // normalize to uppercase
        self = .printable(character.uppercased().first!)
    }
}
