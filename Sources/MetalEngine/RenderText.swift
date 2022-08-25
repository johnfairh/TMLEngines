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
    func drawText(_ text: String, position: SIMD2<Float>) {
        let node = SKLabelNode(text: text)
        node.position = CGPoint(x: CGFloat(position.x), y: CGFloat(Float(scene.size.height) - position.y))
        scene.addChild(node)
    }

    /// End of frame - render the accumulated text & reset
    func flush(encoder: MTLRenderCommandEncoder, rpd: MTLRenderPassDescriptor, commandQueue: MTLCommandQueue) {
        renderer.render(withViewport: CGRect(origin: .zero, size: scene.size),
                        renderCommandEncoder: encoder,
                        renderPassDescriptor: rpd, commandQueue: commandQueue)
        scene.removeAllChildren()
    }
}
