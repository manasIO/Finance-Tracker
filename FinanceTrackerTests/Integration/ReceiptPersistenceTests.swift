import XCTest
import SwiftData
@testable import FinanceTracker

@MainActor
final class ReceiptPersistenceTests: XCTestCase {
    private func container(url: URL? = nil) throws -> ModelContainer {
        let config = url.map { ModelConfiguration(url: $0) } ?? ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Receipt.self, ReceiptItem.self, configurations: config)
    }

    func testHostUsesIsolatedStorageDuringTesting() {
        XCTAssertEqual(ProcessInfo.processInfo.environment["FINANCE_TRACKER_TESTING"], "1")
    }

    func testSavingDraftPersistsAllFieldsAndInverseRelationships() throws {
        let store = try container()
        var draft = ReceiptFixtures.draft()
        draft.merchantName = "  Example Grocery  "
        draft.items[1].classification = "Want"
        let receipt = try ReceiptImportStore.save(draft, confirmedReview: false, in: store.mainContext)
        let saved = try store.mainContext.fetch(FetchDescriptor<Receipt>())
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(receipt.merchantName, "Example Grocery")
        XCTAssertEqual(receipt.purchaseDate, draft.purchaseDate)
        XCTAssertEqual(receipt.totalCents, 727)
        XCTAssertEqual(receipt.subtotalCents, 697)
        XCTAssertEqual(receipt.taxCents, 30)
        XCTAssertEqual(receipt.items.count, 2)
        let apples = try XCTUnwrap(receipt.items.first { $0.name == "Apples" })
        XCTAssertEqual(apples.quantity, Decimal(string: "0.5"))
        XCTAssertEqual(apples.quantityUnit, "lb")
        XCTAssertEqual(apples.unitPriceCents, 596)
        XCTAssertEqual(apples.lineTotalCents, 298)
        XCTAssertEqual(apples.isLuxury, true)
        XCTAssertTrue(apples.receipt === receipt)
        let milk = try XCTUnwrap(receipt.items.first { $0.name == "Milk" })
        XCTAssertNil(milk.unitPriceCents)
        XCTAssertEqual(milk.category, "Groceries")
        XCTAssertEqual(milk.isLuxury, false)
    }

    func testInvalidDraftNeverInsertsPartialReceipt() throws {
        let store = try container()
        var draft = ReceiptFixtures.draft()
        draft.items[1].lineTotal = ""
        XCTAssertThrowsError(try ReceiptImportStore.save(draft, confirmedReview: true, in: store.mainContext))
        XCTAssertEqual(try store.mainContext.fetchCount(FetchDescriptor<Receipt>()), 0)
        XCTAssertEqual(try store.mainContext.fetchCount(FetchDescriptor<ReceiptItem>()), 0)
    }

    func testWarningsRequireConfirmationBeforeSaving() throws {
        let store = try container()
        var draft = ReceiptFixtures.draft()
        draft.total = "8.00"
        XCTAssertThrowsError(try ReceiptImportStore.save(draft, confirmedReview: false, in: store.mainContext))
        XCTAssertEqual(try store.mainContext.fetchCount(FetchDescriptor<Receipt>()), 0)
        let receipt = try ReceiptImportStore.save(draft, confirmedReview: true, in: store.mainContext)
        XCTAssertEqual(receipt.totalCents, 800)
    }

    func testExtractionWarningsAlsoRequireConfirmation() throws {
        let store = try container()
        var extraction = ReceiptFixtures.extraction()
        extraction.warnings = ["Price association needs checking"]
        let draft = ReceiptImportDraft(extraction: extraction)
        XCTAssertFalse(draft.report.needsReview)
        XCTAssertThrowsError(try ReceiptImportStore.save(draft, confirmedReview: false, in: store.mainContext))
        _ = try ReceiptImportStore.save(draft, confirmedReview: true, in: store.mainContext)
        XCTAssertEqual(try store.mainContext.fetchCount(FetchDescriptor<Receipt>()), 1)
    }

    func testUnknownTaxAndUnclassifiedItemsRemainUnknown() throws {
        let store = try container()
        var draft = ReceiptFixtures.draft()
        draft.taxes = []
        draft.subtotal = ""
        draft.items[0].classification = "Unclassified"
        let receipt = try ReceiptImportStore.save(draft, confirmedReview: true, in: store.mainContext)
        XCTAssertNil(receipt.taxCents)
        XCTAssertNil(receipt.subtotalCents)
        XCTAssertNil(receipt.items.first { $0.name == "Milk" }?.isLuxury)
    }

    func testDeletingReceiptCascadesOnlyItsOwnItems() throws {
        let store = try container()
        let first = try ReceiptImportStore.save(ReceiptFixtures.draft(), confirmedReview: false, in: store.mainContext)
        _ = try ReceiptImportStore.save(ReceiptFixtures.draft(), confirmedReview: false, in: store.mainContext)
        store.mainContext.delete(first)
        try store.mainContext.save()
        XCTAssertEqual(try store.mainContext.fetchCount(FetchDescriptor<Receipt>()), 1)
        XCTAssertEqual(try store.mainContext.fetchCount(FetchDescriptor<ReceiptItem>()), 2)
    }

    func testSavedReceiptSurvivesStoreReopening() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("receipt.store")
        var receiptID: UUID?
        do {
            let original = try container(url: url)
            receiptID = try ReceiptImportStore.save(ReceiptFixtures.draft(), confirmedReview: false, in: original.mainContext).id
        }
        let reopened = try container(url: url)
        let saved = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Receipt>()).first)
        XCTAssertEqual(saved.id, receiptID)
        XCTAssertEqual(saved.totalCents, 727)
        XCTAssertEqual(saved.taxCents, 30)
        XCTAssertEqual(saved.items.count, 2)
        XCTAssertEqual(saved.items.first { $0.name == "Apples" }?.quantityUnit, "lb")
    }

    func testImportAnalyzeEditAndSavePipeline() async throws {
        var service = ReceiptImportService()
        service.recognizeText = { _ in "Example Grocery\nMilk | 3.99" }
        service.extractReceipt = { _ in ReceiptFixtures.extraction() }
        let extraction = try await service.analyze(Data([1]))
        var draft = ReceiptImportDraft(extraction: extraction)
        draft.merchantName = "Corrected Grocery"
        draft.items[0].name = "Whole Milk"
        let store = try container()
        let receipt = try ReceiptImportStore.save(draft, confirmedReview: false, in: store.mainContext)
        XCTAssertEqual(receipt.merchantName, "Corrected Grocery")
        XCTAssertTrue(receipt.items.contains { $0.name == "Whole Milk" })
        XCTAssertEqual(try store.mainContext.fetchCount(FetchDescriptor<ReceiptItem>()), 2)
    }
}
