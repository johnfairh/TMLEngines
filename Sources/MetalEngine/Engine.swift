//
//  MetalView.swift
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

import Foundation

/// An asbtract interface to a 2D graphics engine, create using ``MetalView``
public protocol Engine {
    /// Set the background color
    func setBackgroundColor(r: Double, g: Double, b: Double, a: Double)

    /// Accessor for game screen size in points
    var viewportSize: SIMD2<Float> { get }
}

typealias EngineCall = (Engine) -> Void
