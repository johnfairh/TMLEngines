//
//  Renderer.swift
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

// * Switch to per-vertex style - with float2 or ..3 in code
// * Rename vertex shader!
// * Figure out timing requirements
// * Explore points
// * Add proper add/flush-point APIs
// * Write starfield
// * Lines
// * Text
// * ...
// * Research triple-buffer thing

import MetalKit

import CMetalEngine

class Renderer: NSObject, Engine, MTKViewDelegate {
    private(set) var clearColor: MTLClearColor
    private(set) var viewportSize: SIMD2<Float>

    func setBackgroundColor(r: Double, g: Double, b: Double, a: Double) {
        clearColor = MTLClearColor(red: r, green: g, blue: b, alpha: a)
    }

    let metalDevice: MTLDevice // might not need this, is in MTKView ... but should we be independent of that really?
    let metalCommandQueue: MTLCommandQueue
    let clientSetup: EngineCall
    let clientFrame: EngineCall

    private(set) var passthroughPipeline: MTLRenderPipelineState! = nil

    // MARK: Setup

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
        self.viewportSize = .zero
        super.init()

        view.delegate = self

        buildPipelines()

        bufferSetup()
        clientSetup(self)
    }

    private func buildPipelines() {
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

    // MARK: Uniforms management

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        if let window = view.window {
            let cgSize = window.convertFromBacking(NSRect(origin: .zero, size: size)).size
            viewportSize.x = Float(cgSize.width)
            viewportSize.y = Float(cgSize.height)
        }
    }

    private var uniforms = Uniforms()

    /// The client coordinate system has a 0,0 origin in the top-left of the window and
    /// has ``viewportSize`` points on each axis.
    ///
    /// The shaders expect a 'projection matrix' that converts this space to Metal clip space
    /// which is square [-1,1].
    private func updateUniforms() {
        // Scale to [0,2]
        let scale = matrix_float4x4(diagonal: .init(x: 2.0 / viewportSize.x, y: 2.0 / viewportSize.y, z: 1, w: 1))
        // Translate to [-1,1]
        var translate = matrix_float4x4(1)
        translate.columns.3 = vector_float4(x: -1, y: -1, z: 0, w: 1)
        // Flip vertical
        let vflip = matrix_float4x4(diagonal: .init(x: 1, y: -1, z: 1, w: 1))
        uniforms.projectionMatrix = vflip * translate * scale
    }

    private func setUniforms(in encoder: MTLRenderCommandEncoder) {
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: BufferIndex.uniforms.rawValue)
    }

    // MARK: Frame

    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let rpd = view.currentRenderPassDescriptor,
              let commandBuffer = metalCommandQueue.makeCommandBuffer() else {
            print("No resources to generate frame #1")
            return
        }
        updateUniforms()
        rpd.colorAttachments[0].clearColor = clearColor
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) else {
            print("No resources to generate frame #2")
            return
        }
        setUniforms(in: encoder)
        clientFrame(self)
        bufferRender(encoder: encoder)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    let positionPoints: [Float] = [
        400, 100, 0, 1,
        100, 600, 0, 1,
        700, 600, 0, 1,
    ]

    var positionBuffer: MTLBuffer!

    let colourValues: [Float] = [
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
        encoder.setVertexBuffer(positionBuffer, offset: 0, index: BufferIndex.vertexPositions.rawValue)
        encoder.setVertexBuffer(colourBuffer, offset: 0, index: BufferIndex.vertexColors.rawValue)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)
    }
}
