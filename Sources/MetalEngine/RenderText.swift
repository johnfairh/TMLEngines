//
//  Text.swift
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

import MetalKit
import SpriteKit

/// Text renderer component
///
/// So it turns out that doing text in a modern 2D graphics engine is a whole thing, getting the fonts drawn
/// at all at the right time, and then scaling them is an entire niche.
///
/// We use spritekit here to whack a texture with all the frame's text in -- works because we just want flat
/// text with no scaling or effects.  Just assume SpriteKit is doing all kinds of efficient things under the covers.
final class RenderText {
    let renderer: SKRenderer
    let scene: SKScene

    init(device: MTLDevice) {
        renderer = SKRenderer(device: device)
        scene = SKScene()
        renderer.scene = scene
    }

    /// Set the size, in points (not pixels)
    func setSize(_ size: CGSize) {
        scene.size = size
    }

    /// Position is in engine client space, that is points with origin top-left
    func drawText(_ text: String, font: Font2D, color: Color2D,
                  x: Float, y: Float, width: Float, height: Float,
                  align: Font2D.Alignment.Horizontal,
                  valign: Font2D.Alignment.Vertical) {
        let node = SKLabelNode(text: text)

        node.fontName = font.name
        node.fontSize = CGFloat(font.height)
        node.fontColor = NSColor(calibratedRed: CGFloat(color.r), green: CGFloat(color.g), blue: CGFloat(color.b), alpha: 1)
        node.numberOfLines = 0 // enables "\n" to force linebreak
// Maddeningly these are only for multi-line labels...
//        node.preferredMaxLayoutWidth = CGFloat(width)
//        node.lineBreakMode = .byTruncatingTail
//
// We would have to do truncation manually (bsearch the string...) which is yikes,
// gonna wait and see if we need it.  XXX

        var pos = SIMD2<Float>()

        switch valign {
        case .top:
            node.verticalAlignmentMode = .top
            pos.y = y
        case .center:
            node.verticalAlignmentMode = .center
            pos.y = y + height / 2
        case .bottom:
            node.verticalAlignmentMode = .bottom
            pos.y = y + height
        }
        node.position.y = scene.size.height - CGFloat(pos.y) // fettle coordinate space

        switch align {
        case .left:
            node.horizontalAlignmentMode = .left
            pos.x = x
        case .center:
            node.horizontalAlignmentMode = .center
            pos.x = x + width / 2
        case .right:
            node.horizontalAlignmentMode = .right
            pos.x = x + width
        }
        node.position.x = CGFloat(pos.x)

        scene.addChild(node)
    }

    /// End of frame - render the accumulated text & reset
    func flush(encoder: MTLRenderCommandEncoder, rpd: MTLRenderPassDescriptor, commandQueue: MTLCommandQueue) {
        renderer.render(withViewport: CGRect(origin: .zero, size: scene.size),
                        renderCommandEncoder: encoder,
                        renderPassDescriptor: rpd,
                        commandQueue: commandQueue)
        scene.removeAllChildren()
    }
}
