import Cocoa
import UserNotifications

typealias TimerOption = (timeout: TimeInterval, title: String)

#if DEBUG
private let debugTimerOption: TimerOption? = (timeout: 5.seconds, title: "5 seconds")
#else
private let debugTimerOption: TimerOption? = nil
#endif

private let timerOptions: [TimerOption] = [
    (timeout: 5.minutes, title: "5 minutes"),
    (timeout: 30.minutes, title: "30 minutes"),
    (timeout: 60.minutes, title: "1 hour"),
    (timeout: 90.minutes, title: "90 minutes"),
    (timeout: 120.minutes, title: "2 hours"),
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

        func addSubmenuItem(forTimerOption timerOption: TimerOption, withKeyEquivalent keyEquivalent: String) {
            let item = enableSubmenu.addItem(
                withTitle: timerOption.title,
                action: #selector(setTimerMenuItem(_:)),
                keyEquivalent: keyEquivalent)
            item.tag = Int(timerOption.timeout)
        }
        
        if let debugTimerOption = debugTimerOption {
            addSubmenuItem(forTimerOption: debugTimerOption, withKeyEquivalent: "0")
        }
        for (i,option) in timerOptions.enumerated() {
            addSubmenuItem(forTimerOption: option, withKeyEquivalent: "\(i+1)")
        }
        enableTimerMenuItem.submenu = enableSubmenu

        disableTimerMenuItem = menu.addItem(withTitle: "Disable sleep timer", action: #selector(disableTimer), keyEquivalent: "d")

        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = menu

        refreshAppState()
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
            // Ctrl + Shift + Option + Command + T
            guard $0.modifierFlags.contains([.control, .shift, .option, .command]) && $0.keyCode == 17 else {
                return
            }
            self?.globalHotkey()
        }
    }

    private func globalHotkey() {
        var nextTimerOption: TimerOption? = nil
        if let sleepTimer = sleepTimer {
            for timerOption in timerOptions {
                let timeThreshold = timerOption.timeout - 3.seconds
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
            center.removeAllDeliveredNotifications()
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


    private func refreshAppState() {
        let timerRunning = self.sleepTimer != nil
        if timerRunning {
            disableScreenSleep()
        } else {
            enableScreenSleep()
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

        refreshAppState()
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
        refreshAppState()
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
        refreshAppState()
        pauseMovist()
    }

    func pauseMovist() {
        let app = Application(bundleIdentifier: "com.movist.Movist")
        app.activate()
        app.pressMenuItem(["Playback", "Pause"])
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

