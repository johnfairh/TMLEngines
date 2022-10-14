//
//  MetalView.swift
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

import SwiftUI
import MetalKit

/// A SwiftUI view wrapping a Metal implementation of the ``Engine`` protocol.
public struct MetalEngineView: NSViewRepresentable {
    let preferredFPS: Int
    let setup: Engine2DCall
    let frame: Engine2DCall

    /// Create a Metal view whose content is determined by the client callbacks.
    ///
    /// - parameter setup: Called once before any frame callbacks to create textures, fonts etc.
    /// - parameter frame: Called once per frame to render the view
    public init(preferredFPS: Int = 60,
                setup: @escaping (any Engine2D) -> Void,
                frame: @escaping (any Engine2D) -> Void) {
        self.preferredFPS = preferredFPS
        self.setup = setup
        self.frame = frame
    }

    /// :nodoc: SwiftUI implementation
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// :nodoc: SwiftUI implementation
    public class Coordinator {
        let parent: MetalEngineView
        var renderer: Renderer?

        init(_ parent: MetalEngineView) {
            self.parent = parent
        }
    }

    /// :nodoc: SwiftUI implementation
    public func makeNSView(context: NSViewRepresentableContext<MetalEngineView>) -> MTKView {
        let mtkView = MTKView()
        mtkView.preferredFramesPerSecond = preferredFPS
        context.coordinator.renderer = Renderer(view: mtkView, setup: setup, frame: frame)
        return mtkView
    }

    /// :nodoc: SwiftUI implementation
    public func updateNSView(_ nsView: MTKView, context: NSViewRepresentableContext<MetalEngineView>) {
        // still not sure what this is for
    }
}
