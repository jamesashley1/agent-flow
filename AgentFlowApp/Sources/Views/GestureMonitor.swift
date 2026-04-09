import AppKit

// MARK: - Gesture Monitor

/// App-level event monitors for trackpad/mouse gestures.
/// Uses NSEvent.addLocalMonitorForEvents so no overlay view is needed,
/// which means clicks pass through to SwiftUI views cleanly.
final class GestureMonitor: NSObject {
    var onZoom: ((CGFloat) -> Void)?
    var onPan: ((CGFloat, CGFloat) -> Void)?

    private var scrollMonitor: Any?
    private var magnifyMonitor: Any?
    private var gestureRecognizer: NSMagnificationGestureRecognizer?
    private var windowObserver: Any?
    private var attached = false

    func start() {
        // Scroll wheel monitor (pan + mouse-wheel zoom)
        if scrollMonitor == nil {
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.handleScroll(event)
                return event
            }
        }

        // Magnify monitor (trackpad pinch)
        if magnifyMonitor == nil {
            magnifyMonitor = NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] event in
                self?.onZoom?(event.magnification)
                return event
            }
        }

        // Also attach gesture recognizer to window for reliable pinch
        attachToWindow()
        if windowObserver == nil {
            windowObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: nil, queue: .main
            ) { [weak self] _ in self?.attachToWindow() }
        }
    }

    private func handleScroll(_ event: NSEvent) {
        // Trackpad pinch-to-zoom arrives as scroll events with .control modifier
        if event.modifierFlags.contains(.option) || event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
            onZoom?(-event.scrollingDeltaY * 0.01)
        } else if event.hasPreciseScrollingDeltas {
            onPan?(event.scrollingDeltaX, -event.scrollingDeltaY)
        } else {
            onZoom?(-event.scrollingDeltaY * 0.03)
        }
    }

    private func attachToWindow() {
        guard !attached else { return }
        guard let window = NSApplication.shared.mainWindow ?? NSApplication.shared.keyWindow,
              let contentView = window.contentView else { return }

        let recognizer = NSMagnificationGestureRecognizer(target: self, action: #selector(handleMagnify(_:)))
        contentView.addGestureRecognizer(recognizer)
        gestureRecognizer = recognizer
        attached = true
    }

    @objc private func handleMagnify(_ recognizer: NSMagnificationGestureRecognizer) {
        onZoom?(recognizer.magnification)
        recognizer.magnification = 0
    }

    func stop() {
        if let m = scrollMonitor { NSEvent.removeMonitor(m); scrollMonitor = nil }
        if let m = magnifyMonitor { NSEvent.removeMonitor(m); magnifyMonitor = nil }
        if let r = gestureRecognizer, let v = r.view { v.removeGestureRecognizer(r) }
        gestureRecognizer = nil; attached = false
        if let o = windowObserver { NotificationCenter.default.removeObserver(o); windowObserver = nil }
    }

    deinit { stop() }
}
