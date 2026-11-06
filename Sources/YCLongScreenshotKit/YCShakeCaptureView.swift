#if DEBUG
import SwiftUI
import UIKit

/// Simpler trigger for buttons and UI tests; post this from the current scene's app code.
public enum YCLongScreenshotTrigger {
    public static let captureRequested = Notification.Name("cn.yuechuan.YCLongScreenshotKit.captureRequested")

    public static func requestCapture() {
        NotificationCenter.default.post(name: captureRequested, object: nil)
    }
}

/// A responder-chain-based SwiftUI shake detector. A focused TextField may own the
/// first responder and therefore suppress shake callbacks; use YCShakeCaptureWindow
/// for UIKit apps that require consistent detection in that situation.
struct YCShakeCaptureView: UIViewRepresentable {
    let onShake: () -> Void

    func makeUIView(context: Context) -> YCShakeResponderView {
        let view = YCShakeResponderView()
        view.shakeHandler = onShake
        return view
    }

    func updateUIView(_ view: YCShakeResponderView, context: Context) {
        view.shakeHandler = onShake
    }
}

final class YCShakeResponderView: UIView {
    var shakeHandler: (() -> Void)?
    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window != nil, !self.isFirstResponder else { return }
            _ = self.becomeFirstResponder()
        }
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake { shakeHandler?() }
        super.motionEnded(motion, with: event)
    }
}

/// Alternative for apps using a custom UIWindow / SceneDelegate; captures shakes
/// even when keyboard focus moves away from the SwiftUI responder view.
open class YCShakeCaptureWindow: UIWindow {
    public var onScreenshotShake: (() -> Void)?

    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake { onScreenshotShake?() }
        super.motionEnded(motion, with: event)
    }
}

#endif
