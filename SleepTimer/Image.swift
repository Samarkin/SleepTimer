import Cocoa

fileprivate func load_template_image(named: String) -> NSImage? {
    guard let image = NSImage(named: named) else {
        print("Failed to load image \"\(named)\"")
        exit(EXIT_FAILURE)
    }
    image.isTemplate = true
    return image
}

class Image {
    private init() {
    }
    static let menubar_icon = load_template_image(named: "sleep_button")
    static let menubar_icon_active = load_template_image(named: "sleep_button_active")
}
