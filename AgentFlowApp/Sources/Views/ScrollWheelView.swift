import SwiftUI
import AppKit

// MARK: - Magnify Capture View

/// Transparent NSView overlay that captures trackpad pinch (magnify) gestures
/// via an NSMagnificationGestureRecognizer. Mouse clicks and drags pass through
/// because hitTest returns nil — only the gesture recognizer receives pinch input.
struct MagnifyCaptureView: NSViewRepresentable {
    var onMagnify: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onMagnify: onMagnify)
    }

    func makeNSView(context: Context) -> NSView {
        let view = PassthroughView()
        view.wantsLayer = true

        let recognizer = NSMagnificationGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMagnify(_:))
        )
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onMagnify = onMagnify
    }

    class PassthroughView: NSView {
        // Let mouse clicks/drags pass through to SwiftUI Canvas below
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        // But still allow gesture recognizers attached to this view to work
        override var allowedTouchTypes: NSTouch.TouchTypeMask {
            get { [.direct, .indirect] }
            set {}
        }
    }

    class Coordinator: NSObject {
        var onMagnify: (CGFloat) -> Void

        init(onMagnify: @escaping (CGFloat) -> Void) {
            self.onMagnify = onMagnify
        }

        @objc func handleMagnify(_ recognizer: NSMagnificationGestureRecognizer) {
            onMagnify(recognizer.magnification)
            if recognizer.state == .changed {
                recognizer.magnification = 0
            }
        }
    }
}
