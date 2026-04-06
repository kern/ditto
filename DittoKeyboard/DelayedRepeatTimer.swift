import Foundation

/// A timer that fires once after a delay, then repeats at a fixed interval.
/// Used for the backspace key behavior (press and hold to repeat delete).
final class DelayedRepeatTimer {

    private var initialTimer: Timer?
    private var repeatTimer: Timer?

    private let interval: TimeInterval
    private let action: () -> Void

    init(delay: TimeInterval, interval: TimeInterval, action: @escaping () -> Void) {
        self.interval = interval
        self.action = action

        initialTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.beginRepeating()
        }
    }

    private func beginRepeating() {
        action()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.action()
        }
    }

    func invalidate() {
        initialTimer?.invalidate()
        initialTimer = nil
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}
