import Cocoa

class Application {
    private let uiApp: AXUIElement?
    private let nsApp: NSRunningApplication?

    init(bundleIdentifier: String) {
        let nsApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        if let firstNsApp = nsApps.first {
            nsApp = firstNsApp
            uiApp = AXUIElementCreateApplication(firstNsApp.processIdentifier)
        } else {
            nsApp = nil
            uiApp = nil
        }
    }

    func pressMenuItem(_ path: [String]) {
        guard let menuBar = uiApp?.menuBar else {
            return
        }
        _pressMenuItem(menuBar, path, 0)
    }

    func activate() {
        nsApp?.activate(options: .activateIgnoringOtherApps)
    }
}

private func _pressMenuItem(_ uiElement: AXUIElement, _ path: [String], _ idx: Int) {
    guard idx < path.count else {
        return
    }
    guard let children = uiElement.children else {
        return
    }
    for menuItem in children {
        if menuItem.title == nil {
            // I'm not sure why, but some menu items don't have a title - skip them
            _pressMenuItem(menuItem, path, idx)
        } else if menuItem.title == path[idx] {
            if idx+1 < path.count {
                _pressMenuItem(menuItem, path, idx+1)
            } else {
                menuItem.press()
            }
        }
    }
}
