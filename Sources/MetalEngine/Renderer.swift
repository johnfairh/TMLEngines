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

    private(set) var passthroughPipeline: MTLRenderPipelineState! = nil

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
        self.viewportSize = view.frame.size // XXX need to decide if this should be points or pixels
        super.init()

        view.delegate = self

        buildPipelines()

        bufferSetup()
        clientSetup(self)
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize = size // XXX need to decide if this should be points or pixels YYY has to be points
    }

    func buildPipelines() {
#if SWIFT_PACKAGE
        let bundle = Bundle.module
#else
        let bundle = Bundle(for: Self.self)
#endif

        guard let library = try? metalDevice.makeDefaultLibrary(bundle: bundle) else {
            preconditionFailure("Can't load metal shader library")
        }

        func makePipeline(_ label: String, _ vertex: String, _ fragment: String) -> MTLRenderPipelineState {
            let passthroughDescriptor = MTLRenderPipelineDescriptor()
            passthroughDescriptor.label = label
            passthroughDescriptor.vertexFunction = library.makeFunction(name: vertex)!
            passthroughDescriptor.fragmentFunction = library.makeFunction(name: fragment)!
            passthroughDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            return try! metalDevice.makeRenderPipelineState(descriptor: passthroughDescriptor)

        }
        passthroughPipeline = makePipeline("Passthrough", "vertex_passthrough", "fragment_passthrough")
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
        bufferRender(encoder: encoder)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    let positionPoints: [Float] = [
        0.0,  0.5, 0, 1,
        -0.5, -0.5, 0, 1,
        0.5, -0.5, 0, 1,
        -0.9, -0.9, 0, 1,
        -0.7, -0.9, 0, 1,
        -0.8, -0.7, 0, 1
    ]

    var positionBuffer: MTLBuffer!

    let colourValues: [Float] = [
        1, 0, 0, 1,
        0, 1, 0, 1,
        0, 0, 1, 1,
        1, 0, 0, 1,
        0, 1, 0, 1,
        0, 0, 1, 1,
    ]

    var colourBuffer: MTLBuffer!

    func bufferSetup() {
        positionBuffer = metalDevice.makeBuffer(bytes: positionPoints, length: MemoryLayout<Float>.stride * positionPoints.count)
        colourBuffer = metalDevice.makeBuffer(bytes: colourValues, length: MemoryLayout<Float>.stride * colourValues.count)
    }

    func bufferRender(encoder: MTLRenderCommandEncoder) {
        encoder.setRenderPipelineState(passthroughPipeline)
        encoder.setVertexBuffer(positionBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(colourBuffer, offset: 0, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: 1)
    }
}
