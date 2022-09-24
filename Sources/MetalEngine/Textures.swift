//
//  Textures.swift
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

import MetalKit
import CMetalEngine

// MARK: Texture

/// A texture, potentially owned by the GPU
final class Texture {
    /// Lifetime state
    private(set) var isFlushing: Bool

    /// Metal texture
    let metalTexture: MTLTexture

    init(metalTexture: MTLTexture) {
        self.isFlushing = false
        self.metalTexture = metalTexture
    }

    /// Draw command scheduled referencing the texture
    ///
    /// - returns: ``true`` if the texture was not previously scheduled
    func setFlushing() -> Bool {
        defer { isFlushing = true }
        return !isFlushing
    }

    /// Device no longer referencing the texture
    func clearFlushing() {
        assert(isFlushing)
        isFlushing = false
    }
}

// MARK: Textures

final class Textures {
    private let device: MTLDevice

    private let lock = Lock()
    private var textures: [UUID: Texture] = [:]
    private var frameFlushing: [Texture] = []
    private var allFlushing: [Renderer.FrameID: [Texture]] = [:]

    init(device: MTLDevice) {
        self.device = device
    }

    /// Renderer call, start frame - debug only?
    func startFrame() {
        assert(frameFlushing.isEmpty)
    }

    /// Use a texture for something (add entity, ID?)
    func useFragmentTexture(_ texture2D: Texture2D, encoder: MTLRenderCommandEncoder, index: TextureIndex) {
        lock.locked {
            let texture = textures[texture2D.uuid]!
            if texture.setFlushing() {
                frameFlushing.append(texture)
            }
            encoder.setFragmentTexture(texture.metalTexture, index: index.rawValue)
        }
    }

    /// Renderer call, associate all used textures with this frame
    func endFrame(frameID: Renderer.FrameID) {
        lock.locked {
            allFlushing[frameID] = frameFlushing
            frameFlushing = []
        }
    }

    /// Renderer call from CommandBuffer-Complete time -- textures no longer used by GPU
    func completeFrame(frameID: Renderer.FrameID) {
        lock.locked {
            allFlushing.removeValue(forKey: frameID)?.forEach { texture in
                texture.clearFlushing()
            }
        }
    }

    /// Create a new texture from a raw in-memory buffer
    func create(bytes: UnsafeRawPointer, width: Int, height: Int, format: Texture2D.Format) -> Texture2D {
        lock.locked {
            let texture2D = Texture2D(width: width, height: height, format: format)
            let metalTexture = texture2D.makeMetalTexture(device: device)
            texture2D.replaceBytes(metalTexture: metalTexture, bytes: bytes)
            textures[texture2D.uuid] = Texture(metalTexture: metalTexture)
            return texture2D
        }
    }

    /// Change the content of a texture -- if the texture is currently being sent to the GPU then a new texture buffer is
    /// created and the existing one discarded when the GPU is done.
    func update(texture2D: Texture2D, bytes: UnsafeRawPointer) {
        lock.locked {
            guard var texture = textures[texture2D.uuid] else {
                preconditionFailure("Missing Texture2D \(texture2D)")
            }
            if texture.isFlushing {
                let newMetalTexture = texture2D.makeMetalTexture(device: device)
                texture = Texture(metalTexture: newMetalTexture)
                textures[texture2D.uuid] = texture
            }
            texture2D.replaceBytes(metalTexture: texture.metalTexture, bytes: bytes)
        }
    }
}

// MARK: Metal interface helpers

extension Texture2D.Format {
    var metalFormat: MTLPixelFormat {
        switch self {
        case .bgra: return .bgra8Unorm
        case .rgba: return .rgba8Unorm
        }
    }
}

private extension Texture2D {
    func makeMetalTexture(device: MTLDevice) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: format.metalFormat,
            width: width,
            height: height,
            mipmapped: false)
        descriptor.usage = .shaderRead
        guard let metalTexture = device.makeTexture(descriptor: descriptor) else {
            preconditionFailure("MTLDevice.makeTexture")
        }
        return metalTexture
    }

    func replaceBytes(metalTexture: MTLTexture, bytes: UnsafeRawPointer) {
        metalTexture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bytes, bytesPerRow: width * 4)
    }
}
