//
//  Primitives.swift
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

import MetalKit
import CMetalEngine

/// Vertex data as stored in the buffer - don't use any clever types so that everything packs correctly
struct Vertex {
    /// 2D coordinates, origin top-left
    let x, y: Float
    /// RGBA 0-1 components
    let r, g, b, a: Float

    init(x: Float, y: Float, color: Color2D) {
        self.x = x
        self.y = y
        self.r = color.r
        self.g = color.g
        self.b = color.b
        self.a = color.a
    }

    static func buildVertexDescriptor(bufferIndex: BufferIndex) -> MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[VertexAttr.position.rawValue].format = .float2
        vertexDescriptor.attributes[VertexAttr.position.rawValue].offset = 0
        vertexDescriptor.attributes[VertexAttr.position.rawValue].bufferIndex = bufferIndex.rawValue
        vertexDescriptor.attributes[VertexAttr.color.rawValue].format = .float4
        vertexDescriptor.attributes[VertexAttr.color.rawValue].offset = MemoryLayout<Vertex>.offset(of: \.r)!
        vertexDescriptor.attributes[VertexAttr.color.rawValue].bufferIndex = bufferIndex.rawValue
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        return vertexDescriptor
    }
}

/// Batch client calls of some primitive type into a single draw call
final class RenderPrimitives {
    let primitiveType: MTLPrimitiveType
    private var bufferWriter: BufferWriter<Vertex>

    init(buffers: Buffers, primitiveType: MTLPrimitiveType) {
        self.primitiveType = primitiveType
        self.bufferWriter = BufferWriter(buffers: buffers, vertexType: Vertex.self)
    }

    /// Client call
    func render(points: [Vertex], encoder: MTLRenderCommandEncoder) {
        if !bufferWriter.add(vertices: points) {
            flush(encoder: encoder)
            if !bufferWriter.add(vertices: points) {
                preconditionFailure("Too many points in one go? (\(self))")
            }
        }
    }

    /// Renderer calls at end of frame
    func flush(encoder: MTLRenderCommandEncoder) {
        bufferWriter.pend { buffer, usedCount in
            encoder.setVertexBuffer(buffer.mtlBuffer, offset: 0, index: BufferIndex.vertex.rawValue)
            encoder.drawPrimitives(type: primitiveType, vertexStart: 0, vertexCount: usedCount)
        }
    }
}
