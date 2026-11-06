import Foundation
import UIKit

/// Controls how a scrollable page is exported.
public enum YCLongScreenshotLayout: Sendable, Equatable {
    /// Include the fixed areas above and below the scroll view once.
    /// Falls back to contentOnly for partial-width scroll views.
    case page
    /// Export just the content inside the detected scroll view.
    case contentOnly
}

public struct YCLongScreenshotConfiguration: Sendable {
    public var layout: YCLongScreenshotLayout
    /// Output image scale in pixels per point. 1 is memory-efficient; 2 is sharper.
    public var scale: CGFloat
    /// Wait for lazy rows and asynchronous cell layouts after each programmatic scroll.
    public var settleDelay: TimeInterval
    /// Crop the overlap rather than relying on pixel matching.
    public var overlap: CGFloat
    /// Prevent an unbounded / infinite-scrolling feed from capturing forever.
    public var maximumSteps: Int
    /// Hard limit on final image pixels (also protects the image encoding step).
    public var maximumOutputPixels: Int
    /// Limit cumulative pixels temporarily held in screenshot buffers.
    public var maximumBufferedPixels: Int
    /// When a page has no scrollable region, capture the visible window instead.
    public var captureVisiblePageIfNotScrollable: Bool

    public init(
        layout: YCLongScreenshotLayout = .page,
        scale: CGFloat = 1.5,
        settleDelay: TimeInterval = 0.18,
        overlap: CGFloat = 32,
        maximumSteps: Int = 50,
        maximumOutputPixels: Int = 28_000_000,
        maximumBufferedPixels: Int = 36_000_000,
        captureVisiblePageIfNotScrollable: Bool = true
    ) {
        self.layout = layout
        self.scale = scale
        self.settleDelay = settleDelay
        self.overlap = overlap
        self.maximumSteps = maximumSteps
        self.maximumOutputPixels = maximumOutputPixels
        self.maximumBufferedPixels = maximumBufferedPixels
        self.captureVisiblePageIfNotScrollable = captureVisiblePageIfNotScrollable
    }
}

@MainActor
public struct YCLongScreenshotResult {
    public let image: UIImage
    public let fileURL: URL
    public let pixelSize: CGSize
    public let isLongScreenshot: Bool
    public let includesPageChrome: Bool
}

public enum YCLongScreenshotError: LocalizedError {
    case alreadyCapturing
    case noActiveWindow
    case noScrollView
    case invalidGeometry
    case excessiveImageSize
    case captureLimitReached
    case renderingFailed
    case contentDidNotAdvance
    case photoAccessDenied
    case exportFailed

    public var errorDescription: String? {
        switch self {
        case .alreadyCapturing: return "A long screenshot is already in progress."
        case .noActiveWindow: return "No active application window was found."
        case .noScrollView: return "No vertically scrollable view was found."
        case .invalidGeometry: return "The visible scroll area has invalid dimensions."
        case .excessiveImageSize: return "The screenshot exceeds the configured memory or pixel limit."
        case .captureLimitReached: return "Capture stopped at the maximum scroll step limit."
        case .renderingFailed: return "A screenshot frame could not be rendered."
        case .contentDidNotAdvance: return "The scroll view stopped advancing before the capture completed."
        case .photoAccessDenied: return "Photo Library add-only permission was denied."
        case .exportFailed: return "The PNG screenshot could not be saved."
        }
    }
}
