//
//  MetalView.swift
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

import Foundation

public protocol Engine {
    /// Set the background color
    func setBackgroundColor(r: Double, g: Double, b: Double, a: Double)

    /// Accessors for game screen size
    var viewportSize: CGSize { get }
}

typealias EngineCall = (Engine) -> Void
