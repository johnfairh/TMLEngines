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
    private var buffer: Buffer?
    let primitiveType: MTLPrimitiveType

    init(buffers: Buffers, primitiveType: MTLPrimitiveType) {
        self.buffers = buffers
        self.buffer = nil
        self.primitiveType = primitiveType
    }

    /// Client call
    func render(points: [Vertex], encoder: MTLRenderCommandEncoder) {
        func enBuffer() -> Bool {
            if buffer == nil {
                buffer = buffers.allocate()
            }
            return buffer!.add(newVertices: points)
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
        if let buffer {
            encoder.setVertexBuffer(buffer.mtlBuffer, offset: 0, index: BufferIndex.vertex.rawValue)
            encoder.drawPrimitives(type: primitiveType, vertexStart: 0, vertexCount: buffer.usedCount)
            buffers.pend(buffer: buffer)
            self.buffer = nil
        }
    }
}
