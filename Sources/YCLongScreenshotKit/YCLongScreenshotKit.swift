import Foundation
import UIKit

/// Capture the currently visible page without adding hooks to each list row.
/// All UIKit state changes run on the main actor; the original scroll position is restored.
@MainActor
public final class YCLongScreenshotKit {
    public static let shared = YCLongScreenshotKit()

    public private(set) var isCapturing = false
    private init() {}

    /// Automatically locate the most relevant vertical scroll view in the foreground page.
    /// If none exists, optionally return a regular screenshot of the current window.
    public func captureCurrentPage(
        configuration: YCLongScreenshotConfiguration = .init()
    ) async throws -> YCLongScreenshotResult {
        guard let window = YCScrollViewLocator.activeWindow() else {
            throw YCLongScreenshotError.noActiveWindow
        }
        return try await capture(in: window, scrollView: nil, configuration: configuration)
    }

    /// Use for split views, nested scrolling, or a page where automatic selection is ambiguous.
    public func capture(
        scrollView: UIScrollView,
        configuration: YCLongScreenshotConfiguration = .init()
    ) async throws -> YCLongScreenshotResult {
        guard let window = scrollView.window else {
            throw YCLongScreenshotError.noActiveWindow
        }
        return try await capture(in: window, scrollView: scrollView, configuration: configuration)
    }

    private func capture(
        in window: UIWindow,
        scrollView explicitScrollView: UIScrollView?,
        configuration: YCLongScreenshotConfiguration
    ) async throws -> YCLongScreenshotResult {
        guard !isCapturing else { throw YCLongScreenshotError.alreadyCapturing }
        guard configuration.scale.isFinite, configuration.scale >= 1,
              configuration.scale <= 3,
              configuration.maximumSteps > 0,
              configuration.maximumOutputPixels > 0,
              configuration.maximumBufferedPixels > 0,
              configuration.overlap.isFinite,
              configuration.settleDelay.isFinite else {
            throw YCLongScreenshotError.invalidGeometry
        }
        isCapturing = true
        defer { isCapturing = false }

        guard let scrollView = explicitScrollView ?? YCScrollViewLocator.bestScrollView(in: window) else {
            guard configuration.captureVisiblePageIfNotScrollable else {
                throw YCLongScreenshotError.noScrollView
            }
            return try regularScreenshot(of: window, configuration: configuration)
        }

        let originalOffset = scrollView.contentOffset
        let originalInteraction = scrollView.isUserInteractionEnabled
        let originalVerticalIndicator = scrollView.showsVerticalScrollIndicator
        let originalHorizontalIndicator = scrollView.showsHorizontalScrollIndicator
        defer {
            scrollView.setContentOffset(originalOffset, animated: false)
            scrollView.layoutIfNeeded()
            scrollView.isUserInteractionEnabled = originalInteraction
            scrollView.showsVerticalScrollIndicator = originalVerticalIndicator
            scrollView.showsHorizontalScrollIndicator = originalHorizontalIndicator
        }
        scrollView.isUserInteractionEnabled = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false

        scrollView.setContentOffset(
            CGPoint(x: originalOffset.x, y: -scrollView.adjustedContentInset.top),
            animated: false
        )
        try await settle(view: scrollView, delay: configuration.settleDelay)
        // Large-title navigation bars can change safe-area insets as the list reaches the top.
        // Re-evaluate inset and visible viewport AFTER scrolling to the top.
        let minY = -scrollView.adjustedContentInset.top
        if abs(scrollView.contentOffset.y - minY) > 0.5 {
            scrollView.setContentOffset(
                CGPoint(x: originalOffset.x, y: minY), animated: false
            )
            try await settle(view: scrollView, delay: configuration.settleDelay)
        }
        let viewport = YCScrollViewLocator.visibleFrame(of: scrollView, in: window)
        let actualFrame = scrollView.convert(scrollView.bounds, to: window)
        let sourceRect = viewport.offsetBy(dx: -actualFrame.minX, dy: -actualFrame.minY)
        guard !viewport.isNull, viewport.width >= 1, viewport.height >= 1,
              sourceRect.minX >= -1, sourceRect.minY >= -1,
              sourceRect.maxX <= scrollView.bounds.width + 1,
              sourceRect.maxY <= scrollView.bounds.height + 1 else {
            throw YCLongScreenshotError.invalidGeometry
        }

        let initialMax = max(minY, scrollView.contentSize.height
                             + scrollView.adjustedContentInset.bottom - scrollView.bounds.height)
        if initialMax - minY < 8 {
            guard configuration.captureVisiblePageIfNotScrollable else {
                throw YCLongScreenshotError.noScrollView
            }
            return try regularScreenshot(of: window, configuration: configuration)
        }

        // Build the strips separately from the window chrome. This prevents external
        // floating controls / navigation UI from being repeated in every scroll segment.
        let fullWidth = viewport.minX <= 2 &&
            viewport.maxX >= window.bounds.width - 2
        let includeChrome = configuration.layout == .page && fullWidth
        let windowImage: UIImage?
        if includeChrome {
            windowImage = YCCaptureRendering.snapshot(of: window, scale: configuration.scale)
            guard windowImage != nil else { throw YCLongScreenshotError.renderingFailed }
        } else {
            windowImage = nil
        }

        var images: [UIImage] = []
        var positions: [CGFloat] = []
        var bufferedPixels: Double = 0
        let step = max(8, viewport.height - max(0, min(configuration.overlap, viewport.height - 8)))
        var reachedBottom = false

        for _ in 0..<configuration.maximumSteps {
            try Task.checkCancellation()
            guard scrollView.window === window else {
                throw YCLongScreenshotError.noActiveWindow
            }
            try await settle(view: scrollView, delay: configuration.settleDelay)
            let position = scrollView.contentOffset.y
            guard position.isFinite else { throw YCLongScreenshotError.invalidGeometry }

            // Limit allocations before taking another frame.
            let estimatedHeight = (position - minY) + viewport.height
                + (includeChrome ? window.bounds.height - viewport.height : 0)
            try YCCaptureRendering.checkDimensions(
                CGSize(width: includeChrome ? window.bounds.width : viewport.width,
                       height: estimatedHeight), configuration: configuration
            )

            guard let frame = YCCaptureRendering.snapshot(of: scrollView, scale: configuration.scale) else {
                throw YCLongScreenshotError.renderingFailed
            }
            bufferedPixels += Double(frame.size.width * frame.size.height
                                     * configuration.scale * configuration.scale)
            guard bufferedPixels <= Double(configuration.maximumBufferedPixels) else {
                throw YCLongScreenshotError.excessiveImageSize
            }
            images.append(frame)
            positions.append(position)

            // Content height can grow while lazy rows are realized. Re-evaluate on each pass.
            let maxOffset = max(minY, scrollView.contentSize.height
                                + scrollView.adjustedContentInset.bottom - scrollView.bounds.height)
            if position >= maxOffset - 0.5 {
                reachedBottom = true
                break
            }
            let nextOffset = min(position + step, maxOffset)
            guard nextOffset > position + 0.5 else {
                throw YCLongScreenshotError.contentDidNotAdvance
            }
            scrollView.setContentOffset(
                CGPoint(x: originalOffset.x, y: nextOffset), animated: false
            )
        }
        guard reachedBottom else { throw YCLongScreenshotError.captureLimitReached }
        guard let firstFrame = images.first else { throw YCLongScreenshotError.renderingFailed }
        let composed = try YCCaptureRendering.compose(
            scrollFrames: images,
            positions: positions,
            visibleSourceRect: sourceRect,
            visibleWindowRect: viewport,
            windowImage: windowImage ?? firstFrame,
            windowSize: window.bounds.size,
            includeChrome: includeChrome,
            configuration: configuration,
            backgroundColor: UIColor.systemBackground.resolvedColor(with: scrollView.traitCollection)
        )
        return try export(
            composed, long: true, chrome: includeChrome
        )
    }

