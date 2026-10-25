import AppKit
import SwiftUI

/// Renders the SimplePJ window or sheets to a PNG without requiring screen access:
/// `SimplePJ --snapshot /tmp/simplepj.png [--view cards|table|welcome|about|help|shortcuts|osc|console]`
@MainActor
enum Snapshot {
    static func renderOffscreenPNG(model: AppModel, size: CGSize = CGSize(width: 1380, height: 820)) -> Data? {
        let window = NSWindow(
            contentRect: CGRect(origin: CGPoint(x: -20_000, y: -20_000), size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = Theme.background
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: ContentView(model: model))
        hosting.frame = CGRect(origin: .zero, size: size)
        window.contentView = hosting
        window.orderFrontRegardless()
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.30))
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()
        let png = renderPNG(of: hosting)
        window.orderOut(nil)
        return png
    }

    static func renderOffscreenPNG<V: View>(_ view: V, size: CGSize) -> Data? {
        let window = NSWindow(
            contentRect: CGRect(origin: CGPoint(x: -20_000, y: -20_000), size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = Theme.panel
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        hosting.frame = CGRect(origin: .zero, size: size)
        window.contentView = hosting
        window.orderFrontRegardless()
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        hosting.displayIfNeeded()
        let png = renderPNG(of: hosting)
        window.orderOut(nil)
        return png
    }

    static func renderPNG(of view: NSView) -> Data? {
        let bounds = view.bounds
        guard bounds.width > 1, bounds.height > 1,
              let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        view.cacheDisplay(in: bounds, to: rep)
        return rep.representation(using: .png, properties: [:])
    }

    static func runCLISnapshot(outputPath: String, view: String = "cards") -> Never {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let model = AppModel(startServices: false, persistEnabled: false)
        let png: Data?

        switch view {
        case "welcome":
            model.fleet.rangeInput = SyntheticFleet.range
            png = renderOffscreenPNG(model: model)
        case "table", "list":
            SyntheticFleet.load(into: model)
            model.viewMode = .table
            png = renderOffscreenPNG(model: model)
        case "console", "log":
            SyntheticFleet.load(into: model)
            model.showConsoleDrawer = true
            png = renderOffscreenPNG(model: model)
        case "about":
            SyntheticFleet.load(into: model)
            png = renderOffscreenPNG(AboutSheet(model: model, openHelp: {}, close: {}), size: CGSize(width: 650, height: 470))
        case "help":
            png = renderOffscreenPNG(HelpManualSheet(openShortcuts: {}, close: {}), size: CGSize(width: 760, height: 520))
        case "shortcuts":
            png = renderOffscreenPNG(ShortcutsSheet(close: {}), size: CGSize(width: 860, height: 420))
        case "osc":
            SyntheticFleet.load(into: model)
            png = renderOffscreenPNG(OSCGuideSheet(model: model, close: {}), size: CGSize(width: 760, height: 480))
        default:
            SyntheticFleet.load(into: model)
            model.viewMode = .cards
            png = renderOffscreenPNG(model: model)
        }

        guard let png else {
            fputs("snapshot error: failed to render PNG\n", stderr)
            exit(1)
        }
        let outURL = URL(fileURLWithPath: (outputPath as NSString).expandingTildeInPath)
        do {
            try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try png.write(to: outURL, options: .atomic)
            print("Snapshot written to \(outURL.path) (\(png.count) bytes)")
            exit(0)
        } catch {
            fputs("snapshot error: \(error)\n", stderr)
            exit(1)
        }
    }
}
