//
//  Renderer.swift
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

// * Pull out prim-render, tidy bits and interfaces
// * Figure out colour end-to-end, add back to demo, including background
// * Explore points
// * Write starfield
// * Lines
// * Text
// * Textures
// * ...
// * Research triple-buffer thing (though I seem to have implemented it already!)

import MetalKit

import CMetalEngine

class Renderer: NSObject, Engine2D, MTKViewDelegate {
    let metalCommandQueue: MTLCommandQueue
    private(set) var twoDPipeline: MTLRenderPipelineState! = nil

    let clientSetup: Engine2DCall
    let clientFrame: Engine2DCall

    let buffers: Buffers
    let triangles: RenderPrimitives

    // MARK: Setup

    public init(view: MTKView,
                setup: @escaping (any Engine2D) -> Void,
                frame: @escaping (any Engine2D) -> Void) {
        self.clientSetup = setup
        self.clientFrame = frame

        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            preconditionFailure("MTLCreateSystemDefaultDevice")
        }
        view.device = metalDevice
        guard let commandQueue = metalDevice.makeCommandQueue() else {
            preconditionFailure("MTLMakeCommandQueue")
        }
        self.metalCommandQueue = commandQueue

        self.buffers = Buffers(device: metalDevice)
        self.triangles = RenderPrimitives(buffers: buffers, primitiveType: .triangle)

        super.init()

        view.delegate = self

        buildPipelines(for: metalDevice)
        clientSetup(self)
    }

    private func buildPipelines(for device: MTLDevice) {
#if SWIFT_PACKAGE
        let bundle = Bundle.module
#else
        let bundle = Bundle(for: Self.self)
#endif

        guard let library = try? device.makeDefaultLibrary(bundle: bundle) else {
            preconditionFailure("Can't load metal shader library")
        }

        let vertexDescriptor = Vertex.buildVertexDescriptor(bufferIndex: .vertex)

        func makePipeline(_ label: String, _ vertex: String, _ fragment: String) -> MTLRenderPipelineState {
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.label = label
            pipelineDescriptor.vertexFunction = library.makeFunction(name: vertex)!
            pipelineDescriptor.fragmentFunction = library.makeFunction(name: fragment)!
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.vertexDescriptor = vertexDescriptor
            return try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }

        twoDPipeline = makePipeline("TwoD", "vertex_2d", "fragment_passthrough")
    }

    // MARK: Uniforms

    private(set) var viewportSize: SIMD2<Float> = .zero

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
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: BufferIndex.uniform.rawValue)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: BufferIndex.uniform.rawValue)
    }

    // MARK: Background colour

    private(set) var clearColor = MTLClearColor(red: 0, green: 1, blue: 0, alpha: 0)

    func setBackgroundColor(r: Double, g: Double, b: Double, a: Double) {
        clearColor = MTLClearColor(red: r, green: g, blue: b, alpha: a)
    }

    // MARK: Clock

    private(set) var frameTimestamp = TickCount()
    private      var prevFrameTimestamp = TickCount()

    var frameDelta: TickCount {
        frameTimestamp - prevFrameTimestamp
    }

    private func updateTickCount() {
        prevFrameTimestamp = frameTimestamp
        frameTimestamp = TickCount(CACurrentMediaTime() * 1000)
    }

    // MARK: Frame

    typealias FrameID = UInt64
    private(set) var frameID = FrameID(1000)
    private var frameEncoder: MTLRenderCommandEncoder?

    public func draw(in view: MTKView) {
        guard let rpd = view.currentRenderPassDescriptor,
              let commandBuffer = metalCommandQueue.makeCommandBuffer() else {
            print("No resources to generate frame #1")
            return
        }
        updateUniforms()
        updateTickCount()
        buffers.startFrame()

        rpd.colorAttachments[0].clearColor = clearColor
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) else {
            print("No resources to generate frame #2")
            return
        }
        encoder.setRenderPipelineState(twoDPipeline)
        setUniforms(in: encoder)

        frameEncoder = encoder
        clientFrame(self)
        frameEncoder = nil

        triangles.flush(encoder: encoder)
        buffers.endFrame(frameID: frameID)

        encoder.endEncoding()
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.addCompletedHandler { [frameID] _ in
            self.buffers.completeFrame(frameID: frameID)
        }
        commandBuffer.commit()

        frameID += 1
    }

    // MARK: Primitives

    func drawTriangle(x0: Float, y0: Float, x1: Float, y1: Float, x2: Float, y2: Float) {
        assert(frameEncoder != nil)
        triangles.render(points: [
            .init(x: x0, y: y0, r: 1, g: 0, b: 0),
            .init(x: x1, y: y1, r: 1, g: 0, b: 0),
            .init(x: x2, y: y2, r: 1, g: 0, b: 0),
        ], encoder: frameEncoder!)
    }
}

final class RenderPrimitives {
    let buffers: Buffers
    private var buffer: Buffer?
    let primitiveType: MTLPrimitiveType

    init(buffers: Buffers, primitiveType: MTLPrimitiveType) {
        self.buffers = buffers
        self.buffer = nil
        self.primitiveType = primitiveType
    }

    func render(points: [Vertex], encoder: MTLRenderCommandEncoder) {
        func enBuffer() -> Bool {
            if buffer == nil {
                buffer = buffers.allocate()
            }
            return buffer!.add(newVertices: points)
        }
        if !enBuffer() {
            flush(encoder: encoder)
            _ = enBuffer()
        }
    }

    func flush(encoder: MTLRenderCommandEncoder) {
        if let buffer {
            encoder.setVertexBuffer(buffer.mtlBuffer, offset: 0, index: BufferIndex.vertex.rawValue)
            encoder.drawPrimitives(type: primitiveType, vertexStart: 0, vertexCount: buffer.usedCount)
            buffers.pend(buffer: buffer)
            self.buffer = nil
        }
    }
}
