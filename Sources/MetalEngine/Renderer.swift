//
//  Renderer.swift
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

// * Proper locking in buffer/texture managers
//
// Extra stuff..
// * voice (no, move this to Steamworks as a separate module)

import MetalKit
import CMetalEngine

class Renderer: NSObject, Engine2D, MTKViewDelegate {
    let metalCommandQueue: MTLCommandQueue
    let flatPipeline: PipelineState
    let texturedPipeline: PipelineState

    let clientSetup: Engine2DCall
    let clientFrame: Engine2DCall

    let buffers: Buffers
    let textures: Textures
    let points: RenderPrimitives
    let lines: RenderPrimitives
    let triangles: RenderPrimitives
    let text: RenderText
    let texturedRects: RenderTextures

    let keypress: Keypress

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

        let library = metalDevice.makeDefaultLibrary(for: Self.self)

        flatPipeline = PipelineState(device: metalDevice, library: library,
                                     label: "Flat", vertex: "vertex_flat", fragment: "fragment_flat",
                                     vertexDescriptor: FlatVertex.buildVertexDescriptor(bufferIndex: .vertex),
                                     withSampler: false)
        
        texturedPipeline = PipelineState(device: metalDevice, library: library,
                                         label: "Textured", vertex: "vertex_textured", fragment: "fragment_textured",
                                         vertexDescriptor: TexturedVertex.buildVertexDescriptor(bufferIndex: .vertex),
                                         withSampler: true)

        self.buffers = Buffers(device: metalDevice)
        self.textures = Textures(device: metalDevice)
        self.triangles = RenderPrimitives(buffers: buffers, primitiveType: .triangle)
        self.points = RenderPrimitives(buffers: buffers, primitiveType: .point)
        self.lines = RenderPrimitives(buffers: buffers, primitiveType: .line)
        self.text = RenderText(device: metalDevice)
        self.texturedRects = RenderTextures(buffers: buffers, textures: textures)

        self.keypress = Keypress()

        super.init()

        view.delegate = self
        clientSetup(self)
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

            keypress.set(window: window)
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

    // MARK: Frame counter

    typealias FrameID = UInt64
    private(set) var frameID = FrameID(1000)

    // MARK: Frame, pipeline selection

    enum Pipeline {
        case none
        case flat
        case textured
    }
    private(set) var currentPipeline = Pipeline.none
    private(set) var frameEncoder: MTLRenderCommandEncoder!

    func select(pipeline: Pipeline) {
        assert(frameEncoder != nil)
        guard pipeline != currentPipeline else {
            return
        }

        switch currentPipeline {
        case .flat:
            points.flush(encoder: frameEncoder)
            lines.flush(encoder: frameEncoder)
            triangles.flush(encoder: frameEncoder)

        case .textured:
            texturedRects.flush(encoder: frameEncoder)

        case .none:
            break
        }

        switch pipeline {
        case .flat:
            flatPipeline.select(encoder: frameEncoder)

        case .textured:
            texturedPipeline.select(encoder: frameEncoder)

        case .none:
            break
        }
        currentPipeline = pipeline
    }

    func flushCurrentPipeline() {
        select(pipeline: .none)
    }

    // MARK: Frame, entrypoint

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
        setUniforms(in: encoder)

        frameEncoder = encoder
        clientFrame(self)
        flushCurrentPipeline()
        frameEncoder = nil

        buffers.endFrame(frameID: frameID)
        textures.endFrame(frameID: frameID)
        text.flush(encoder: encoder, rpd: rpd, commandQueue: metalCommandQueue)

        encoder.endEncoding()
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.addCompletedHandler { [frameID] _ in
            DispatchQueue.main.async { // this is a bit suspicious and really points to locking required in the managers...
                self.buffers.completeFrame(frameID: frameID)
                self.textures.completeFrame(frameID: frameID)
            }
        }
        commandBuffer.commit()

