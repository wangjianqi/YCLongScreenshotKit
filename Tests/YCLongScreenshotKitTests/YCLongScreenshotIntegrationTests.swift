import XCTest
import UIKit
@testable import YCLongScreenshotKit

@MainActor
final class YCLongScreenshotIntegrationTests: XCTestCase {
    func testExplicitScrollCaptureRestoresOffsetAndCreatesPNG() async throws {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            throw XCTSkip("截图集成测试需要带 UIWindowScene 的 iOS App 测试宿主。")
        }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
        defer { window.isHidden = true }
        let vc = UIViewController()
        window.rootViewController = vc
        vc.view.frame = window.bounds
        vc.view.backgroundColor = .systemTeal

        let scroll = UIScrollView(frame: CGRect(x: 0, y: 80, width: 390, height: 550))
        scroll.backgroundColor = .clear
        scroll.contentSize = CGSize(width: 390, height: 1900)
        vc.view.addSubview(scroll)
        for index in 0..<19 {
            let label = UILabel(frame: CGRect(x: 20, y: index * 100, width: 330, height: 100))
            label.text = "Row \(index)"
            scroll.addSubview(label)
        }
        window.makeKeyAndVisible()
        scroll.setContentOffset(CGPoint(x: 0, y: 110), animated: false)

        try await Task.sleep(nanoseconds: 100_000_000)

        // A transparent scroll view must retain the background composited by its parent.
        let reference = try XCTUnwrap(YCCaptureRendering.snapshot(of: window, scale: 1))
        let sampleRect = CGRect(x: 2, y: 120, width: 4, height: 4)
        let expectedBackground = try XCTUnwrap(reference.cgImage?.cropping(to: sampleRect))

        let result = try await YCLongScreenshotKit.shared.capture(
            scrollView: scroll,
            configuration: .init(scale: 1, settleDelay: 0.03)
        )

        let actualBackground = try XCTUnwrap(result.image.cgImage?.cropping(to: sampleRect))
        XCTAssertEqual(
            UIImage(cgImage: actualBackground).pngData(),
            UIImage(cgImage: expectedBackground).pngData()
        )
        XCTAssertTrue(result.isLongScreenshot)
        XCTAssertTrue(result.includesPageChrome)
        XCTAssertEqual(result.image.size.width, 390, accuracy: 1)
        XCTAssertGreaterThan(result.image.size.height, 1800)
        XCTAssertEqual(scroll.contentOffset.y, 110, accuracy: 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.fileURL.path))
        try? FileManager.default.removeItem(at: result.fileURL)
    }
}
