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

        clientSetup(self)
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize = size // XXX need to decide if this should be points or pixels
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
        let functionNames = [
            "vertex_passthrough",
            "fragment_passthrough"
        ]
        let functions = Dictionary<String, MTLFunction>(
            uniqueKeysWithValues: functionNames.map { name in
                (name, library.makeFunction(name: name)!)
            }
        )

        let passthroughDescriptor = MTLRenderPipelineDescriptor()
        passthroughDescriptor.label = "Passthrough"
        passthroughDescriptor.vertexFunction = functions["vertex_passthrough"]
        passthroughDescriptor.fragmentFunction = functions["fragment_passthrough"]
        passthroughDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        passthroughPipeline = try! metalDevice.makeRenderPipelineState(descriptor: passthroughDescriptor)
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
