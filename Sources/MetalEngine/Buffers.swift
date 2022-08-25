//
//  Buffers.swift
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
    /// RGB 0-1 components
    let r, g, b: Float

    init(x: Float, y: Float, color: Color2D) {
        self.x = x
        self.y = y
        self.r = color.r
        self.g = color.g
        self.b = color.b
    }

    static func buildVertexDescriptor(bufferIndex: BufferIndex) -> MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[VertexAttr.position.rawValue].format = .float2
        vertexDescriptor.attributes[VertexAttr.position.rawValue].offset = 0
        vertexDescriptor.attributes[VertexAttr.position.rawValue].bufferIndex = bufferIndex.rawValue
        vertexDescriptor.attributes[VertexAttr.color.rawValue].format = .float3
        vertexDescriptor.attributes[VertexAttr.color.rawValue].offset = MemoryLayout<Vertex>.offset(of: \.r)!
        vertexDescriptor.attributes[VertexAttr.color.rawValue].bufferIndex = bufferIndex.rawValue
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        return vertexDescriptor
    }
}

// MARK: Buffer

// All this stuff is single-threaded right now because I dunno where the concurrency
// boundaries ought to be.  Probably Buffer should be ST but Buffers MT?

/// A managed vertex buffer
final class Buffer {
    /// I have no idea how big is reasonable, probably too small for real systems
    private static let BUFFER_BYTES = 8192
    /// 200 vertices per 4K page
    private static let VERTEX_PER_BUFFER = BUFFER_BYTES / MemoryLayout<Vertex>.stride

    /// Metal buffer object
    let mtlBuffer: MTLBuffer
    /// Permanent typed pointer to the start of the buffer
    private let firstVertex: UnsafeMutablePointer<Vertex>

    /// Cursor into buffer, insertion point
    private var nextVertex: UnsafeMutablePointer<Vertex>
    /// Number of vertices currently used
    private(set) var usedCount: Int
    /// Number of vertices currently free
    private var freeCount: Int {
        Buffer.VERTEX_PER_BUFFER - usedCount
    }

    enum State {
        /// Buffer is unused
        case free
        /// Buffer is allocated to a client who is filling it
        case allocated
        /// Buffer is owned by the GPU
        case pending
    }
    private(set) var state: State

    /// Fails if the GPU won't allocate a buffer
    fileprivate init?(device: MTLDevice, id: UInt64) {
        guard let mtlBuffer = device.makeBuffer(length: Buffer.BUFFER_BYTES) else {
            return nil
        }
        self.mtlBuffer = mtlBuffer
        mtlBuffer.label = "Vertex buffer \(id)"
        firstVertex = mtlBuffer.contents().bindMemory(to: Vertex.self, capacity: Buffer.VERTEX_PER_BUFFER)
        nextVertex = firstVertex
        usedCount = 0
        state = .free
    }

    /// State change, debug
    fileprivate func setAllocated() {
        assert(state == .free)
        state = .allocated
    }

    /// State change, debug
    fileprivate func setPending() {
        assert(state == .allocated)
        state = .pending
    }

    /// State change, debug and state reset for reuse
    fileprivate func setFree() {
        assert(state == .pending)
        state = .free
        nextVertex = firstVertex
        usedCount = 0
    }

    /// Client request to add vertices
    func add(newVertices: [Vertex]) -> Bool {
        guard newVertices.count < freeCount else {
            return false
        }
        // Swift's job to turn this into memcpy()...
        newVertices.withUnsafeBufferPointer {
            nextVertex.assign(from: $0.baseAddress!, count: $0.count)
        }
        nextVertex += newVertices.count
        usedCount += newVertices.count
        return true
    }

    /// Client request to add one vertex
    func add(newVertex: Vertex) -> Bool {
        guard freeCount > 0 else {
            return false
        }
        nextVertex[0] = newVertex
        nextVertex += 1
        usedCount += 1
        return true
    }
}

extension Buffer: Hashable, CustomStringConvertible {
    static func == (lhs: Buffer, rhs: Buffer) -> Bool {
        lhs.mtlBuffer.label == rhs.mtlBuffer.label
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(mtlBuffer.label)
    }

    var description: String {
        "\(mtlBuffer.label!) [\(state) used=\(usedCount)/\(Buffer.VERTEX_PER_BUFFER)]"
    }
}

// MARK: Buffer Manager

/// Buffer manager
final class Buffers {
    private let device: MTLDevice

    /// Buffer IDs are unique per ``Buffers``
    private var nextBufferID = UInt64(2000)
    /// All buffers that exist, for debug
    private var all: [Buffer] = []
    /// Free pool, most recently used at the end
    private var free: [Buffer] = []
    /// During a frame, buffers allocated to clients being written into
    private var allocated: Set<Buffer> = []
    /// During a frame, buffers that clients have put into draw commands
    private var framePending: [Buffer] = []
    /// Buffers waiting for GPU to be done with a frame's draw commands
    private var allPending: [UInt64 : [Buffer]] = [:]

    /// Should be number of clients?  In general want to keep small and rely on dynamic allocating
    /// in the early frames?  Or have clients declare during some initial pass?
    private static let INITIAL_BUFFERS = 4
    /// This is the Apple triple-buffer thing, deal with GPU pipelining
    private static let BUFFER_CONCURRENCY = 3

    /// Startup time -- allocate initial buffer needs
    init(device: MTLDevice) {
        self.device = device
        for _ in 0..<Buffers.INITIAL_BUFFERS * Buffers.BUFFER_CONCURRENCY {
            free.append(create()!)
        }
    }

    /// Helper to create a ``Buffer``
    private func create() -> Buffer? {
        guard let buffer = Buffer(device: device, id: nextBufferID) else {
            return nil
        }
        nextBufferID += 1
        all.append(buffer)
        return buffer
    }

    /// Renderer call.  Debug only right now.
    func startFrame() {
        assert(framePending.isEmpty)
        assert(allocated.isEmpty)
    }

    /// Client buffer allocation, during frame, fastpath
    func allocate() -> Buffer {
        precondition(!free.isEmpty, "Out of buffers: \(self)") // for now, spot leaks...
        let buffer = free.removeLast()
        allocated.insert(buffer)
        buffer.setAllocated()
        return buffer
    }

    /// Client buffer done, during frame, fastpath
    func pend(buffer: Buffer) {
        if allocated.remove(buffer) == nil {
            preconditionFailure("Buffer not allocated: \(buffer)")
        }
        buffer.setPending()
        framePending.append(buffer)
    }

    /// Renderer call, this frame's buffer set is completej
    func endFrame(frameID: Renderer.FrameID) {
        assert(allocated.isEmpty, "Buffers still allocated at end-frame")
        allPending[frameID] = framePending
        framePending = []
    }

    /// Renderer call from CommandBuffer-Complete time -- buffers now ready for reuse
    func completeFrame(frameID: Renderer.FrameID) {
        allPending.removeValue(forKey: frameID)?.forEach {
            $0.setFree()
            free.append($0)
        }
    }
}

extension Buffers: CustomStringConvertible {
    var allPendingDescription: String {
        allPending.map { kv in
            "(\(kv.key): \(kv.value.count) buf)"
        }.joined(separator: ", ")
    }

    var allPendingCount: Int {
        allPending.reduce(0) { r, kv in r + kv.value.count }
    }

    var description: String {
        "Buffers: \(all.count) total, \(free.count) free, \(allocated.count) allocated, \(framePending.count) framePending, \(allPendingCount) allPending\n" +
          "  AllPending: [\(allPendingDescription)]\n" +
        all.map { "  \($0.description)" }.joined(separator: "\n")
    }
}
