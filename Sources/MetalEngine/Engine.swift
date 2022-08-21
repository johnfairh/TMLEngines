//
//  MetalView.swift
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

import Foundation

/// An asbtract interface to a 2D graphics engine, create using ``MetalView``
public protocol Engine2D {
    /// Set the background color
    func setBackgroundColor(r: Double, g: Double, b: Double, a: Double)

    /// Accessor for game screen size in points
    var viewportSize: SIMD2<Float> { get }

    /// Poorly-encapsulated millisecond clock
    typealias TickCount = UInt

    /// Tick count - millisecond clock of the start of the current/most recent frame
    var frameTimestamp: TickCount { get }

    /// Milliseconds since the previous frame
    var frameDelta: TickCount { get }

    /// Primitives
    func drawTriangle(x0: Float, y0: Float, x1: Float, y1: Float, x2: Float, y2: Float)
}

typealias Engine2DCall = (Engine2D) -> Void
