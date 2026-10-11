import XCTest
@testable import FinanceTracker

@MainActor
final class ReceiptImportDraftTests: XCTestCase {
    func testWeightedQuantityAndUnknownUnitPriceArePreserved() {
        let draft = ReceiptFixtures.draft()
        XCTAssertEqual(draft.items[1].quantity, "0.5")
        XCTAssertEqual(draft.items[1].quantityUnit, "lb")
        XCTAssertEqual(draft.items[1].unitPrice, "5.96")
        XCTAssertEqual(draft.items[0].quantity, "1")
        XCTAssertTrue(draft.items[0].unitPrice.isEmpty)
        XCTAssertEqual(draft.taxCents, 30)
        XCTAssertTrue(draft.canSave)
    }

    func testQuantityParsingRejectsZeroNegativeUnitsAndExcessPrecision() {
        XCTAssertEqual(ReceiptImportDraft.quantity(from: " 1.25 "), Decimal(string: "1.25"))
        for text in ["0", "-1", "1 lb", "", "1,5", "1.1234567", "1e2", "1000000000"] {
            XCTAssertNil(ReceiptImportDraft.quantity(from: text), text)
        }
    }

    func testMalformedExtractedQuantityRequiresCorrection() {
        var receipt = ReceiptFixtures.extraction()
        receipt.items[1].quantity = "unknown"
        let draft = ReceiptImportDraft(extraction: receipt)
        XCTAssertEqual(draft.items[1].quantity, "unknown")
        XCTAssertFalse(draft.canSave)
    }

    func testEditingUpdatesValidationAndSaveEligibility() {
        var draft = ReceiptFixtures.draft()
        draft.items[0].lineTotal = ""
        XCTAssertFalse(draft.canSave)
        XCTAssertTrue(draft.report.needsReview)
        draft.items[0].lineTotal = "3.99"
        XCTAssertTrue(draft.canSave)
        XCTAssertFalse(draft.report.needsReview)
    }

    func testMissingRequiredFieldsBlockSaving() {
        var draft = ReceiptFixtures.draft()
        draft.merchantName = "Unknown"
        XCTAssertFalse(draft.canSave)
        draft.merchantName = "Example Grocery"
        draft.total = ""
        XCTAssertFalse(draft.canSave)
        draft.total = "7.27"
        draft.items[0].name = " "
        XCTAssertFalse(draft.canSave)
        draft.items = []
        XCTAssertTrue(draft.canSave)
    }

    func testHiddenSummaryDoesNotBlockSavingButInvalidVisibleUnitPriceDoes() {
        var draft = ReceiptFixtures.draft()
        draft.subtotal = "$6.97"
        XCTAssertTrue(draft.canSave)
        draft.subtotal = ""
        XCTAssertTrue(draft.canSave)
        draft.items[0].unitPrice = "three"
        XCTAssertFalse(draft.canSave)
        draft.items[0].unitPrice = " "
        XCTAssertTrue(draft.canSave)
    }

    func testUnknownZeroAndInvalidTaxRemainDistinct() {
        var draft = ReceiptFixtures.draft()
        draft.taxes = []
        XCTAssertNil(draft.taxCents)
        XCTAssertTrue(draft.canSave)
        XCTAssertTrue(draft.report.needsReview)
        draft.taxes = [.init(amount: "0.00")]
        XCTAssertEqual(draft.taxCents, 0)
        draft.taxes = [.init(amount: "invalid")]
        XCTAssertNil(draft.taxCents)
        XCTAssertTrue(draft.canSave)
    }

    func testReviewRetainsEvidenceAndExtractionWarnings() {
        var receipt = ReceiptFixtures.extraction()
        receipt.warnings = ["Verify item association"]
        let draft = ReceiptImportDraft(extraction: receipt)
        XCTAssertEqual(draft.extraction.merchantEvidence, receipt.merchantEvidence)
        XCTAssertEqual(draft.extraction.warnings, receipt.warnings)
        XCTAssertEqual(draft.extraction.items.count, receipt.items.count)
    }
}
