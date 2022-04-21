import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, SleepTimerDelegate {
    private var statusItem: NSStatusItem!

    private var appStatusMenuItem: NSMenuItem!
    private var enableTimerMenuItem: NSMenuItem!
    private var disableTimerMenuItem: NSMenuItem!

    private var sleepTimer: SleepTimer?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setUpMenu()
    }

    func setUpMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let menu = NSMenu(title: "blah!")

        appStatusMenuItem = NSMenuItem()
        appStatusMenuItem.title = "opa"
        appStatusMenuItem.isEnabled = false
        menu.addItem(appStatusMenuItem)

        enableTimerMenuItem = menu.addItem(withTitle: "Enable sleep timer", action: nil, keyEquivalent: "e")
        let enableSubmenu = NSMenu()
#if DEBUG
        enableSubmenu.addItem(withTitle: "5 seconds", action: #selector(setTimer5Seconds), keyEquivalent: "0")
#endif
        enableSubmenu.addItem(withTitle: "5 minutes", action: #selector(setTimer5Minutes), keyEquivalent: "1")
        enableSubmenu.addItem(withTitle: "30 minutes", action: #selector(setTimer30Minutes), keyEquivalent: "2")
        enableSubmenu.addItem(withTitle: "1 hour", action: #selector(setTimer1Hour), keyEquivalent: "3")
        enableSubmenu.addItem(withTitle: "90 minutes", action: #selector(setTimer90Minutes), keyEquivalent: "4")
        enableSubmenu.addItem(withTitle: "2 hours", action: #selector(setTimer2Hours), keyEquivalent: "5")
        enableTimerMenuItem.submenu = enableSubmenu

        disableTimerMenuItem = menu.addItem(withTitle: "Disable sleep timer", action: #selector(disableTimer), keyEquivalent: "d")

        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = menu

        refreshMenuState()
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

    private func setTimer(timeout: TimeInterval) {
        let sleepTimer = SleepTimer(timeout: timeout)
        sleepTimer.delegate = self
        sleepTimer.start()
        self.sleepTimer = sleepTimer

        refreshMenuState()
    }

#if DEBUG
    @objc func setTimer5Seconds() {
        setTimer(timeout: 5.seconds)
    }
#endif

    @objc func setTimer5Minutes() {
        setTimer(timeout: 5.minutes)
    }

    @objc func setTimer30Minutes() {
        setTimer(timeout: 30.minutes)
    }

    @objc func setTimer1Hour() {
        setTimer(timeout: 60.minutes)
    }

    @objc func setTimer90Minutes() {
        setTimer(timeout: 90.minutes)
    }

    @objc func setTimer2Hours() {
        setTimer(timeout: 120.minutes)
    }

    @objc func disableTimer() {
        self.sleepTimer = nil
        refreshMenuState()
    }

    func timerTick(timer: SleepTimer) {
        let timeLeft = Int(timer.timeLeft)
        appStatusMenuItem.title = timeLeft > Int(2.minutes)
            ? "\(timeLeft / 60) minutes left"
            : "\(timeLeft) seconds left"
    }

    func timerExpiration(timer: SleepTimer) {
        self.sleepTimer = nil
        refreshMenuState()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

