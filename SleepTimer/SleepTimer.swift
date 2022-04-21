import Foundation

protocol SleepTimerDelegate: AnyObject {
    func timerTick(timer: SleepTimer)
    func timerExpiration(timer: SleepTimer)
}

class SleepTimer {
    private (set) var timeLeft: TimeInterval
    weak var delegate: SleepTimerDelegate?

    init(timeout: TimeInterval) {
        timeLeft = timeout
    }

    func start() {
        assert(timeLeft > 1 + 1e-6, "Timer started twice")
        delegate?.timerTick(timer: self)
        scheduleNextTick()
    }

    private func scheduleNextTick() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: { [weak self] in self?.timerTick() })
    }

    private func timerTick() {
        timeLeft -= 1
        delegate?.timerTick(timer: self)
        if timeLeft > 1 + 1e-6 {
            scheduleNextTick()
        } else {
            delegate?.timerExpiration(timer: self)
        }
    }
}
