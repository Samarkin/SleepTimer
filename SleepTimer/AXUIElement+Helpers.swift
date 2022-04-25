import ApplicationServices

extension AXUIElement {
    var children: [AXUIElement]? { getAttribute(withName: kAXChildrenAttribute) }

    var text: String? { getAttribute(withName: kAXTextAttribute) }

    var title: String? { getAttribute(withName: kAXTitleAttribute) }

    var menuBar: AXUIElement? { getAttribute(withName: kAXMenuBarAttribute) }

    var windows: [AXUIElement]? { getAttribute(withName: kAXWindowsAttribute) }

    func press() { performAction(withName: kAXPressAction) }

    private func performAction(withName name: String) {
        let result = AXUIElementPerformAction(self, name as CFString)
        guard result == .success else {
            print("Error performing action \(name): \(result)")
            exit(EXIT_FAILURE)
        }
    }

    private func getAttribute<T>(withName name: String) -> T? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(self, name as CFString, &valueRef)
        guard result == .success else {
            if result == .noValue || result.rawValue == -25205 {
                return nil
            }
            print("Error reading attribute \(name): \(result)")
            exit(EXIT_FAILURE)
        }
        return valueRef as? T
    }

    private func getAttributeNames() -> [String] {
        var attributeNames: CFArray?
        AXUIElementCopyAttributeNames(self, &attributeNames)
        return attributeNames as? [String] ?? []
    }

    private func getActionNames() -> [String] {
        var actionNames: CFArray?
        AXUIElementCopyActionNames(self, &actionNames)
        return actionNames as? [String] ?? []
    }
}

extension AXUIElement: CustomStringConvertible {
    public var description: String {
        return "<AXUIElement \(getAttributeNames())/\(getActionNames())>"
    }
}
