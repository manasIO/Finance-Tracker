import XCTest
import SwiftData
@testable import FinanceTracker

// The original persisted schema, before subtotal, tax, and quantity units.
private enum LegacyReceiptSchema: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Receipt.self, ReceiptItem.self] }

    @Model final class Receipt {
        var id: UUID
        var merchantName: String
        var purchaseDate: Date
        var currencyCode: String
        var totalCents: Int64
        @Relationship(deleteRule: .cascade, inverse: \ReceiptItem.receipt)
        var items: [ReceiptItem] = []

        init() {
            id = UUID()
            merchantName = "Existing Grocery"
            purchaseDate = Date(timeIntervalSince1970: 1_700_000_000)
            currencyCode = "USD"
            totalCents = 399
        }
    }

    @Model final class ReceiptItem {
        var id: UUID
        var name: String
        var quantity: Decimal
        var unitPriceCents: Int64?
        var lineTotalCents: Int64
        var category: String
        var isLuxury: Bool?
        var receipt: Receipt?

        init() {
            id = UUID()
            name = "Milk"
            quantity = 1
            unitPriceCents = 399
            lineTotalCents = 399
            category = "Groceries"
            isLuxury = false
        }
    }
}

@MainActor
final class ReceiptMigrationTests: XCTestCase {
    func testExistingReceiptMigratesWithoutLosingItems() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("migration.store")
        var originalID: UUID?
        do {
            let schema = Schema(versionedSchema: LegacyReceiptSchema.self)
            let legacy = try ModelContainer(for: schema, configurations: ModelConfiguration(url: url))
            let receipt = LegacyReceiptSchema.Receipt()
            receipt.items = [LegacyReceiptSchema.ReceiptItem()]
            originalID = receipt.id
            legacy.mainContext.insert(receipt)
            try legacy.mainContext.save()
        }
        let current = try ModelContainer(for: Receipt.self, ReceiptItem.self, configurations: ModelConfiguration(url: url))
        let receipt = try XCTUnwrap(current.mainContext.fetch(FetchDescriptor<Receipt>()).first)
        XCTAssertEqual(receipt.id, originalID)
        XCTAssertEqual(receipt.merchantName, "Existing Grocery")
        XCTAssertEqual(receipt.totalCents, 399)
        XCTAssertEqual(receipt.items.count, 1)
        XCTAssertEqual(receipt.items[0].name, "Milk")
        XCTAssertNil(receipt.subtotalCents)
        XCTAssertNil(receipt.taxCents)
        XCTAssertNil(receipt.items[0].quantityUnit)
    }
}
