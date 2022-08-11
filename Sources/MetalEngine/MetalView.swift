//
//  MetalView.swift
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

import SwiftUI
import MetalKit

public struct MetalView: NSViewRepresentable {
    let setup: EngineCall
    let frame: EngineCall

    public init(setup: @escaping (any Engine) -> Void,
                frame: @escaping (any Engine) -> Void) {
        self.setup = setup
        self.frame = frame
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator {
        let parent: MetalView
        var renderer: Renderer?

        init(_ parent: MetalView) {
            self.parent = parent
        }
    }

    public func makeNSView(context: NSViewRepresentableContext<MetalView>) -> MTKView {
        let mtkView = MTKView()
        context.coordinator.renderer = Renderer(view: mtkView,
                                                setup: setup,
                                                frame: frame)
        return mtkView
    }

    public func updateNSView(_ nsView: MTKView, context: NSViewRepresentableContext<MetalView>) {
    }
}
