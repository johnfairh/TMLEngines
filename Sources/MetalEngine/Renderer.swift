//
//  Renderer.swift
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

import MetalKit

class Renderer: NSObject, Engine, MTKViewDelegate {
    func setBackgroundColor(r: Double, g: Double, b: Double, a: Double) {
    }

    var viewportSize: CGSize {
        .init()
    }

    let metalDevice: MTLDevice // might not need this, is in MTKView ... but should we be independent of that really?
    let metalCommandQueue: MTLCommandQueue
    let setup: EngineCall
    let frame: EngineCall

    public init(view: MTKView,
                setup: @escaping (any Engine) -> Void,
                frame: @escaping (any Engine) -> Void) {
        self.setup = setup
        self.frame = frame

        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            preconditionFailure("MTLCreateSystemDefaultDevice")
        }
        self.metalDevice = metalDevice
        view.device = metalDevice
        guard let commandQueue = metalDevice.makeCommandQueue() else {
            preconditionFailure("MTLMakeCommandQueue")
        }
        self.metalCommandQueue = commandQueue
        super.init()

        view.delegate = self
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = true
        view.framebufferOnly = false
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.drawableSize = view.frame.size
        view.enableSetNeedsDisplay = true
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else {
            return
        }
        let commandBuffer = metalCommandQueue.makeCommandBuffer()
        let rpd = view.currentRenderPassDescriptor
        rpd?.colorAttachments[0].clearColor = MTLClearColorMake(0, 1, 0, 1)
        rpd?.colorAttachments[0].loadAction = .clear
        rpd?.colorAttachments[0].storeAction = .store
        let re = commandBuffer?.makeRenderCommandEncoder(descriptor: rpd!)
        re?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
}
