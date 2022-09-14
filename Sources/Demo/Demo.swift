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
    var monoFont: Font2D! = nil
    var propFont: Font2D! = nil
    var texture1: Texture2D! = nil
    var texture2: Texture2D! = nil

    func setup(engine: Engine2D) {
        engine.setBackgroundColor(.rgb(0, 0, 0))

        monoFont = engine.createFont(style: .monospaced, weight: .bold, height: 10)
        propFont = engine.createFont(style: .proportional, weight: .medium, height: 30)

        texture1 = engine.loadTexture(name: "avatar_bgra", format: .bgra)
        texture2 = engine.loadTexture(name: "avatar_rgba", format: .rgba)
    }

    func frame(engine: Engine2D) {
        let screen = engine.viewportSize

        starField.render(engine: engine)

        engine.drawLine(x0: 0, y0: 0, color0: .rgb(0.1, 0, 0),
                        x1: screen.x - 1, y1: screen.y - 1, color1: .rgb(0.9, 0, 0))

        engine.drawTriangle(x0: screen.x / 2, y0: screen.y / 4, color0: .rgba(1, 0, 0, 0.8),
                            x1: screen.x * (3/4), y1: screen.y * (3/4), color1: .rgba(0, 1, 0, 0.8),
                            x2: screen.x / 4, y2: screen.y * (3/4), color2: .rgba(0, 0, 1, 0.8))

        engine.drawTexturedRect(x0: screen.x / 8, y0: screen.y / 8,
                                x1: screen.x / 8 + screen.x / 4, y1: screen.y / 8 + screen.y / 4,
                                texture: texture1)

        if engine.isKeyDown(.escape) {
            engine.drawTexturedRect(x0: screen.x / 4, y0: screen.y / 4,
                                    x1: screen.x / 4 + screen.x / 4, y1: screen.y / 4 + screen.y / 4,
                                    texture: texture2)
        }

        engine.drawQuad(x0: screen.x - screen.x / 8, y0: 0,
                        x1: screen.x, y1: screen.y / 8,
                        x2: screen.x - screen.x / 8, y2: screen.y / 4,
                        x3: screen.x - screen.x / 4, y3: screen.y / 8,
                        color: .rgba(0.6, 0.55, 0, 0.4))

        engine.drawText("Hello World" + (engine.getFirstKeyDown()?.character ?? ""),
                        font: monoFont,
                        color: .rgb(0, 1, 0),
                        x: screen.x / 4,
                        y: screen.y / 8,
                        width: screen.x / 2,
                        height: screen.y / 8,
                        align: .center,
                        valign: .center)

        engine.drawText("Slime molds taste like gelatine and bananas",
                        font: propFont,
                        color: .rgb(0, 1, 0),
                        x: 0,
                        y: Float((engine.frameTimestamp/50) % UInt(screen.y)),
                        width: screen.x / 2,
                        height: 20,
                        align: .left,
                        valign: .center)
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
        engine.flushPoints() // make them behind everything else
    }
}

extension Engine2D {
    func loadTexture(name: String, format: Texture2D.Format) -> Texture2D {
#if SWIFT_PACKAGE
        let bundle = Bundle.module
#else
        let bundle = Bundle.main
#endif
        guard let url = bundle.url(forResource: "Resources/\(name)", withExtension: nil) else {
            preconditionFailure("Bundle load fail")
        }
        return try! Data(contentsOf: url).withUnsafeBytes { ubp in
            createTexture(bytes: ubp.baseAddress!, width: 64, height: 64, format: format)
        }
    }
}
