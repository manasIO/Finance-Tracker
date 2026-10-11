import XCTest
@testable import FinanceTracker

@MainActor
final class CategorySummaryTests: XCTestCase {
    func testGiftPurchasesRemainInTheirOwnCategory() {
        let now = Date()
        let summary = CategorySummary(entries: [
            .init(date: now, currency: "USD", totalCents: 2500, items: [
                .init(category: "Gifts", isLuxury: true, cents: 2500)])
        ], now: now, currency: "USD")
        XCTAssertEqual(summary.categories.first?.name, "Gifts")
        XCTAssertEqual(summary.categories.first?.total, 25)
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private func date(_ day: Int, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
    }

    func testCategoriesReconcileTaxMissingItemsAndDiscounts() {
        let summary = CategorySummary(entries: [
            .init(date: date(1), currency: "USD", totalCents: 1100, items: [
                .init(category: "Groceries", isLuxury: false, cents: 600),
                .init(category: "Entertainment", isLuxury: true, cents: 400)]),
            .init(date: date(2), currency: "USD", totalCents: 300, items: []),
            .init(date: date(3), currency: "USD", totalCents: 150, items: [
                .init(category: "Unknown category", isLuxury: nil, cents: 200)])
        ], now: date(11), currency: "USD", calendar: calendar)
        XCTAssertEqual(summary.categories.reduce(Decimal(0)) { $0 + $1.total } + summary.adjustment, Decimal(string: "15.50"))
        XCTAssertEqual(summary.adjustment, Decimal(string: "3.50"))
        XCTAssertEqual(summary.needs, 6)
        XCTAssertEqual(summary.wants, 4)
        XCTAssertEqual(summary.unclassified, 2)
        XCTAssertEqual(summary.categories.last?.name, "Uncategorized")
    }

    func testExcludesOtherCurrencyPriorMonthAndFutureDays() {
        let entries: [CategorySummary.Entry] = [
            .init(date: date(10), currency: "USD", totalCents: 100, items: []),
            .init(date: date(11), currency: "USD", totalCents: 200, items: []),
            .init(date: date(12), currency: "USD", totalCents: 400, items: []),
            .init(date: date(1, month: 9), currency: "USD", totalCents: 800, items: []),
            .init(date: date(1), currency: "EUR", totalCents: 1600, items: [])]
        let summary = CategorySummary(entries: entries, now: date(11), currency: "USD", calendar: calendar)
        XCTAssertEqual(summary.adjustment, 3)
    }

    func testAggregationDoesNotOverflowIntegerCents() {
        let entry = CategorySummary.Entry(date: date(1), currency: "USD", totalCents: Int64.max,
                                          items: [.init(category: "Groceries", isLuxury: false, cents: Int64.max)])
        let summary = CategorySummary(entries: [entry, entry], now: date(11), currency: "USD", calendar: calendar)
        XCTAssertEqual(summary.needs, Decimal(Int64.max) / 100 * 2)
        XCTAssertEqual(summary.adjustment, 0)
    }
}
