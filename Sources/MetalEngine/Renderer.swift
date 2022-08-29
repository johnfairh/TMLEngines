//
//  Renderer.swift
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

// * Textures
// ** CreateTexture RGBA
// ** UpdateTexture (for browser..)
// ** DrawTexturedRect
// *** Understand pipeline implications
// *** Restructure for encoder reuse issues
// *** Rename shaders
// *** New shader/buffer/pipeline design for textures
// * What threading guarantees of frame-complete ?
// * Keyboard & mouse input
//
// Extra stuff..
// * voice
// * 

import MetalKit

import CMetalEngine

class Renderer: NSObject, Engine2D, MTKViewDelegate {
    let metalCommandQueue: MTLCommandQueue
    private(set) var twoDPipeline: MTLRenderPipelineState! = nil

    let clientSetup: Engine2DCall
    let clientFrame: Engine2DCall

    let buffers: Buffers
    let textures: Textures
    let points: RenderPrimitives
    let lines: RenderPrimitives
    let triangles: RenderPrimitives
    let text: RenderText

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
        self.textures = Textures(device: metalDevice)
        self.triangles = RenderPrimitives(buffers: buffers, primitiveType: .triangle)
        self.points = RenderPrimitives(buffers: buffers, primitiveType: .point)
        self.lines = RenderPrimitives(buffers: buffers, primitiveType: .line)
        self.text = RenderText(device: metalDevice)

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

            let colorAtt = pipelineDescriptor.colorAttachments[0]!
            colorAtt.pixelFormat = .bgra8Unorm
            colorAtt.isBlendingEnabled = true
            colorAtt.sourceRGBBlendFactor = .sourceAlpha
            colorAtt.destinationRGBBlendFactor = .oneMinusSourceAlpha
            colorAtt.sourceAlphaBlendFactor = .sourceAlpha
            colorAtt.destinationAlphaBlendFactor = .oneMinusSourceAlpha

            pipelineDescriptor.vertexDescriptor = vertexDescriptor
            pipelineDescriptor.vertexBuffers[BufferIndex.vertex.rawValue].mutability = .immutable
            pipelineDescriptor.vertexBuffers[BufferIndex.uniform.rawValue].mutability = .immutable
            pipelineDescriptor.fragmentBuffers[BufferIndex.uniform.rawValue].mutability = .immutable
            return try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }

        twoDPipeline = makePipeline("TwoD", "vertex_2d", "fragment_passthrough")
    }

    // MARK: Uniforms

    private(set) var viewportSize: SIMD2<Float> = .zero
    private(set) var scaleFactor: Float = 0

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        if let window = view.window {
            let cgSize = window.convertFromBacking(NSRect(origin: .zero, size: size)).size
            viewportSize.x = Float(cgSize.width)
            viewportSize.y = Float(cgSize.height)
            scaleFactor = Float(window.backingScaleFactor)
            text.setSize(cgSize)
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
        // How many render pixels to a point - for drawing points
        uniforms.scaleFactor = scaleFactor
    }

    private func setUniforms(in encoder: MTLRenderCommandEncoder) {
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: BufferIndex.uniform.rawValue)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: BufferIndex.uniform.rawValue)
    }

    // MARK: Background colour

    private(set) var clearColor = MTLClearColor(red: 0, green: 1, blue: 0, alpha: 0)

    func setBackgroundColor(_ color: Color2D) {
        clearColor = MTLClearColor(red: Double(color.r), green: Double(color.g), blue: Double(color.b), alpha: 1)
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
        textures.startFrame()

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

        points.flush(encoder: encoder)
        lines.flush(encoder: encoder)
        triangles.flush(encoder: encoder)
        buffers.endFrame(frameID: frameID)
        textures.endFrame(frameID: frameID)
        text.flush(encoder: encoder, rpd: rpd, commandQueue: metalCommandQueue)

        encoder.endEncoding()
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.addCompletedHandler { [frameID] _ in
            self.buffers.completeFrame(frameID: frameID)
        }
        commandBuffer.commit()

        frameID += 1
    }

    // MARK: Primitives

    func drawPoint(x: Float, y: Float, color: Color2D) {
        assert(frameEncoder != nil)
        points.render(points: [.init(x: x, y: y, color: color)], encoder: frameEncoder!)
    }

    func flushPoints() {
        assert(frameEncoder != nil)
        points.flush(encoder: frameEncoder!)
    }

    func drawLine(x0: Float, y0: Float, color0: Color2D,
                  x1: Float, y1: Float, color1: Color2D) {
        assert(frameEncoder != nil)
        lines.render(points: [
            .init(x: x0, y: y0, color: color0),
            .init(x: x1, y: y1, color: color1),
        ], encoder: frameEncoder!)
    }

    func flushLines() {
        assert(frameEncoder != nil)
        lines.flush(encoder: frameEncoder!)
    }

    func drawTriangle(x0: Float, y0: Float, color0: Color2D,
                      x1: Float, y1: Float, color1: Color2D,
                      x2: Float, y2: Float, color2: Color2D) {
        assert(frameEncoder != nil)
        triangles.render(points: [
            .init(x: x0, y: y0, color: color0),
            .init(x: x1, y: y1, color: color1),
            .init(x: x2, y: y2, color: color2),
          ], encoder: frameEncoder!)
    }

    func flushTriangles() {
        assert(frameEncoder != nil)
        triangles.flush(encoder: frameEncoder!)
    }

    func drawText(_ text: String, font: Font2D, color: Color2D,
                  x: Float, y: Float, width: Float, height: Float,
                  align: Font2D.Alignment.Horizontal,
                  valign: Font2D.Alignment.Vertical) {
        assert(frameEncoder != nil)
        self.text.drawText(text, font: font, color: color, x: x, y: y, width: width, height: height, align: align, valign: valign)
    }

    func createTexture(bytes: UnsafeRawPointer, width: Int, height: Int, format: Texture2D.Format) -> Texture2D {
        textures.create(bytes: bytes, width: width, height: height, format: format)
    }

    /// Update a texture - must be the same size and pixel format as at create time
    func updateTexture(_ texture: Texture2D, bytes: UnsafeRawPointer) {
        textures.update(texture: texture, bytes: bytes)
    }
}
