#if DEBUG
import UIKit

@MainActor
enum YCCaptureRendering {
    static func snapshot(of view: UIView, scale: CGFloat) -> UIImage? {
        guard view.bounds.width > 0, view.bounds.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let background = (view.backgroundColor ?? UIColor.systemBackground)
            .resolvedColor(with: view.traitCollection)
        var didRender = false
        let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { context in
            background.setFill()
            context.fill(CGRect(origin: .zero, size: view.bounds.size))
            // Layer rendering drops materials and hosted content. Fail instead of exporting
            // a visually different fallback when UIKit cannot capture the composited hierarchy.
            didRender = view.drawHierarchy(
                in: CGRect(origin: .zero, size: view.bounds.size), afterScreenUpdates: false
            )
        }
        return didRender ? image : nil
    }

    static func compose(
        scrollFrames: [UIImage],
        positions: [CGFloat],
        visibleSourceRect: CGRect,
        visibleWindowRect: CGRect,
        windowImage: UIImage,
        windowSize: CGSize,
        includeChrome: Bool,
        configuration: YCLongScreenshotConfiguration,
        backgroundColor: UIColor
    ) throws -> UIImage {
        let slices = try YCScrollSlicePlanner.makeSlices(
            offsets: positions, viewportHeight: visibleSourceRect.height
        )
        guard let last = slices.last else { throw YCLongScreenshotError.renderingFailed }
        let totalScrollHeight = last.destinationTop + last.height
        let top = includeChrome ? visibleWindowRect.minY : 0
        let bottom = includeChrome ? max(0, windowSize.height - visibleWindowRect.maxY) : 0
        let outputWidth = includeChrome ? windowSize.width : visibleSourceRect.width
        let outputHeight = top + totalScrollHeight + bottom
        try checkDimensions(
            CGSize(width: outputWidth, height: outputHeight), configuration: configuration
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = configuration.scale
        format.opaque = true
        let size = CGSize(width: outputWidth, height: outputHeight)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let background = backgroundColor
            background.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            if includeChrome {
                // Paint the top and bottom chrome only ONCE. Never paint entire page frames repeatedly.
                drawPiece(
                    windowImage,
                    source: CGRect(x: 0, y: 0, width: windowSize.width, height: top),
                    destination: CGPoint(x: 0, y: 0), context: context.cgContext
                )
                drawPiece(
                    windowImage,
                    source: CGRect(x: 0, y: visibleWindowRect.maxY,
                                   width: windowSize.width, height: bottom),
                    destination: CGPoint(x: 0, y: top + totalScrollHeight),
                    context: context.cgContext
                )
            }

            let x = includeChrome ? visibleWindowRect.minX : 0
            for slice in slices {
                let source = CGRect(
                    x: visibleSourceRect.minX,
                    y: visibleSourceRect.minY + slice.sourceTop,
                    width: visibleSourceRect.width,
                    height: slice.height
                )
                drawPiece(
                    scrollFrames[slice.frameIndex], source: source,
                    destination: CGPoint(x: x, y: top + slice.destinationTop),
                    context: context.cgContext
                )
            }
        }
    }

    static func checkDimensions(
        _ size: CGSize, configuration: YCLongScreenshotConfiguration
    ) throws {
        let width = size.width * configuration.scale
        let height = size.height * configuration.scale
        guard width.isFinite, height.isFinite, width > 0, height > 0,
              width <= 32_000, height <= 32_000,
              Double(width * height) <= Double(configuration.maximumOutputPixels) else {
            throw YCLongScreenshotError.excessiveImageSize
        }
    }

    /// Draw a sub-rectangle of a UIKit-oriented UIImage into a final UIKit graphics context.
    /// Clipping and translation prevent duplicate rows at overlapping scroll offsets.
    private static func drawPiece(
        _ image: UIImage, source: CGRect, destination: CGPoint, context: CGContext
    ) {
        guard source.width > 0, source.height > 0 else { return }
        let destinationRect = CGRect(origin: destination, size: source.size)
        context.saveGState()
        context.clip(to: destinationRect)
        image.draw(at: CGPoint(x: destination.x - source.minX,
                               y: destination.y - source.minY))
        context.restoreGState()
    }
}


#endif
