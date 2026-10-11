import XCTest
@testable import FinanceTracker

@MainActor
final class SpendingSummaryTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func entry(_ year: Int, _ month: Int, _ day: Int, cents: Int64, currency: String = "USD", hour: Int = 12) -> SpendingSummary.Entry {
        .init(date: date(year, month, day, hour: hour), totalCents: cents, currencyCode: currency)
    }

    func testCurrentSpendingIncludesTodayAndExcludesFutureDays() {
        let summary = SpendingSummary(entries: [
            entry(2026, 10, 1, cents: 399), entry(2026, 10, 10, cents: 201, hour: 23),
            entry(2026, 10, 11, cents: 900), entry(2026, 11, 1, cents: 500)
        ], now: date(2026, 10, 10), calendar: calendar)
        XCTAssertEqual(summary.currentMonth.totalCents, 600)
        XCTAssertEqual(summary.currentMonth.receiptCount, 2)
    }

    func testComparisonUsesSameElapsedDaysNotFullPreviousMonth() {
        let summary = SpendingSummary(entries: [
            entry(2026, 10, 1, cents: 600), entry(2026, 9, 1, cents: 200),
            entry(2026, 9, 10, cents: 200, hour: 23), entry(2026, 9, 11, cents: 800)
        ], now: date(2026, 10, 10), calendar: calendar)
        XCTAssertEqual(summary.previousMonth.totalCents, 1200)
        XCTAssertEqual(summary.previousMonthToDateCents, 400)
        XCTAssertEqual(summary.previousMonthToDateCount, 2)
        XCTAssertEqual(summary.changeCents, 200)
        XCTAssertEqual(summary.changeRatio, Decimal(string: "0.5"))
    }

    func testPreviousMonthComparisonClampsToShorterMonth() {
        let summary = SpendingSummary(entries: [
            entry(2026, 2, 28, cents: 200), entry(2026, 3, 1, cents: 300)
        ], now: date(2026, 3, 31), calendar: calendar)
        XCTAssertEqual(summary.previousMonthToDateCents, 200)
        XCTAssertEqual(summary.currentMonth.totalCents, 300)
    }

    func testLeapYearFebruaryIncludesLeapDay() {
        let summary = SpendingSummary(entries: [entry(2024, 2, 29, cents: 1299)], now: date(2024, 3, 31), calendar: calendar)
        XCTAssertEqual(summary.previousMonthToDateCents, 1299)
    }

    func testJanuaryComparisonAndHistoryCrossYearBoundary() {
        let summary = SpendingSummary(entries: [
            entry(2025, 12, 1, cents: 100), entry(2026, 1, 1, cents: 200)
        ], now: date(2026, 1, 1), calendar: calendar)
        XCTAssertEqual(summary.previousMonth.start, date(2025, 12, 1, hour: 0))
        XCTAssertEqual(summary.previousMonthToDateCents, 100)
        XCTAssertEqual(summary.history.map(\.totalCents), [200, 100])
    }

    func testEmptyMonthsAreFilledAndHistoryIsNewestFirst() {
        let summary = SpendingSummary(entries: [entry(2026, 8, 1, cents: 100)], now: date(2026, 10, 10), calendar: calendar)
        XCTAssertEqual(summary.months.count, 12)
        XCTAssertEqual(summary.history.map(\.totalCents), [0, 0, 100])
        XCTAssertEqual(summary.history.map(\.receiptCount), [0, 0, 1])
    }

    func testHistoryKeepsReceiptsOlderThanChartWindow() {
        let summary = SpendingSummary(entries: [entry(2024, 1, 1, cents: 100)], now: date(2026, 10, 10), calendar: calendar)
        XCTAssertEqual(summary.history.count, 34)
        XCTAssertEqual(summary.history.last?.totalCents, 100)
        XCTAssertEqual(summary.months.suffix(12).count, 12)
    }

    func testEmptyAndFutureOnlyDataHaveNoHistoryOrPercentage() {
        for entries in [[], [entry(2026, 11, 1, cents: 100)]] as [[SpendingSummary.Entry]] {
            let summary = SpendingSummary(entries: entries, now: date(2026, 10, 10), calendar: calendar)
            XCTAssertEqual(summary.currentMonth.totalCents, 0)
            XCTAssertNil(summary.firstRecordedMonth)
            XCTAssertTrue(summary.history.isEmpty)
            XCTAssertNil(summary.changeRatio)
        }
    }

    func testCurrenciesAreNeverAddedTogether() {
        let entries = [entry(2026, 10, 1, cents: 100), entry(2026, 10, 1, cents: 900, currency: "EUR")]
        let usd = SpendingSummary(entries: entries, now: date(2026, 10, 10), calendar: calendar)
        let eur = SpendingSummary(entries: entries, now: date(2026, 10, 10), calendar: calendar, currencyCode: "EUR")
        XCTAssertEqual(usd.currentMonth.totalCents, 100)
        XCTAssertEqual(eur.currentMonth.totalCents, 900)
    }

    func testMonthGroupingUsesLocalTimezoneAtMidnight() {
        // 03:30 UTC on October 1 is still September 30 in New York.
        let utc = ISO8601DateFormatter().date(from: "2026-10-01T03:30:00Z")!
        let summary = SpendingSummary(entries: [.init(date: utc, totalCents: 100, currencyCode: "USD")], now: date(2026, 10, 10), calendar: calendar)
        XCTAssertEqual(summary.currentMonth.totalCents, 0)
        XCTAssertEqual(summary.previousMonth.totalCents, 100)
    }

    func testCalendarDayComparisonHandlesDaylightSaving() {
        let summary = SpendingSummary(entries: [
            entry(2026, 2, 10, cents: 100, hour: 23), entry(2026, 2, 11, cents: 500),
            entry(2026, 3, 10, cents: 200)
        ], now: date(2026, 3, 10), calendar: calendar)
        XCTAssertEqual(summary.previousMonthToDateCents, 100)
        XCTAssertEqual(summary.changeRatio, 1)
    }

    func testZeroBaselineDoesNotDivideByZero() {
        let summary = SpendingSummary(entries: [entry(2026, 9, 1, cents: 0), entry(2026, 10, 1, cents: 399)], now: date(2026, 10, 10), calendar: calendar)
        XCTAssertNil(summary.changeRatio)
        XCTAssertEqual(summary.changeCents, 399)
        XCTAssertEqual(summary.previousMonthToDateCount, 1)
    }

    func testTotalsRemainExactBeyondInt64SumAndIncludeNegativeAdjustments() {
        let summary = SpendingSummary(entries: [
            entry(2026, 10, 1, cents: Int64.max), entry(2026, 10, 1, cents: Int64.max),
            entry(2026, 10, 1, cents: -1)
        ], now: date(2026, 10, 10), calendar: calendar)
        XCTAssertEqual(summary.currentMonth.totalCents, Decimal(Int64.max) * 2 - 1)
    }
}
