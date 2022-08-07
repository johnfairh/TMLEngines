//
//  DemoApp.swift
//  DemoApp
//
//  Created by John on 07/08/2022.
//

import SwiftUI

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    #if SWIFT_PACKAGE
    // Some nonsense to make the app work properly when built outside of Xcode
    init() {
      DispatchQueue.main.async {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
      }
    }
    #endif
}
