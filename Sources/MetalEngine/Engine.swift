//
//  MetalView.swift
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

/// A color.  Transparency is for cowards.
public struct Color2D {
    /// 0-1
    public let r, g, b: Float

    public init(r: Float, g: Float, b: Float) {
        self.r = r
        self.g = g
        self.b = b
    }

    public static func rgb(_ r: Float, _ g: Float, _ b: Float) -> Color2D {
        Color2D(r: r, g: g, b: b)
    }
}

/// An asbtract interface to a 2D graphics engine, create using ``MetalView``
public protocol Engine2D {
    /// Set the background color
    func setBackgroundColor(_ color: Color2D)

    /// Accessor for game screen size in points
    var viewportSize: SIMD2<Float> { get }

    /// Poorly-encapsulated millisecond clock
    typealias TickCount = UInt

    /// Tick count - millisecond clock of the start of the current/most recent frame
    var frameTimestamp: TickCount { get }

    /// Milliseconds since the previous frame
    var frameDelta: TickCount { get }

    /// Primitives - point
    func drawPoint(x: Float, y: Float, color: Color2D)

    /// Primitives - triangle
    func drawTriangle(x0: Float, y0: Float, color0: Color2D,
                      x1: Float, y1: Float, color1: Color2D,
                      x2: Float, y2: Float, color2: Color2D)
}

typealias Engine2DCall = (Engine2D) -> Void
