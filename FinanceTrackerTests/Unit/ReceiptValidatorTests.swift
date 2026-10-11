import XCTest
@testable import FinanceTracker

@MainActor
final class ReceiptValidatorTests: XCTestCase {
    func testMoneyConvertsExactlyWithoutFloatingPoint() {
        for (text, expected) in [("0", Int64(0)), ("0.01", 1), ("3.9", 390), (" 3.99\n", 399), ("999999999.99", 99_999_999_999)] {
            XCTAssertEqual(ReceiptValidator.cents(from: text), expected, text)
        }
    }

    func testMoneyRejectsAmbiguousAndOutOfRangeValues() {
        XCTAssertNil(ReceiptValidator.cents(from: nil))
        for text in ["", " ", "$3.99", "3,99", "1,000.00", "3.999", "-1.00", "3.99%", "3 lb", "1e2", ".99", "3.", "1000000000", "999999999999999999999999"] {
            XCTAssertNil(ReceiptValidator.cents(from: text), text)
        }
    }

    func testMatchingItemsAndMultipleTaxesPass() {
        let report = ReceiptValidator.validate(ReceiptFixtures.extraction())
        XCTAssertFalse(report.needsReview)
        XCTAssertEqual(report.messages.filter { $0.hasPrefix("Passed:") }.count, 2)
    }

    func testMissingMerchantIsFlagged() {
        for name in [nil, "", " \n", "Unknown", "NOT SHOWN"] as [String?] {
            var receipt = ReceiptFixtures.extraction()
            receipt.merchantName = name
            XCTAssertTrue(ReceiptValidator.validate(receipt).messages.contains { $0.contains("Merchant name is missing") })
        }
    }

    func testMissingAndInvalidItemPricesHaveDifferentDiagnostics() {
        var receipt = ReceiptFixtures.extraction()
        receipt.items[0].lineTotal = nil
        XCTAssertTrue(ReceiptValidator.validate(receipt).messages.contains { $0.contains("no extracted line total") })
        receipt.items[0].lineTotal = "$3.99"
        let report = ReceiptValidator.validate(receipt)
        XCTAssertTrue(report.messages.contains { $0.contains("invalid line total") && $0.contains("$3.99") })
        XCTAssertFalse(report.messages.contains { $0.contains("no extracted line total") })
        XCTAssertFalse(report.messages.contains { $0.contains("item amounts match") })
    }

    func testEmptyItemsAndBlankItemNamesNeedReview() {
        var receipt = ReceiptFixtures.extraction()
        receipt.items[0].name = " "
        XCTAssertTrue(ReceiptValidator.validate(receipt).needsReview)
        receipt.items = []
        XCTAssertTrue(ReceiptValidator.validate(receipt).messages.contains { $0.contains("No items") })
    }

    func testItemSubtotalMismatchIsFlagged() {
        var receipt = ReceiptFixtures.extraction()
        receipt.items[0].lineTotal = "4.00"
        XCTAssertTrue(ReceiptValidator.validate(receipt).messages.contains { $0.contains("Items add up") })
    }

    func testUnknownTaxIsNotTreatedAsZero() {
        var receipt = ReceiptFixtures.extraction()
        receipt.taxAmounts = []
        receipt.total = receipt.subtotal
        let report = ReceiptValidator.validate(receipt)
        XCTAssertTrue(report.needsReview)
        XCTAssertFalse(report.messages.contains { $0.contains("subtotal plus tax matches") })
        receipt.taxAmounts = ["0.00"]
        XCTAssertFalse(ReceiptValidator.validate(receipt).needsReview)
    }

    func testInvalidTaxPreventsPassingTotalCheck() {
        var receipt = ReceiptFixtures.extraction()
        receipt.taxAmounts = ["6%"]
        let report = ReceiptValidator.validate(receipt)
        XCTAssertTrue(report.messages.contains { $0.contains("tax amount is invalid") })
        XCTAssertFalse(report.messages.contains { $0.contains("subtotal plus tax matches") })
    }

    func testTotalMismatchAndMissingSummaryNeedReview() {
        var receipt = ReceiptFixtures.extraction()
        receipt.total = "10.00"
        XCTAssertTrue(ReceiptValidator.validate(receipt).messages.contains { $0.contains("Subtotal plus tax is") })
        receipt.total = nil
        receipt.subtotal = nil
        let report = ReceiptValidator.validate(receipt)
        XCTAssertTrue(report.messages.contains { $0.contains("Subtotal is missing") })
        XCTAssertTrue(report.messages.contains { $0.contains("Total is missing") })
    }
}
