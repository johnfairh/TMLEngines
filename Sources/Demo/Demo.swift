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

    let starField = StarField()

    func setup(engine: Engine2D) {
        engine.setBackgroundColor(.rgb(0, 0, 0))
    }

    func frame(engine: Engine2D) {

        starField.render(engine: engine)
        let screen = engine.viewportSize

        engine.drawTriangle(x0: screen.x / 2, y0: screen.y / 4, color0: .rgb(1, 0, 0),
                            x1: screen.x * (3/4), y1: screen.y * (3/4), color1: .rgb(0, 1, 0),
                            x2: screen.x / 4, y2: screen.y * (3/4), color2: .rgb(0, 0, 1))

    }
}

final class StarField {
    private static let STAR_COUNT = 600

    private struct Vertex {
        let x, y: Float
        let color: Color2D

        init(x: Float, y: Float, gray: Float) {
            self.x = x
            self.y = y
            self.color = .rgb(gray, gray, gray)
        }
    }

    private var size: SIMD2<Float> = .zero
    private var stars: [Vertex] = []
    private var scrollCount = 0

    init() {
    }

    /// Generate star positions for the current size
    private func reset(engine: Engine2D) {
        size = engine.viewportSize
        stars = []
        stars.reserveCapacity(Self.STAR_COUNT)
        scrollCount = 0
        for _ in 0..<Self.STAR_COUNT {
            stars.append(Vertex(x: Float.random(in: 0..<size.x),
                                y: Float.random(in: 0..<size.y),
                                gray: Float.random(in: 0.2..<1.0))) // visible shade of gray
        }
    }

    /// Render the star field
    func render(engine: Engine2D) {
        if engine.viewportSize != size {
            reset(engine: engine)
        }

        scrollCount += 1

        stars.forEach { star in
            let scoot = Float(scrollCount) * star.color.r / 4.0 // brighter->faster, max .25/frame
            let newy = star.y - scoot // go up
            engine.drawPoint(x: star.x, y: newy < 0 ? newy + size.y : newy, color: star.color)
        }
    }
}