    private func regularScreenshot(
        of window: UIWindow,
        configuration: YCLongScreenshotConfiguration
    ) throws -> YCLongScreenshotResult {
        try YCCaptureRendering.checkDimensions(window.bounds.size, configuration: configuration)
        guard let image = YCCaptureRendering.snapshot(of: window, scale: configuration.scale) else {
            throw YCLongScreenshotError.renderingFailed
        }
        return try export(image, long: false, chrome: true)
    }

    private func export(
        _ image: UIImage, long: Bool, chrome: Bool
    ) throws -> YCLongScreenshotResult {
        guard let data = image.pngData() else { throw YCLongScreenshotError.exportFailed }
        let date = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let name = "YCLongScreenshot-\(date)-\(UUID().uuidString.prefix(8)).png"
        let directory = FileManager.default.temporaryDirectory
        let url = directory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw YCLongScreenshotError.exportFailed
        }
        return YCLongScreenshotResult(
            image: image,
            fileURL: url,
            pixelSize: CGSize(width: image.size.width * image.scale,
                              height: image.size.height * image.scale),
            isLongScreenshot: long,
            includesPageChrome: chrome
        )
    }

    private func settle(view: UIView, delay: TimeInterval) async throws {
        view.setNeedsLayout()
        view.layoutIfNeeded()
        let nanoseconds = UInt64(max(0.03, min(delay, 2)) * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
        view.layoutIfNeeded()
    }
}
