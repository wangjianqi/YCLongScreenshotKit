#if DEBUG
import Photos
import SwiftUI
import UIKit

/// Uses Photos add-only access. The HOST app must add NSPhotoLibraryAddUsageDescription.
public enum YCLongScreenshotPhotoLibrary {
    @MainActor
    public static func save(_ result: YCLongScreenshotResult) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw YCLongScreenshotError.photoAccessDenied
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: result.fileURL)
        }
    }
}

/// Presents iOS's native sharing sheet (including AirDrop and Save Image).
public struct YCLongScreenshotShareSheet: UIViewControllerRepresentable {
    public let image: UIImage

    public init(image: UIImage) { self.image = image }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [image], applicationActivities: nil
        )
        if Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryAddUsageDescription") == nil {
            controller.excludedActivityTypes = [.saveToCameraRoll]
        }
        // Hosted by SwiftUI's sheet, which supplies the appropriate iPad presentation.
        return controller
    }

    public func updateUIViewController(
        _ uiViewController: UIActivityViewController, context: Context
    ) {}
}

#endif
