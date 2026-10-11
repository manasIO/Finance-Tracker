import XCTest
import CoreGraphics
@testable import FinanceTracker

@MainActor
final class ReceiptOCRLayoutTests: XCTestCase {
    private func block(_ text: String, x: CGFloat, y: CGFloat, height: CGFloat = 0.03) -> ReceiptOCRService.TextBlock {
        .init(text: text, box: CGRect(x: x, y: y, width: 0.2, height: height))
    }

    func testReconstructsRowsTopToBottomAndPricesLeftToRight() async {
        let service = ReceiptOCRService()
        let text = await service.reconstructRows(from: [
            block("3.99", x: 0.7, y: 0.7), block("Total", x: 0.1, y: 0.2),
            block("Example Grocery", x: 0.2, y: 0.9), block("Milk", x: 0.1, y: 0.7),
            block("3.99", x: 0.7, y: 0.2)
        ])
        XCTAssertEqual(text, "Example Grocery\nMilk | 3.99\nTotal | 3.99")
    }

    func testNearbyDistinctRowsAreNotMerged() async {
        let text = await ReceiptOCRService().reconstructRows(from: [block("Milk", x: 0.1, y: 0.7), block("Bread", x: 0.1, y: 0.66)])
        XCTAssertEqual(text, "Milk\nBread")
    }

    func testSlightlyMisalignedPriceRemainsOnProductRow() async {
        let text = await ReceiptOCRService().reconstructRows(from: [block("Milk", x: 0.1, y: 0.7), block("3.99", x: 0.7, y: 0.705)])
        XCTAssertEqual(text, "Milk | 3.99")
    }

    func testEmptyLayoutProducesEmptyText() async {
        let text = await ReceiptOCRService().reconstructRows(from: [])
        XCTAssertTrue(text.isEmpty)
    }
}
