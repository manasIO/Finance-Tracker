import XCTest
import UIKit
@testable import FinanceTracker

@MainActor
final class ReceiptOCRServiceTests: XCTestCase {
    private func image(withText: Bool) throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 600))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1000, height: 600))
            if withText {
                let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 48), .foregroundColor: UIColor.black]
                for (index, text) in ["EXAMPLE GROCERY", "MILK 3.99", "TOTAL 3.99"].enumerated() {
                    (text as NSString).draw(at: CGPoint(x: 60, y: 60 + index * 140), withAttributes: attributes)
                }
            }
        }
        return try XCTUnwrap(image.pngData())
    }

    func testVisionReadsSyntheticReceiptInReadingOrder() async throws {
        let text = try await ReceiptOCRService().recognizeText(in: image(withText: true))
        XCTAssertTrue(text.contains("EXAMPLE GROCERY"), text)
        XCTAssertTrue(text.contains("MILK"), text)
        XCTAssertTrue(text.contains("3.99"), text)
        let header = try XCTUnwrap(text.range(of: "EXAMPLE GROCERY"))
        let total = try XCTUnwrap(text.range(of: "TOTAL"))
        XCTAssertLessThan(header.lowerBound, total.lowerBound)
    }

    func testInvalidImageReturnsRecoverableError() async {
        do {
            _ = try await ReceiptOCRService().recognizeText(in: Data([0, 1, 2]))
            XCTFail("Invalid image accepted")
        } catch ReceiptOCRService.OCRError.invalidImage {
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    func testBlankImageReturnsNoTextError() async throws {
        let data = try image(withText: false)
        do {
            _ = try await ReceiptOCRService().recognizeText(in: data)
            XCTFail("Blank image accepted")
        } catch ReceiptOCRService.OCRError.noTextFound {
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    func testCancelledOCRReturnsCancellation() async {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await ReceiptOCRService().recognizeText(in: Data())
        }
        do {
            _ = try await task.value
            XCTFail("Cancelled OCR ran")
        } catch is CancellationError {
        } catch { XCTFail("Unexpected error: \(error)") }
    }
}
