//
//  Primitives.swift
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

import MetalKit
import CMetalEngine

/// Batch client calls of some primitive type into a single draw call
final class RenderPrimitives {
    let buffers: Buffers
    let primitiveType: MTLPrimitiveType
    private var bufferWriter: BufferWriter<Vertex>

    init(buffers: Buffers, primitiveType: MTLPrimitiveType) {
        self.buffers = buffers
        self.primitiveType = primitiveType
        self.bufferWriter = BufferWriter(vertexType: Vertex.self)
    }

    /// Client call
    func render(points: [Vertex], encoder: MTLRenderCommandEncoder) {
        func enBuffer() -> Bool {
            if bufferWriter.buffer == nil {
                bufferWriter.setBuffer(buffers.allocate())
            }
            return bufferWriter.add(vertices: points)
        }
        if !enBuffer() {
            flush(encoder: encoder)
            if !enBuffer() {
                preconditionFailure("Too many points in one go? (\(self))")
            }
        }
    }

    /// Renderer calls at end of frame
    func flush(encoder: MTLRenderCommandEncoder) {
        if let buffer = bufferWriter.buffer {
            encoder.setVertexBuffer(buffer.mtlBuffer, offset: 0, index: BufferIndex.vertex.rawValue)
            encoder.drawPrimitives(type: primitiveType, vertexStart: 0, vertexCount: bufferWriter.usedCount)
            buffers.pend(buffer: buffer)
            bufferWriter.setBuffer(nil)
        }
    }
}
