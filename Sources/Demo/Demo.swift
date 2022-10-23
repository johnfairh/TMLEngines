//
//  Demo.swift
//  Demo
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

import SwiftUI
import MetalEngine

@main
struct Demo: App {
    var body: some Scene {
        WindowGroup {
            MetalEngineView(preferredFPS: 100,
                            setup: { GameClient.instance = .init(engine: $0) },
                            frame: { GameClient.instance?.frame(engine: $0) })
//                .frame(minWidth: 1024, minHeight: 768)
        .frame(minWidth: 1024, maxWidth: 1024, minHeight: 768, maxHeight: 768)

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

class GameClient {
    static var instance: GameClient?

    let starField: StarField
    var mainMenu: MainMenu!

    let monoFont: Font2D
    let propFont: Font2D
    let texture1: Texture2D
    let texture2: Texture2D

    var showingMenu: Bool = false

    init(engine: Engine2D) {
        engine.setBackgroundColor(.rgb(0, 0, 0))

        monoFont = engine.createFont(style: .monospaced, weight: .bold, height: 10)
        propFont = engine.createFont(style: .proportional, weight: .medium, height: 30)

        texture1 = engine.loadTexture(name: "avatar_bgra", format: .bgra)
        texture2 = engine.loadTexture(name: "avatar_rgba", format: .rgba)

        starField = StarField(engine: engine)
        mainMenu = MainMenu(engine: engine) { mi in
            true
        } onSelection: { [weak self] cmd in
            self?.showingMenu = false
            if cmd == .gameExiting {
                GameClient.instance = nil
                DispatchQueue.main.async {
                    NSApp.terminate(self)
                }
            }
        }
        mainMenu.heading = "Menu"
    }

    func frame(engine: Engine2D) {

        starField.render()

        if showingMenu {
            mainMenu.runFrame()
            return
        }

        if engine.isKeyDown(.printable("M")) {
            showingMenu = true
            return
        }

        let screen = engine.viewportSize

        engine.drawLine(x0: 0, y0: 0, color0: .rgb(0.1, 0, 0),
                        x1: screen.x - 1, y1: screen.y - 1, color1: .rgb(0.9, 0, 0))

        engine.drawTriangle(x0: screen.x / 2, y0: screen.y / 4, color0: .rgba(1, 0, 0, 0.8),
                            x1: screen.x * (3/4), y1: screen.y * (3/4), color1: .rgba(0, 1, 0, 0.8),
                            x2: screen.x / 4, y2: screen.y * (3/4), color2: .rgba(0, 0, 1, 0.8))

        engine.drawTexturedRect(x0: screen.x / 8, y0: screen.y / 8,
                                x1: screen.x / 8 + screen.x / 4, y1: screen.y / 8 + screen.y / 4,
                                texture: texture1)

        if engine.isKeyDown(.escape) {
            engine.drawTexturedRect(x0: screen.x / 4, y0: screen.y / 4,
                                    x1: screen.x / 4 + screen.x / 4, y1: screen.y / 4 + screen.y / 4,
                                    texture: texture2)
        }

        engine.drawQuad(x0: screen.x - screen.x / 8, y0: 0,
                        x1: screen.x, y1: screen.y / 8,
                        x2: screen.x - screen.x / 8, y2: screen.y / 4,
                        x3: screen.x - screen.x / 4, y3: screen.y / 8,
                        color: .rgba(0.6, 0.55, 0, 0.4))

        engine.drawText("Hello World" + (engine.getFirstKeyDown()?.character ?? ""),
                        font: monoFont,
                        color: .rgb(0, 1, 0),
                        x: screen.x / 4,
                        y: screen.y / 8,
                        width: screen.x / 2,
                        height: screen.y / 8,
                        align: .center,
                        valign: .center)

        engine.drawText("Slime molds taste like gelatine and bananas",
                        font: propFont,
                        color: .rgb(0, 1, 0),
                        x: 0,
                        y: Float((engine.frameTimestamp/50) % UInt(screen.y)),
                        width: screen.x / 2,
                        height: 20,
                        align: .left,
                        valign: .center)
    }
}

final class StarField {
    private static let STAR_COUNT = 600

    private struct Vertex {
        let x, y: Float
        let color: Color2D

        init(x: Float, y: Float, gray: Float) {
            self.x = x
            self.y = y
            self.color = .rgb(gray, gray, gray)
        }
    }

    private let engine: Engine2D
    private var size: SIMD2<Float> = .zero
    private var stars: [Vertex] = []
    private var scrollCount = 0

    init(engine: Engine2D) {
        self.engine = engine
    }

    /// Generate star positions for the current size
    private func reset() {
        size = engine.viewportSize
        stars = []
        stars.reserveCapacity(Self.STAR_COUNT)
        scrollCount = 0
        for _ in 0..<Self.STAR_COUNT {
            stars.append(Vertex(x: Float.random(in: 0..<size.x),
                                y: Float.random(in: 0..<size.y),
                                gray: Float.random(in: 0.2..<1.0))) // visible shade of gray
        }
    }

    /// Render the star field
    func render() {
        if engine.viewportSize != size {
            reset()
        }

        scrollCount += 1

        stars.forEach { star in
            let scoot = Float(scrollCount) * star.color.r / 4.0 // brighter->faster, max .25/frame
            let newy = star.y - scoot // go up
            engine.drawPoint(x: star.x, y: newy < 0 ? newy + size.y : newy, color: star.color)
        }
        engine.flushPoints() // make them behind everything else
    }
}

extension Engine2D {
    func loadTexture(name: String, format: Texture2D.Format) -> Texture2D {
#if SWIFT_PACKAGE
        let bundle = Bundle.module
#else
        let bundle = Bundle.main
#endif
        guard let url = bundle.url(forResource: "Resources/\(name)", withExtension: nil) else {
            preconditionFailure("Bundle load fail")
        }
        return try! Data(contentsOf: url).withUnsafeBytes { ubp in
            createTexture(bytes: ubp.baseAddress!, width: 64, height: 64, format: format)
        }
    }
}

enum Menu {
    static var font: Font2D!

    static let FONT_HEIGHT = Float(24)
    static let ITEM_PADDING = Float(12)

    static var lastReturnKeyTick: Engine2D.TickCount = 0
    static var lastKeyDownTick: Engine2D.TickCount = 0
    static var lastKeyUpTick: Engine2D.TickCount = 0
}

public class BaseMenu<ItemData: Equatable> {
    private let engine: Engine2D
    private let onSelection: (ItemData) -> Void

    private var items: [(String, ItemData)]
    private var selectedItem: Int
    private var pushedSelection: ItemData?
    var heading: String

    init(engine: Engine2D, onSelection: @escaping (ItemData) -> Void) {
        self.engine = engine
        self.onSelection = onSelection

        items = []
        selectedItem = 0
        pushedSelection = nil

        heading = ""

        if Menu.font == nil {
            Menu.font = engine.createFont(style: .proportional, weight: .bold, height: Menu.FONT_HEIGHT)
        }
    }

    // Clear all menu entries
    func clearMenuItems() {
        items = []
        selectedItem = 0
    }

    // Add a menu item to the menu
    func addItem(_ data: ItemData, title: String) {
        items.append((title, data))
    }

    // Save any current selection 'by value', prep for menu rebuild
    func pushSelectedItem() {
        if selectedItem < items.count {
            pushedSelection = items[selectedItem].1
        }
    }

    // Restore a previously 'pushed' selection, after menu rebuild
    func popSelectedItem() {
        guard let pushedSelection else {
            return
        }

        self.pushedSelection = nil

        if let index = items.firstIndex(where: {$0.1 == pushedSelection}) {
            selectedItem = index
        }
    }

    // Run a frame + render
    func runFrame() {
        // Note: The below code uses globals that are shared across all menus to avoid double
        // key press registration, this is so that when you do something like hit return in the pause
        // menu to "go back to main menu" you don't end up immediately registering a return in the
        // main menu afterwards.

        let currentTickCount = engine.frameTimestamp

        // check if the enter key is down, if it is take action
        if engine.isKeyDown(.enter) /* ||
                                         m_pGameEngine->BIsControllerActionActive( eControllerDigitalAction_MenuSelect ) */ {
            if currentTickCount - 220 > Menu.lastReturnKeyTick {
                Menu.lastReturnKeyTick = currentTickCount
                if selectedItem < items.count {
                    onSelection(items[selectedItem].1)
                }
            }
            // Check if we need to change the selected menu item
        } else if engine.isKeyDown(.down) /* ||
                                               m_pGameEngine->BIsControllerActionActive( eControllerDigitalAction_MenuDown ) */ {

            if currentTickCount - 140 > Menu.lastKeyDownTick {
                Menu.lastKeyDownTick = currentTickCount
                selectedItem += 1
                if selectedItem == items.count {
                    selectedItem = 0
                }
            }
        } else if engine.isKeyDown(.up) /* ||
                                             m_pGameEngine->BIsControllerActionActive( eControllerDigitalAction_MenuUp ) */ {

            if currentTickCount - 140 > Menu.lastKeyUpTick {
                Menu.lastKeyUpTick = currentTickCount
                selectedItem -= 1
                if selectedItem < 0 {
                    selectedItem = items.count - 1
                }
            }
        }

        render()
    }

    private func render() {
        if !heading.isEmpty {
            engine.drawText(heading, font: Menu.font, color: .rgb(1, 0.5, 0.5),
                            x: 0, y: 10, width: engine.viewportSize.x, height: Menu.FONT_HEIGHT + Menu.ITEM_PADDING * 2,
                            align: .center, valign: .center)
        }

        let maxMenuItems = 14

        let numItems = items.count

        let startItem: Int
        let endItem: Int
        if numItems > maxMenuItems {
            startItem = max(selectedItem - maxMenuItems / 2, 0)
            endItem = min(startItem + maxMenuItems, numItems)
        } else {
            startItem = 0
            endItem = numItems
        }

        let boxHeight = min(numItems, maxMenuItems) * Int(Menu.FONT_HEIGHT + Menu.ITEM_PADDING)

        var yPos = engine.viewportSize.y / 2.0 - Float(boxHeight / 2)

        func drawText(_ text: String, color: Color2D) {
            engine.drawText(text, font: Menu.font, color: color,
                            x: 0, y: yPos, width: engine.viewportSize.x, height: Menu.FONT_HEIGHT + Menu.ITEM_PADDING,
                            align: .center, valign: .center)
            yPos += Menu.FONT_HEIGHT + Menu.ITEM_PADDING
        }

        if startItem > 0 {
            drawText("... Scroll Up ...", color: .rgb(1, 1, 1))
        }

        for i in startItem..<endItem {
            let item = items[i]
            // Empty strings can be used to space menus, they don't get drawn or selected
            if !item.0.isEmpty {
                if i == selectedItem {
                    drawText("{ \(item.0) }", color: .rgb_i(25, 200, 25))
                } else {
                    drawText(item.0, color: .rgb(1, 1, 1))
                }
            } else {
                yPos += Menu.FONT_HEIGHT + Menu.ITEM_PADDING
            }
        }

        if numItems > endItem {
            drawText("... Scroll Down ...", color: .rgb(1, 1, 1))
        }
    }
}

/// Specialized for common case with String enum permanently holding all the choices
final class StaticMenu<MenuItemEnum> : BaseMenu<MenuItemEnum> where MenuItemEnum: Equatable & CaseIterable & CustomStringConvertible {//& RawRepresentable, MenuItemEnum.RawValue == String {
    private let filter: (MenuItemEnum) -> Bool

    func populate() {
        MenuItemEnum.allCases.forEach {
            if filter($0) {
                addItem($0, title: $0.description)
            }
        }
    }

    init(engine: Engine2D, filter: @escaping (MenuItemEnum) -> Bool = { _ in true }, onSelection: @escaping (MenuItemEnum) -> Void) {
        self.filter = filter
        super.init(engine: engine, onSelection: onSelection)
        populate()
    }
}

enum MainMenuItem: String, CaseIterable, CustomStringConvertible {
    case gameStartServer = "Start New Server"
    case findLANServers = "Find LAN Servers"
    case findInternetServers = "Find Internet Servers"
    case createLobby = "Create Lobby"
    case findLobby = "Find Lobby"
    case gameInstructions = "Instructions"
    case statsAchievements = "Stats and Achievements"
    case leaderboards = "Leaderboards"
    case friendsList = "Friends List"
    case clanChatRoom = "Group Chat Room"
    case remotePlay = "Remote Play"
    case remoteStorage = "Remote Storage"
    case minidump = "Write Minidump"
    case webcallback = "Web Callback"
    case music = "Music Player"
    case workshop = "Workshop Items"
    case htmlSurface = "HTML Page"
    case inGameStore = "In-game Store"
    case overlayAPI = "OverlayAPI"
    case gameExiting = "Exit Game"

    var description: String {
        rawValue
    }
}

typealias MainMenu = StaticMenu<MainMenuItem>
