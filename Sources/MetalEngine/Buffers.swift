//
//  Buffers.swift
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

import MetalKit
import CMetalEngine

// MARK: Buffer

/// ``Buffers`` is MT-safe, ``Buffer`` is not, client to manage.

/// A managed vertex buffer, not thread-safe
final class Buffer {
    /// I have no idea how big is reasonable, probably too small for real systems
    fileprivate static let BUFFER_BYTES = 8192

    /// Metal buffer object
    let mtlBuffer: MTLBuffer

    /// Lifetime state of buffer
    enum State {
        /// Buffer is unused
        case free
        /// Buffer is allocated to a client who is filling it
        case allocated
        /// Buffer is owned by the GPU
        case flushing
    }
    private(set) var state: State

    /// Fails if the GPU won't allocate a buffer
    fileprivate init?(device: MTLDevice, id: UInt64) {
        guard let mtlBuffer = device.makeBuffer(length: Buffer.BUFFER_BYTES) else {
            return nil
        }
        self.mtlBuffer = mtlBuffer
        mtlBuffer.label = "Vertex buffer \(id)"
        state = .free
    }

    /// State change, debug
    fileprivate func setAllocated() {
        assert(state == .free)
        state = .allocated
    }

    /// State change, debug
    fileprivate func setFlushing() {
        assert(state == .allocated)
        state = .flushing
    }

    /// State change, debug and state reset for reuse
    fileprivate func setFree() {
        assert(state == .flushing)
        state = .free
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
        "\(mtlBuffer.label!) [\(state)]"
    }
}

// MARK: Buffer Manager

/// Buffer manager, threadsafe
final class Buffers {
    private let device: MTLDevice

    /// Protects everything here
    private let lock = Lock()
    /// Buffer IDs are unique per ``Buffers``
    private var nextBufferID = UInt64(2000)
    /// All buffers that exist, for debug
    private var all: [Buffer] = []
    /// Free pool, most recently used at the end
    private var free: [Buffer] = []
    /// During a frame, buffers allocated to clients being written into
    private var allocated: Set<Buffer> = []
    /// During a frame, buffers that clients have put into draw commands
    private var frameFlushing: [Buffer] = []
    /// Buffers waiting for GPU to be done with a frame's draw commands
    private var allFlushing: [UInt64 : [Buffer]] = [:]

    /// Should be number of clients?  In general want to keep small and rely on dynamic allocating
    /// in the early frames?  Or have clients declare during some initial pass?
    private static let INITIAL_BUFFERS = 4
    /// This is the Apple triple-buffer thing, deal with GPU pipelining
    private static let BUFFER_CONCURRENCY = 3

    /// Startup time -- allocate initial buffer needs
    init(device: MTLDevice) {
        self.device = device
        create(n: Buffers.INITIAL_BUFFERS)
    }

    /// Helper to create some buffers, deal with concurrency inflation here
    private func create(n: Int) {
        for _ in 0..<n * Buffers.BUFFER_CONCURRENCY {
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
    func startFrame() -> Bool {
        lock.locked {
            assert(frameFlushing.isEmpty)
            assert(allocated.isEmpty)
            /// We shouldn't have more than three frames in flight (likely to run out of buffers) because
            /// the higher-level RPD/drawable should have been unavailable and the frame abandoned...
            ///
            /// ...this seems not to be true when the system grinds, particularly when stopping in the debugger
            /// or whizzing windows around.
            return (allFlushing.count < 3)
        }
    }

    /// Client buffer allocation, during frame, fastpath
    func allocate() -> Buffer {
        lock.locked {
            if free.isEmpty {
                create(n: 1)
            }
            let buffer = free.removeLast()
            allocated.insert(buffer)
            buffer.setAllocated()
            return buffer
        }
    }

    /// Client buffer done, during frame, fastpath
    func flush(buffer: Buffer) {
        lock.locked {
            if allocated.remove(buffer) == nil {
                preconditionFailure("Buffer not allocated: \(buffer)")
            }
            buffer.setFlushing()
            frameFlushing.append(buffer)
        }
    }

    /// Renderer call, this frame's buffer set is completej
    func endFrame(frameID: Renderer.FrameID) {
        lock.locked {
            assert(allocated.isEmpty, "Buffers still allocated at end-frame")
            allFlushing[frameID] = frameFlushing
            frameFlushing = []
        }
    }

    /// Renderer call from CommandBuffer-Complete time -- buffers now ready for reuse
    func completeFrame(frameID: Renderer.FrameID) {
        lock.locked {
            allFlushing.removeValue(forKey: frameID)?.forEach {
                $0.setFree()
                free.append($0)
            }
        }
    }
}

extension Buffers: CustomStringConvertible {
    private var allFlushingDescription: String {
        allFlushing.map { kv in
            "(\(kv.key): \(kv.value.count) buf)"
        }.joined(separator: ", ")
    }

    private var allFlushingCount: Int {
        allFlushing.reduce(0) { r, kv in r + kv.value.count }
    }

    var description: String {
        lock.locked {
            "Buffers: \(all.count) total, \(free.count) free, \(allocated.count) allocated, \(frameFlushing.count) frameFlushing, \(allFlushingCount) allFlushing\n" +
            "  AllFlushing: [\(allFlushingDescription)]\n" +
            all.map { "  \($0.description)" }.joined(separator: "\n")
        }
    }
}

// MARK: BufferWriter

/// Client component to manage putting some kind of vertex data into a succession of
/// buffers and sending them to the device when full.  Not threadsafe.
struct BufferWriter<VertexType> {
    /// Buffer manager
    private let buffers: Buffers
    /// The currently open buffer, or `nil` if none
    private(set) var buffer: Buffer?

    /// Cursor pointer, next place to write
    private var nextVertex: UnsafeMutablePointer<VertexType>!
    /// Max capacity of buffer given ``VertexType``
    let totalCount: Int
    /// Currently used count, <= ``totalCount``
    private(set) var usedCount: Int

    /// Create at startup for a particular type
    init(buffers: Buffers, vertexType: VertexType.Type) {
        self.buffers = buffers
        self.buffer = nil
        self.nextVertex = nil
        self.totalCount = Buffer.BUFFER_BYTES / MemoryLayout<VertexType>.stride
        self.usedCount = 0
    }

    /// Update the buffer, called inside ``add(vertices:)``
    private mutating func setBuffer(_ buffer: Buffer) {
        self.buffer = buffer
        self.nextVertex = buffer.mtlBuffer.contents().bindMemory(to: VertexType.self, capacity: totalCount)
        self.usedCount = 0
    }

    /// Callback if there is a buffer to finish, flush it throught ``Buffers`` and forget it
    mutating func flush(with: (Buffer, Int) -> Void) {
        if let buffer {
            with(buffer, usedCount)
            buffers.flush(buffer: buffer)
            self.buffer = nil
        }
    }

    /// Add vertices (or whatever) to the buffer
    mutating func add(vertices: [VertexType]) -> Bool {
        if buffer == nil {
            setBuffer(buffers.allocate())
        }
        guard usedCount + vertices.count <= totalCount else {
            return false
        }
        // Swift's job to turn this into memcpy()...
        vertices.withUnsafeBufferPointer {
            nextVertex.update(from: $0.baseAddress!, count: $0.count)
        }
        nextVertex += vertices.count
        usedCount += vertices.count
        return true
    }
}

extension BufferWriter: CustomStringConvertible {
    var description: String {
        guard let buffer else {
            return "(no buffer))"
        }
        return "\(buffer) used \(usedCount)/\(totalCount)"
    }
}
