//
//  RenderTextures.swift
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

import MetalKit
import CMetalEngine

/// Vertex data as stored in the buffer - don't use any clever types so that everything packs correctly
struct TexturedVertex {
    /// 2D coordinates, origin top-left
    let x, y: Float
    /// Texture coordinates
    let u, v: Float

    init(x: Float, y: Float, u: Float, v: Float) {
        self.x = x
        self.y = y
        self.u = u
        self.v = v
    }

    static func buildVertexDescriptor(bufferIndex: BufferIndex) -> MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[TexturedVertexAttr.position.rawValue].format = .float2
        vertexDescriptor.attributes[TexturedVertexAttr.position.rawValue].offset = 0
        vertexDescriptor.attributes[TexturedVertexAttr.position.rawValue].bufferIndex = bufferIndex.rawValue
        vertexDescriptor.attributes[TexturedVertexAttr.texturePosition.rawValue].format = .float2
        vertexDescriptor.attributes[TexturedVertexAttr.texturePosition.rawValue].offset = MemoryLayout<Self>.offset(of: \.u)!
        vertexDescriptor.attributes[TexturedVertexAttr.texturePosition.rawValue].bufferIndex = bufferIndex.rawValue
        vertexDescriptor.layouts[0].stride = MemoryLayout<Self>.stride
        return vertexDescriptor
    }
}

/// Batch client calls of some primitive type into a single draw call
final class RenderTextures {
    private let textures: Textures
    private var bufferWriter: BufferWriter<TexturedVertex>
    private var currentTexture: Texture2D?

    init(buffers: Buffers, textures: Textures) {
        self.bufferWriter = BufferWriter(buffers: buffers, vertexType: TexturedVertex.self)
        self.textures = textures
        self.currentTexture = nil
    }

    /// Client call
    func render(x0: Float, y0: Float, // top left
                x1: Float, y1: Float, // bottom right
                texture: Texture2D,
                encoder: MTLRenderCommandEncoder) {
        // Always using texture 0 for now so flush if we change...
        if let currentTexture, currentTexture != texture {
            flush(encoder: encoder)
            assert(self.currentTexture == nil)
        }
        if currentTexture == nil {
            currentTexture = texture
            textures.useFragmentTexture(texture, encoder: encoder, index: .texture )
        }
        let vertices: [TexturedVertex] = [
            .init(x: x0, y: y0, u: 0, v: 0),
            .init(x: x1, y: y0, u: 1, v: 0),
            .init(x: x0, y: y1, u: 0, v: 1),
            .init(x: x1, y: y0, u: 1, v: 0),
            .init(x: x0, y: y1, u: 0, v: 1),
            .init(x: x1, y: y1, u: 1, v: 1),

        ]
        if !bufferWriter.add(vertices: vertices) {
            flush(encoder: encoder)
            if !bufferWriter.add(vertices: vertices) {
                preconditionFailure("Too many points in one go? (\(self))")
            }
        }
    }

    /// Renderer calls at end of frame
    func flush(encoder: MTLRenderCommandEncoder) {
        bufferWriter.pend { buffer, usedCount in
            encoder.setVertexBuffer(buffer.mtlBuffer, offset: 0, index: BufferIndex.vertex.rawValue)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: usedCount)
        }
        currentTexture = nil
    }
}

