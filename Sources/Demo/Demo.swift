//
//  Demo.swift
//  Demo
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

import SwiftUI
import MetalEngine

@main
struct Demo: App {
    var body: some Scene {
        WindowGroup {
            MetalView(setup: {_ in }, frame: {_ in })
                .frame(minWidth: 200, minHeight: 100)
        }
    }

    #if SWIFT_PACKAGE
    // Some nonsense to make the app work properly when built outside of Xcode
    init() {
      DispatchQueue.main.async {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
      }
    }
    #endif
}
