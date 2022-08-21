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
            MetalView(setup: {GameClient.instance.setup(engine: $0) },
                      frame: { GameClient.instance.frame(engine: $0) })
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

class GameClient {
    static var instance = GameClient()

    private init() {}

    func setup(engine: Engine2D) {
        engine.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
    }

    func frame(engine: Engine2D) {

        let screen = engine.viewportSize

        engine.drawTriangle(x0: screen.x / 2, y0: screen.y / 4,
                            x1: screen.x * (3/4), y1: screen.y * (3/4),
                            x2: screen.x / 4, y2: screen.y * (3/4))
    }
}
