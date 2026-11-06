#if DEBUG
import Foundation

/// A non-overlapping strip read from a viewport frame and placed in the final image.
struct YCScrollSlice: Equatable {
    let frameIndex: Int
    let sourceTop: CGFloat
    let destinationTop: CGFloat
    let height: CGFloat
}

enum YCScrollSlicePlanner {
    /// Offsets are the *actual* scroll positions measured after layout, not requested offsets.
    /// Each successive viewport must overlap the area already captured or touch it exactly.
    static func makeSlices(offsets: [CGFloat], viewportHeight: CGFloat) throws -> [YCScrollSlice] {
        guard let first = offsets.first, first.isFinite,
              viewportHeight.isFinite, viewportHeight > 0 else {
            throw YCLongScreenshotError.invalidGeometry
        }

        var coveredUntil: CGFloat = 0
        var slices: [YCScrollSlice] = []

        for (index, offset) in offsets.enumerated() {
            guard offset.isFinite else { throw YCLongScreenshotError.invalidGeometry }
            let start = offset - first
            // Allow sub-point rounding drift, but never silently introduce a hole.
            guard start >= -0.5, start <= coveredUntil + 0.5 else {
                throw YCLongScreenshotError.contentDidNotAdvance
            }
            let newStart = max(coveredUntil, start)
            let sourceTop = max(0, newStart - start)
            let height = viewportHeight - sourceTop
            if height > 0.5 {
                slices.append(YCScrollSlice(
                    frameIndex: index,
                    sourceTop: sourceTop,
                    destinationTop: newStart,
                    height: height
                ))
                coveredUntil = newStart + height
            }
        }
        return slices
    }
}

#endif
