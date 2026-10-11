import XCTest
import UIKit
@testable import FinanceTracker

@MainActor
final class ReceiptPhotoEncoderTests: XCTestCase {
    func testLargeCameraImageIsResizedForOCR() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4000, height: 1000)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4000, height: 1000))
        }
        let data = try XCTUnwrap(ReceiptPhotoEncoder.data(from: image))
        let decoded = try XCTUnwrap(UIImage(data: data)?.cgImage)
        XCTAssertEqual(decoded.width, 3000)
        XCTAssertEqual(decoded.height, 750)
    }

    func testCameraOrientationIsAppliedBeforeEncoding() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 60)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 60))
        }
        let rotated = UIImage(cgImage: try XCTUnwrap(image.cgImage), scale: 1, orientation: .right)
        let data = try XCTUnwrap(ReceiptPhotoEncoder.data(from: rotated))
        let decoded = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(decoded.imageOrientation, .up)
        XCTAssertEqual(decoded.size, rotated.size)
    }

    func testEmptyImageIsRejected() {
        XCTAssertNil(ReceiptPhotoEncoder.data(from: UIImage()))
    }
}
