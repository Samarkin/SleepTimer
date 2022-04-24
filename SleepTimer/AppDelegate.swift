import Cocoa
import UserNotifications

typealias TimerOption = (timeout: TimeInterval, title: String, keyEquivalent: String)

#if DEBUG
private let _debugTimerOptions: [TimerOption] = [
    (timeout: 5.seconds, title: "5 seconds", keyEquivalent: "0"),
]
#else
private let _debugTimerOptions = []
#endif

private let timerOptions: [TimerOption] = _debugTimerOptions + [
    (timeout: 5.minutes, title: "5 minutes", keyEquivalent: "1"),
    (timeout: 30.minutes, title: "30 minutes", keyEquivalent: "2"),
    (timeout: 60.minutes, title: "1 hour", keyEquivalent: "3"),
    (timeout: 90.minutes, title: "90 minutes", keyEquivalent: "4"),
    (timeout: 120.minutes, title: "2 hours", keyEquivalent: "5"),
]

class AppDelegate: NSObject, NSApplicationDelegate, SleepTimerDelegate {
    private var statusItem: NSStatusItem!
    private var globalHotkeyMonitor: Any!

    private var appStatusMenuItem: NSMenuItem!
    private var enableTimerMenuItem: NSMenuItem!
    private var disableTimerMenuItem: NSMenuItem!

    private var sleepTimer: SleepTimer?
    private var sendNotifications = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setUpMenu()
        setUpHotkey()
        setUpNotifications()
    }

    func setUpMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let menu = NSMenu()

        appStatusMenuItem = NSMenuItem()
        appStatusMenuItem.isEnabled = false
        menu.addItem(appStatusMenuItem)

        enableTimerMenuItem = menu.addItem(withTitle: "Enable sleep timer", action: nil, keyEquivalent: "e")
        let enableSubmenu = NSMenu()

        for timerOption in timerOptions {
            let item = enableSubmenu.addItem(
                withTitle: timerOption.title,
                action: #selector(setTimerMenuItem(_:)),
                keyEquivalent: timerOption.keyEquivalent)
            item.tag = Int(timerOption.timeout)
        }
        enableTimerMenuItem.submenu = enableSubmenu

        disableTimerMenuItem = menu.addItem(withTitle: "Disable sleep timer", action: #selector(disableTimer), keyEquivalent: "d")

        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = menu

        refreshMenuState()
    }

    private func setUpHotkey() {
        guard AXIsProcessTrusted() else {
            let alert = NSAlert()
            alert.messageText = "Turn on accessibility"
            alert.informativeText = "SleepTimer needs special permisions to control your computer"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Go to Settings")
            alert.addButton(withTitle: "Close application")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                let prefPage = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(prefPage)
            }
            NSApplication.shared.terminate(self)
            return
        }
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] in
            // Ctrl + Shift + Option + Fn + T
            guard $0.modifierFlags.contains([.control, .shift, .option, .command, .function]) && $0.keyCode == 17 else {
                return
            }
            self?.globalHotkey()
        }
    }

    private func globalHotkey() {
        var nextTimerOption: TimerOption? = nil
        if let sleepTimer = sleepTimer {
            for timerOption in timerOptions {
                let timeThreshold = min(timerOption.timeout * 0.66, timerOption.timeout - 3.seconds)
                if sleepTimer.timeLeft < timeThreshold {
                    nextTimerOption = timerOption
                    break
                }
            }
        } else {
            nextTimerOption = timerOptions[0]
        }
        if let option = nextTimerOption {
            setTimer(timeout: option.timeout, title: option.title)
        } else {
            disableTimer()
        }
    }

    private func setUpNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: .alert) { [weak self] in
            guard $0 else {
                print("Notifications disabled: \($1?.localizedDescription ?? "No error")")
                return
            }
            self?.sendNotifications = true
        }
    }

    private func sendNotification(body: String) {
        guard sendNotifications else {
            return
        }
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        let content = UNMutableNotificationContent()
        content.title = "SleepTimer"
        content.body = body
        let notificationIdentifier = UUID().uuidString
        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: nil)
        center.add(request)
    }


    private func refreshMenuState() {
        let timerRunning = self.sleepTimer != nil
        if !timerRunning {
            appStatusMenuItem.title = "Timer is not running"
        }

        enableTimerMenuItem.isHidden = timerRunning
        disableTimerMenuItem.isHidden = !timerRunning

        guard let button = statusItem.button else {
            print("Failed to access status item button")
            exit(EXIT_FAILURE)
        }
        button.image = timerRunning ? Image.menubar_icon_active : Image.menubar_icon
    }

    private func setTimer(timeout: TimeInterval, title: String) {
        let sleepTimer = SleepTimer(timeout: timeout)
        sleepTimer.delegate = self
        sleepTimer.start()
        self.sleepTimer = sleepTimer

        refreshMenuState()
        sendNotification(body: "Timer set for \(title)")
    }

    @objc func setTimerMenuItem(_ sender: Any) {
        guard let menuItem = sender as? NSMenuItem else {
            print("ERROR: Invalid sender for setTimer")
            return
        }
        setTimer(timeout: TimeInterval(menuItem.tag), title: menuItem.title)
    }

    @objc func disableTimer() {
        self.sleepTimer = nil
        refreshMenuState()
        sendNotification(body: "Timer disabled")
    }

    func timerTick(timer: SleepTimer) {
        let timeLeft = Int(timer.timeLeft)
        appStatusMenuItem.title = timeLeft > Int(2.minutes)
            ? "\((timeLeft + 30) / 60) minutes left"
            : "\(timeLeft) seconds left"
    }

    func timerExpiration(timer: SleepTimer) {
        self.sleepTimer = nil
        refreshMenuState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let globalHotkeyMonitor = globalHotkeyMonitor {
            NSEvent.removeMonitor(globalHotkeyMonitor)
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

