import XCTest
@testable import FinanceTracker

@MainActor
final class ReceiptRedactorTests: XCTestCase {
    func testRemovesPaymentMetadataButKeepsPurchaseFacts() {
        let text = "Example Grocery\n123 Main Street\n(555) 123-4567\nMilk | 3.99\nAuth Code: 12345\nTotal | 3.99\nvisit example.com"
        XCTAssertEqual(ReceiptRedactor.prepare(text), "Example Grocery\nMilk | 3.99\nTotal | 3.99\nvisit example.com")
    }

    func testStopsBeforeSeparateTerminalReceipt() {
        XCTAssertEqual(ReceiptRedactor.prepare("Store\nTotal 3.99\nTransaction Receipt\nCard data\nTotal 3.99"), "Store\nTotal 3.99")
    }

    func testDoesNotRemoveProductContainingAddressWord() {
        XCTAssertEqual(ReceiptRedactor.prepare("  Road Trip Snacks | 3.99 \n\nStore Street Coffee | 2.00"), "Road Trip Snacks | 3.99\nStore Street Coffee | 2.00")
    }
}
