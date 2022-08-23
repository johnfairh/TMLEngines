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
        engine.setBackgroundColor(.rgb(0, 0, 0))
    }

    func frame(engine: Engine2D) {

        let screen = engine.viewportSize

//        engine.drawTriangle(x0: screen.x / 2, y0: screen.y / 4, color0: .rgb(1, 0, 0),
//                            x1: screen.x * (3/4), y1: screen.y * (3/4), color1: .rgb(0, 1, 0),
//                            x2: screen.x / 4, y2: screen.y * (3/4), color2: .rgb(0, 0, 1))
        engine.drawPoint(x: screen.x / 2, y: screen.y / 4, color: .rgb(1, 0, 0))
//                            x1: screen.x * (3/4), y1: screen.y * (3/4), color1: .rgb(0, 1, 0),
//                            x2: screen.x / 4, y2: screen.y * (3/4), color2: .rgb(0, 0, 1))

    }
}
