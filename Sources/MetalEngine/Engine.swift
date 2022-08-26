//
//  MetalView.swift
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

/// A color.
public struct Color2D {
    /// 0-1
    public let r, g, b, a: Float

    public init(r: Float, g: Float, b: Float, a: Float) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    public static func rgb(_ r: Float, _ g: Float, _ b: Float) -> Color2D {
        Color2D(r: r, g: g, b: b, a: 1)
    }

    public static func rgba(_ r: Float, _ g: Float, _ b: Float, _ a: Float) -> Color2D {
        Color2D(r: r, g: g, b: b, a: a)
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
    func flushPoints()

    /// Primitives - line
    func drawLine(x0: Float, y0: Float, color0: Color2D,
                  x1: Float, y1: Float, color1: Color2D)
    func flushLines()

    /// Primitives - triangle
    func drawTriangle(x0: Float, y0: Float, color0: Color2D,
                      x1: Float, y1: Float, color1: Color2D,
                      x2: Float, y2: Float, color2: Color2D)
    func flushTriangles()

    /// Text - cache fonts at init
    func createFont(style: Font2D.Style, weight: Font2D.Weight, height: Float) -> Font2D

    /// An approximate version of the DirectX original, position parameters describe a rectangle the text goes inside,
    /// aligned according to the align parameters.
    func drawText(_ text: String, font: Font2D, color: Color2D,
                  x: Float, y: Float, width: Float, height: Float,
                  align: Font2D.Alignment.Horizontal,
                  valign: Font2D.Alignment.Vertical)
}

typealias Engine2DCall = (Engine2D) -> Void

public struct Font2D: Hashable {
    public enum Style {
        case proportional
        case monospaced
    }

    public enum Weight {
        case medium
        case bold
    }

    public enum Alignment {
        public enum Vertical: Hashable {
            case top
            case center
            case bottom
        }

        public enum Horizontal: Hashable {
            case left
            case center
            case right
        }
    }

    let name: String
    let height: Float
}

import AppKit

extension Engine2D {
    /// Cache font parameters ...
    func createFont(style: Font2D.Style, weight: Font2D.Weight, height: Float) -> Font2D {
        let font: NSFont
        let fWeight: NSFont.Weight = weight == .medium ? .medium : .bold

        switch style {
        case .monospaced:
            font = NSFont.monospacedSystemFont(ofSize: CGFloat(height), weight: fWeight)
        case .proportional:
            font = NSFont.systemFont(ofSize: CGFloat(height), weight: fWeight)
        }
        return Font2D(name: font.fontName, height: height)
    }
}
