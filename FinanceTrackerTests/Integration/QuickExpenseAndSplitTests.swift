import XCTest
import SwiftData
@testable import FinanceTracker

@MainActor
final class QuickExpenseAndSplitTests: XCTestCase {
    func testAmountOnlyExpenseIsSavedWithoutStoreOrItemEntry() throws {
        let container = try LocalStorage.container(inMemory: true)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let expense = try QuickExpenseStore.save(amount: "12.50", date: date, in: container.mainContext)
        XCTAssertTrue(expense.isQuickExpense)
        XCTAssertEqual(expense.merchantName, "Quick expense")
        XCTAssertEqual(expense.totalCents, 1250)
        XCTAssertEqual(expense.purchaseDate, date)
        XCTAssertEqual(expense.items.first?.category, "Uncategorized")
        XCTAssertTrue(expense.items.first?.receipt === expense)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Receipt>()), 1)
    }

    func testAnonymousEqualAmountPurchasesDoNotCauseFalseDuplicateWarning() throws {
        let container = try LocalStorage.container(inMemory: true)
        let date = Date()
        _ = try QuickExpenseStore.save(amount: "12", date: date, in: container.mainContext)
        _ = try QuickExpenseStore.save(amount: "12", date: date, in: container.mainContext)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Receipt>()), 2)
    }

    func testNamedDuplicateRequiresExplicitOverride() throws {
        let container = try LocalStorage.container(inMemory: true)
        let context = container.mainContext
        let date = Date()
        _ = try QuickExpenseStore.save(amount: "12", description: "Cafe", date: date, in: context)
        XCTAssertThrowsError(try QuickExpenseStore.save(amount: "12", description: "  CAFE ", date: date, in: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Receipt>()), 1)
        _ = try QuickExpenseStore.save(amount: "12", description: "Cafe", date: date, allowDuplicate: true, in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Receipt>()), 2)
    }

    func testInvalidQuickExpenseNeverCreatesPartialData() throws {
        let container = try LocalStorage.container(inMemory: true)
        for amount in ["", "0", "-12", "invalid", "99999999999999999999999999999"] {
            XCTAssertThrowsError(try QuickExpenseStore.save(amount: amount, in: container.mainContext))
        }
        XCTAssertThrowsError(try QuickExpenseStore.save(amount: "12", category: "Invalid category", in: container.mainContext))
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Receipt>()), 0)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<ReceiptItem>()), 0)
    }

    func testQuickExpenseUpdatesSpendingCategoryAndBudgetWhileSplitChangesLeaveCostIntact() throws {
        let container = try LocalStorage.container(inMemory: true)
        let context = container.mainContext
        let now = Date()
        let expense = try QuickExpenseStore.save(amount: "12", description: "Lunch", category: "Dining",
                                                 date: now, needsSplit: true, in: context)
        let summary = SpendingSummary(entries: [.init(date: expense.purchaseDate, totalCents: expense.totalCents, currencyCode: "USD")], now: now)
        XCTAssertEqual(summary.currentMonth.total, 12)
        XCTAssertEqual(RecurringBudgetStatus(limitCents: 10000, spent: summary.currentMonth.total, recurring: []).remaining, 88)
        let categories = CategorySummary(entries: [
            .init(date: now, currency: "USD", totalCents: expense.totalCents,
                  items: expense.items.map { .init(category: $0.category, isLuxury: $0.isLuxury, cents: $0.lineTotalCents) })
        ], now: now, currency: "USD")
        XCTAssertEqual(categories.categories.first?.name, "Dining")
        XCTAssertEqual(categories.categories.first?.total, 12)
        let source = SplitExpenseSource.purchase(expense)
        XCTAssertTrue(source.pending)
        try SplitStore.setPending(false, for: source, at: now, in: context)
        XCTAssertFalse(source.pending)
        XCTAssertEqual(source.resolvedAt, now)
        XCTAssertEqual(expense.totalCents, 1200)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Receipt>()), 1)
        try SplitStore.setPending(true, for: source, in: context)
        XCTAssertTrue(source.pending)
        XCTAssertNil(source.resolvedAt)
    }

    func testImportedReceiptAndPaidBillCanBeFlaggedAndResolved() throws {
        let container = try LocalStorage.container(inMemory: true)
        let context = container.mainContext
        var draft = ReceiptFixtures.draft()
        draft.needsSplit = true
        let receipt = try ReceiptImportStore.save(draft, in: context)
        XCTAssertTrue(receipt.needsSplit)
        try RecurringStore.save(name: "Rent", amount: "1000", currency: "USD", frequency: "monthly",
                                firstDue: .now, category: "Household", needsSplit: true, in: context)
        let expenses = try context.fetch(FetchDescriptor<RecurringExpense>())
        let occurrence = try XCTUnwrap(RecurringSchedule.occurrences(expenses: expenses, payments: [], month: .now).first)
        try RecurringStore.markPaid(occurrence, in: context)
        let payment = try XCTUnwrap(context.fetch(FetchDescriptor<RecurringPayment>()).first)
        XCTAssertTrue(payment.needsSplit)
        try SplitStore.setPending(false, for: .bill(payment), in: context)
        XCTAssertFalse(payment.needsSplit)
        XCTAssertNotNil(payment.splitResolvedAt)
        XCTAssertEqual(payment.amountCents, 100000)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RecurringPayment>()), 1)
    }

    func testQuickExpenseAndResolvedSplitSurviveReopening() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("store")
        let now = Date()
        do {
            let store = try ModelContainer(for: Receipt.self, ReceiptItem.self,
                                           configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
            let expense = try QuickExpenseStore.save(amount: "25", description: "Taxi", category: "Transport",
                                                     needsSplit: true, in: store.mainContext)
            try SplitStore.setPending(false, for: .purchase(expense), at: now, in: store.mainContext)
        }
        let reopened = try ModelContainer(for: Receipt.self, ReceiptItem.self,
                                          configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
        let saved = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Receipt>()).first)
        XCTAssertTrue(saved.isQuickExpense)
        XCTAssertEqual(saved.totalCents, 2500)
        XCTAssertEqual(saved.items.first?.category, "Transport")
        XCTAssertFalse(saved.needsSplit)
        XCTAssertEqual(saved.splitResolvedAt, now)
    }
}