        frameID += 1
    }

    // MARK: Primitives

    func drawPoint(x: Float, y: Float, color: Color2D) {
        assert(frameEncoder != nil)
        select(pipeline: .flat)
        points.render(points: [.init(x: x, y: y, color: color)], encoder: frameEncoder)
    }

    func flushPoints() {
        assert(frameEncoder != nil)
        points.flush(encoder: frameEncoder)
    }

    func drawLine(x0: Float, y0: Float, color0: Color2D,
                  x1: Float, y1: Float, color1: Color2D) {
        assert(frameEncoder != nil)
        select(pipeline: .flat)
        lines.render(points: [
            .init(x: x0, y: y0, color: color0),
            .init(x: x1, y: y1, color: color1),
        ], encoder: frameEncoder)
    }

    func flushLines() {
        assert(frameEncoder != nil)
        lines.flush(encoder: frameEncoder)
    }

    func drawTriangle(x0: Float, y0: Float, color0: Color2D,
                      x1: Float, y1: Float, color1: Color2D,
                      x2: Float, y2: Float, color2: Color2D) {
        assert(frameEncoder != nil)
        select(pipeline: .flat)
        triangles.render(points: [
            .init(x: x0, y: y0, color: color0),
            .init(x: x1, y: y1, color: color1),
            .init(x: x2, y: y2, color: color2),
          ], encoder: frameEncoder)
    }

    func flushTriangles() {
        assert(frameEncoder != nil)
        triangles.flush(encoder: frameEncoder)
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

    func updateTexture(_ texture: Texture2D, bytes: UnsafeRawPointer) {
        textures.update(texture2D: texture, bytes: bytes)
    }

    func drawTexturedRect(x0: Float, y0: Float,
                          x1: Float, y1: Float,
                          texture: Texture2D) {
        assert(frameEncoder != nil)
        select(pipeline: .textured)
        texturedRects.render(x0: x0, y0: y0, x1: x1, y1: y1, texture: texture, encoder: frameEncoder)
    }

    func flushTexturedRects() {
        assert(frameEncoder != nil)
        texturedRects.flush(encoder: frameEncoder)
    }

    func isKeyDown(_ key: VirtualKey) -> Bool {
        keypress.isKeyDown(key)
    }

    func getFirstKeyDown() -> VirtualKey? {
        keypress.getFirstKeyDown()
    }
}

struct PipelineState {
    let pipeline: MTLRenderPipelineState
    let sampler: MTLSamplerState?

    init(device: MTLDevice,
         library: MTLLibrary,
         label: String,
         vertex: String,
         fragment: String,
         vertexDescriptor: MTLVertexDescriptor,
         withSampler: Bool) {

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

        if withSampler {
            let samplerDescriptor = MTLSamplerDescriptor()
            samplerDescriptor.magFilter = .linear
            samplerDescriptor.minFilter = .linear
            samplerDescriptor.sAddressMode = .repeat
            samplerDescriptor.tAddressMode = .repeat
            guard let sampler = device.makeSamplerState(descriptor: samplerDescriptor) else {
                preconditionFailure("MTLDevice.makeSamplerState()")
            }
            self.sampler = sampler
        } else {
            self.sampler = nil
        }
        pipeline = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    func select(encoder: MTLRenderCommandEncoder) {
        encoder.setFragmentSamplerState(sampler, index: SamplerIndex.linear.rawValue)
        encoder.setRenderPipelineState(pipeline)
    }
}

extension Bundle {
    static func findModuleBundle(for clazz: AnyClass) -> Bundle {
#if SWIFT_PACKAGE
        return Bundle.module
#else
        return Bundle(for: clazz)
#endif
    }
}

extension MTLDevice {
    func makeDefaultLibrary(for clazz: AnyClass) -> MTLLibrary {
        guard let library = try? makeDefaultLibrary(bundle: Bundle.findModuleBundle(for: clazz)) else {
            preconditionFailure("Can't load metal shader library")
        }
        return library
    }
}
