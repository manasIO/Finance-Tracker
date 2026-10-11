import XCTest
import SwiftData
@testable import FinanceTracker

@MainActor
final class DashboardPersistenceTests: XCTestCase {
    func testDashboardReflectsImportedReceiptEditsAndDeletion() throws {
        let container = try ModelContainer(for: Receipt.self, ReceiptItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 10))!
        var draft = ReceiptFixtures.draft()
        draft.purchaseDate = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        let receipt = try ReceiptImportStore.save(draft, in: container.mainContext)

        func summary() throws -> SpendingSummary {
            let receipts = try container.mainContext.fetch(FetchDescriptor<Receipt>())
            return SpendingSummary(entries: receipts.map { .init(date: $0.purchaseDate, totalCents: $0.totalCents, currencyCode: $0.currencyCode) }, now: now, calendar: calendar)
        }
        // Use the paid receipt total, not line items plus tax a second time.
        XCTAssertEqual(try summary().currentMonth.totalCents, 727)
        XCTAssertEqual(try summary().currentMonth.receiptCount, 1)
        receipt.purchaseDate = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        try container.mainContext.save()
        XCTAssertEqual(try summary().currentMonth.totalCents, 0)
        XCTAssertEqual(try summary().previousMonth.totalCents, 727)
        container.mainContext.delete(receipt)
        try container.mainContext.save()
        XCTAssertTrue(try summary().history.isEmpty)
    }
}
