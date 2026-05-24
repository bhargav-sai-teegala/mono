import AppKit
import SwiftUI
import ServiceManagement

extension Notification.Name {
    static let closeMonoPanel = Notification.Name("com.mono.closePanel")
    static let monoFocusInput = Notification.Name("com.mono.focusInput")
    static let monoWillShow   = Notification.Name("com.mono.willShow")
    static let monoBeginExit  = Notification.Name("com.mono.beginExit")
}

// Borderless NSPanel doesn't become key by default — override to allow text input
private class KeyPanel: NSPanel {
    override var canBecomeKey: Bool  { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel:      KeyPanel!
    private let store = TaskStore()
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ note: Notification) {
        buildPanel()
        buildStatusItem()
        NotificationCenter.default.addObserver(
            forName: .closeMonoPanel, object: nil, queue: .main
        ) { [weak self] _ in self?.hidePanel() }
    }

    // MARK: Panel
    private func buildPanel() {
        let frame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        panel = KeyPanel(contentRect: frame,
                         styleMask: [.borderless],
                         backing: .buffered,
                         defer: false)
        panel.level              = .floating
        panel.backgroundColor    = .clear
        panel.isOpaque           = false
        panel.hasShadow          = false
        panel.isMovable          = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let host = NSHostingView(rootView: ContentView().environmentObject(store))
        host.frame = NSRect(origin: .zero, size: frame.size)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
    }

    private func showPanel() {
        if let f = NSScreen.main?.frame { panel.setFrame(f, display: false) }

        NSApp.setActivationPolicy(.regular)
        panel.alphaValue = 1
        NotificationCenter.default.post(name: .monoWillShow, object: nil)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(name: .monoFocusInput, object: nil)
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] ev in
            if ev.keyCode == 53 { self?.hidePanel(); return nil }
            return ev
        }
    }

    private func hidePanel() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }

        NotificationCenter.default.post(name: .monoBeginExit, object: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            self.panel.orderOut(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    private func togglePanel() {
        panel.isVisible ? hidePanel() : showPanel()
    }

    // MARK: Status item
    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let btn = statusItem.button else { return }
        btn.image = makeHexagonIcon()
        btn.image?.isTemplate = false
        btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        btn.action = #selector(handleClick)
        btn.target = self
    }

    @objc private func handleClick() {
        guard let ev = NSApp.currentEvent else { return }
        if ev.type == .rightMouseUp { showQuitMenu() } else { togglePanel() }
    }

    private func showQuitMenu() {
        let menu = NSMenu()

        if #available(macOS 13.0, *) {
            let enabled = SMAppService.mainApp.status == .enabled
            let title   = enabled ? "✓ Launch at Login" : "Launch at Login"
            menu.addItem(NSMenuItem(title: title,
                                    action: #selector(toggleLaunchAtLogin),
                                    keyEquivalent: ""))
            menu.addItem(.separator())
        }

        menu.addItem(NSMenuItem(title: "Quit Mono",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        DispatchQueue.main.async { self.statusItem.menu = nil }
    }

    @objc private func toggleLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            // Silently ignore — only works when running as a proper installed .app
        }
    }

    // MARK: Hex icon
    private func makeHexagonIcon() -> NSImage {
        let size: CGFloat = 18
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let cx = rect.midX, cy = rect.midY
            let r: CGFloat = size / 2 - 2.0
            let path = CGMutablePath()
            for i in 0..<6 {
                let a = CGFloat(i) * .pi / 3 - .pi / 6
                let pt = CGPoint(x: cx + r * cos(a), y: cy + r * sin(a))
                i == 0 ? path.move(to: pt) : path.addLine(to: pt)
            }
            path.closeSubpath()
            let stroke = path.copy(strokingWithWidth: 1.8, lineCap: .round, lineJoin: .round, miterLimit: 4)
            ctx.saveGState(); ctx.addPath(stroke); ctx.clip()
            let comps: [CGFloat] = [0.49,0.23,0.93,1, 0.85,0.27,0.90,1, 0.96,0.25,0.37,1, 0.98,0.57,0.24,1]
            let locs: [CGFloat]  = [0, 0.33, 0.66, 1]
            if let g = CGGradient(colorSpace: CGColorSpaceCreateDeviceRGB(),
                                   colorComponents: comps, locations: locs, count: 4) {
                ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: size, y: size), options: [])
            }
            ctx.restoreGState(); return true
        }
        img.isTemplate = false
        return img
    }
}
