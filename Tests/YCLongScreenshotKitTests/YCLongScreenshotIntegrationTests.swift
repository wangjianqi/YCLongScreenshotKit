import XCTest
import UIKit
@testable import YCLongScreenshotKit

@MainActor
final class YCLongScreenshotIntegrationTests: XCTestCase {
    func testExplicitScrollCaptureRestoresOffsetAndCreatesPNG() async throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        let vc = UIViewController()
        window.rootViewController = vc
        vc.view.frame = window.bounds
        vc.view.backgroundColor = .systemBackground

        let scroll = UIScrollView(frame: CGRect(x: 0, y: 80, width: 390, height: 550))
        scroll.backgroundColor = .systemBackground
        scroll.contentSize = CGSize(width: 390, height: 1900)
        vc.view.addSubview(scroll)
        for index in 0..<19 {
            let label = UILabel(frame: CGRect(x: 20, y: index * 100, width: 330, height: 100))
            label.text = "Row \(index)"
            scroll.addSubview(label)
        }
        window.makeKeyAndVisible()
        scroll.setContentOffset(CGPoint(x: 0, y: 110), animated: false)

        let result = try await YCLongScreenshotKit.shared.capture(
            scrollView: scroll,
            configuration: .init(scale: 1, settleDelay: 0.03)
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
