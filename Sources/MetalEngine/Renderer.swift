//
//  Renderer.swift
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

import MetalKit

class Renderer: NSObject, Engine, MTKViewDelegate {
    private(set) var clearColor: MTLClearColor
    private(set) var viewportSize: CGSize

    func setBackgroundColor(r: Double, g: Double, b: Double, a: Double) {
        clearColor = MTLClearColor(red: r, green: g, blue: b, alpha: a)
    }

    let metalDevice: MTLDevice // might not need this, is in MTKView ... but should we be independent of that really?
    let metalCommandQueue: MTLCommandQueue
    let clientSetup: EngineCall
    let clientFrame: EngineCall

    public init(view: MTKView,
                setup: @escaping (any Engine) -> Void,
                frame: @escaping (any Engine) -> Void) {
        self.clientSetup = setup
        self.clientFrame = frame

        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            preconditionFailure("MTLCreateSystemDefaultDevice")
        }
        self.metalDevice = metalDevice
        view.device = metalDevice
        guard let commandQueue = metalDevice.makeCommandQueue() else {
            preconditionFailure("MTLMakeCommandQueue")
        }
        self.metalCommandQueue = commandQueue
        self.clearColor = MTLClearColor(red: 0, green: 1, blue: 0, alpha: 0)
        self.viewportSize = view.frame.size
        super.init()

        view.delegate = self
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = true
        view.framebufferOnly = false
        view.drawableSize = view.frame.size
        view.enableSetNeedsDisplay = true

        clientSetup(self)
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize = size
    }

    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let rpd = view.currentRenderPassDescriptor,
              let commandBuffer = metalCommandQueue.makeCommandBuffer() else {
            print("No resources to generate frame #1")
            return
        }
        rpd.colorAttachments[0].clearColor = clearColor
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) else {
            print("No resources to generate frame #2")
            return
        }
        clientFrame(self)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
