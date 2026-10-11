import XCTest
@testable import FinanceTracker

@MainActor
final class RecurringScheduleTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testMonthlyDayClampsWithoutDriftingAfterFebruary() {
        let bill = RecurringExpense(name: "Rent", amountCents: 10000, firstDueDate: date(2024, 1, 31))
        let feb = RecurringSchedule.occurrences(expenses: [bill], payments: [], month: date(2024, 2, 1), calendar: calendar)
        let march = RecurringSchedule.occurrences(expenses: [bill], payments: [], month: date(2024, 3, 1), calendar: calendar)
        XCTAssertEqual(feb.first?.dueDate, date(2024, 2, 29))
        XCTAssertEqual(march.first?.dueDate, date(2024, 3, 31))
    }

    func testDailyBillsRespectStartEndAndCalendarDayCount() {
        let bill = RecurringExpense(name: "Parking", amountCents: 500, frequency: "daily", firstDueDate: date(2026, 3, 28))
        bill.endDate = date(2026, 3, 30)
        let result = RecurringSchedule.occurrences(expenses: [bill], payments: [], month: date(2026, 3, 1), calendar: calendar)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.reduce(Decimal(0)) { $0 + $1.amount }, 15)
        XCTAssertTrue(RecurringSchedule.occurrences(expenses: [bill], payments: [], month: date(2026, 2, 1), calendar: calendar).isEmpty)
    }

    func testPaidSnapshotSurvivesCostChangesAndScheduleRemoval() throws {
        let bill = RecurringExpense(name: "Wi-Fi", amountCents: 5000, firstDueDate: date(2026, 10, 1))
        let first = try XCTUnwrap(RecurringSchedule.occurrences(expenses: [bill], payments: [], month: date(2026, 10, 1), calendar: calendar).first)
        let payment = RecurringPayment(occurrence: first, paidDate: date(2026, 10, 1))
        bill.amountCents = 6000
        let current = RecurringSchedule.occurrences(expenses: [bill], payments: [payment], month: date(2026, 10, 1), calendar: calendar)
        XCTAssertEqual(current.count, 1)
        XCTAssertEqual(current.first?.amountCents, 5000)
        XCTAssertTrue(current.first?.isPaid == true)
        XCTAssertEqual(RecurringSchedule.occurrences(expenses: [], payments: [payment], month: date(2026, 10, 1), calendar: calendar).count, 1)
        XCTAssertEqual(RecurringSchedule.occurrences(expenses: [bill], payments: [payment], month: date(2026, 11, 1), calendar: calendar).first?.amountCents, 6000)
    }

    func testBudgetReservationDoesNotDoubleCountAfterPaymentOrDueDateEdit() throws {
        let bill = RecurringExpense(name: "Rent", amountCents: 100000, firstDueDate: date(2026, 10, 1))
        let unpaid = RecurringSchedule.occurrences(expenses: [bill], payments: [], month: date(2026, 10, 1), calendar: calendar)
        let before = RecurringBudgetStatus(limitCents: 150000, spent: 100, recurring: unpaid)
        XCTAssertEqual(before.remaining, 400)
        let payment = RecurringPayment(occurrence: try XCTUnwrap(unpaid.first), paidDate: date(2026, 10, 2))
        bill.firstDueDate = date(2026, 10, 5)
        let paid = RecurringSchedule.occurrences(expenses: [bill], payments: [payment], month: date(2026, 10, 1), calendar: calendar)
        XCTAssertEqual(paid.count, 1)
        let after = RecurringBudgetStatus(limitCents: 150000, spent: 1100, recurring: paid)
        XCTAssertEqual(after.reserved, 0)
        XCTAssertEqual(after.remaining, before.remaining)
    }

    func testActualSpendingIncludesPaidBillsWithoutIncreasingReceiptCount() {
        let now = date(2026, 10, 10)
        let summary = SpendingSummary(entries: [
            .init(date: date(2026, 10, 1), totalCents: 1000, currencyCode: "USD"),
            .init(date: date(2026, 10, 2), totalCents: 2000, currencyCode: "USD", isReceipt: false),
            .init(date: date(2026, 11, 1), totalCents: 9999, currencyCode: "USD", isReceipt: false),
            .init(date: date(2026, 10, 2), totalCents: 9999, currencyCode: "EUR", isReceipt: false)
        ], now: now, calendar: calendar)
        XCTAssertEqual(summary.currentMonth.total, 30)
        XCTAssertEqual(summary.currentMonth.receiptCount, 1)
    }
}
