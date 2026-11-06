#if DEBUG
import UIKit

@MainActor
enum YCScrollViewLocator {
    static func activeWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        for scene in scenes {
            if let key = scene.windows.first(where: { $0.isKeyWindow && !$0.isHidden }) {
                return key
            }
        }
        return scenes.flatMap(\.windows).first(where: { !$0.isHidden && $0.windowLevel == .normal })
    }

    static func bestScrollView(in window: UIWindow) -> UIScrollView? {
        // A presented sheet/dialog must win over a scroll view behind the modal.
        var controller = window.rootViewController
        while let presented = controller?.presentedViewController,
              !presented.isBeingDismissed {
            controller = presented
        }
        let root = controller?.viewIfLoaded ?? window
        let candidates = allScrollViews(in: root)
        return candidates.max(by: { score($0, window: window) < score($1, window: window) })
            .flatMap { score($0, window: window) > 0 ? $0 : nil }
    }

    static func visibleFrame(of view: UIView, in window: UIWindow) -> CGRect {
        guard view.window === window else { return .null }
        // SwiftUI scroll views can extend beneath navigation and floating tab bars.
        // Stitch only the unobscured safe-area viewport, retaining the bars once.
        let visibleBounds = view.bounds.inset(by: view.safeAreaInsets)
        var result = view.convert(visibleBounds, to: window).intersection(window.bounds)
        var parent = view.superview
        while let ancestor = parent, ancestor !== window {
            if ancestor.clipsToBounds {
                result = result.intersection(ancestor.convert(ancestor.bounds, to: window))
            }
            if ancestor.isHidden || ancestor.alpha < 0.02 { return .null }
            parent = ancestor.superview
        }
        return result.isNull ? .null : result
    }

    private static func allScrollViews(in root: UIView) -> [UIScrollView] {
        var result: [UIScrollView] = []
        func visit(_ view: UIView) {
            guard !view.isHidden, view.alpha > 0.02 else { return }
            if let scroll = view as? UIScrollView { result.append(scroll) }
            for subview in view.subviews { visit(subview) }
        }
        visit(root)
        return result
    }

    private static func score(_ scroll: UIScrollView, window: UIWindow) -> CGFloat {
        let frame = visibleFrame(of: scroll, in: window)
        let overflow = scroll.contentSize.height + scroll.adjustedContentInset.top
            + scroll.adjustedContentInset.bottom - scroll.bounds.height
        guard scroll.isScrollEnabled, !frame.isNull,
              frame.width >= 120, frame.height >= 100, overflow >= 24,
              scroll.bounds.height > 0 else { return 0 }
        let visibility = frame.width * frame.height
        let depthBonus = 1 + min(overflow / frame.height, 4) * 0.08
        return visibility * depthBonus
    }
}

#endif
