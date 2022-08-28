//
//  Textures.swift
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

import MetalKit
import CMetalEngine

final class Texture {
    enum State {
        case unused
        case pending
        case pending_free
    }
    private(set) var state: State

    let texture: MTLTexture

    init(texture: MTLTexture) {
        self.state = .unused
        self.texture = texture
    }
}

final class Textures {
    private let device: MTLDevice
    private var textures: [Texture2D: Texture] = [:]
    private var framePending: [Texture] = []
    private var allPending: [Renderer.FrameID: [Texture]] = [:]

    init(device: MTLDevice) {
        self.device = device
    }

    /// Renderer call, start frame - debug only?
    func startFrame() {
        assert(framePending.isEmpty)
    }

    /// Use a texture for something (add entity, ID?)
    func useTexture(_ texture2D: Texture2D) {
        let texture = textures[texture2D]!
        // if ...texture.setPending
        framePending.append(texture)
    }

    /// Renderer call, associate all used textures with this frame
    func endFrame(frameID: Renderer.FrameID) {
        allPending[frameID] = framePending
        framePending = []
    }

    /// Renderer call from CommandBuffer-Complete time -- textures no longer used by GPU
    func completeFrame(frameID: Renderer.FrameID) {
        allPending.removeValue(forKey: frameID)?.forEach { _ in
            // texture delete?
            // set unused
        }
    }

    func create(bytes: UnsafeRawPointer, width: Int, height: Int, format: Texture2D.Format) -> Texture2D {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format.metalFormat, width: width, height: height, mipmapped: false)
        descriptor.usage = .shaderRead
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            preconditionFailure("MTLDevice.makeTexture")
        }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bytes, bytesPerRow: width * 4)
        let texture2D = Texture2D(width: width, height: height, format: format)
        textures[texture2D] = Texture(texture: texture)
        return texture2D
    }

    func update(texture: Texture2D, bytes: UnsafeRawPointer) {
    }
}

extension Texture2D.Format {
    var metalFormat: MTLPixelFormat {
        switch self {
        case .bgra: return .bgra8Unorm
        case .rgba: return .rgba8Unorm
        }
    }
}
