import XCTest
@testable import FinanceTracker

@MainActor
final class FoodSpendingSummaryTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testPercentagesUseSpendingRatherThanItemCountAndIncludeUnknown() {
        let entries: [CategorySummary.Entry] = [
            .init(date: now, currency: "USD", totalCents: 1200, items: [
                .init(category: "Groceries", isLuxury: false, cents: 600, foodChoice: "Healthier staples"),
                .init(category: "Groceries", isLuxury: true, cents: 200, foodChoice: "Treats"),
                .init(category: "Groceries", isLuxury: nil, cents: 200),
                .init(category: "Household", isLuxury: false, cents: 100, foodChoice: "Healthier staples")])]
        let summary = FoodSpendingSummary(entries: entries, now: now, currency: "USD")
        XCTAssertEqual(summary.total, 10)
        XCTAssertEqual(summary.slices[0].share, Decimal(string: "0.6"))
        XCTAssertEqual(summary.slices[1].share, Decimal(string: "0.2"))
        XCTAssertEqual(summary.slices[2].share, Decimal(string: "0.2"))
        XCTAssertEqual(summary.slices.reduce(Decimal(0)) { $0 + $1.share }, 1)
    }

    func testExcludesFutureMonthsOtherCurrenciesAndNegativeCharges() {
        let item = CategorySummary.Item(category: "Groceries", isLuxury: nil, cents: 100, foodChoice: "Treats")
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: now)!
        let entries: [CategorySummary.Entry] = [
            .init(date: nextMonth, currency: "USD", totalCents: 100, items: [item]),
            .init(date: now, currency: "EUR", totalCents: 100, items: [item]),
            .init(date: now, currency: "USD", totalCents: 0, items: [
                .init(category: "Groceries", isLuxury: nil, cents: -100, foodChoice: "Treats")])]
        let summary = FoodSpendingSummary(entries: entries, now: now, currency: "USD")
        XCTAssertEqual(summary.total, 0)
        XCTAssertTrue(summary.slices.allSatisfy { $0.share == 0 })
    }

    func testUnknownLegacyLabelsStayUnclassified() {
        let summary = FoodSpendingSummary(entries: [
            .init(date: now, currency: "USD", totalCents: 500, items: [
                .init(category: "Groceries", isLuxury: nil, cents: 500, foodChoice: "Invalid label")])
        ], now: now, currency: "USD")
        XCTAssertEqual(summary.slices[2].share, 1)
    }
}
