import XCTest
import SwiftData
@testable import FinanceTracker

@MainActor
final class FinanceFeaturesPersistenceTests: XCTestCase {
    private func container(url: URL? = nil) throws -> ModelContainer {
        let config = url.map { ModelConfiguration(url: $0) } ?? ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Receipt.self, ReceiptItem.self, MonthlyBudget.self, UserProfile.self,
                                  configurations: config)
    }

    func testDuplicateBlockedWithoutPartialInsertAndCanBeOverridden() throws {
        let store = try container()
        let context = store.mainContext
        let draft = ReceiptFixtures.draft()
        _ = try ReceiptImportStore.save(draft, in: context)
        XCTAssertThrowsError(try ReceiptImportStore.save(draft, in: context)) { error in
            XCTAssertTrue(error is ReceiptStore.SaveError)
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Receipt>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ReceiptItem>()), 2)
        _ = try ReceiptImportStore.save(draft, in: context, allowDuplicate: true)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Receipt>()), 2)
    }

    func testDuplicateMatchesNormalizedMerchantAndCalendarDay() {
        let first = Receipt(merchantName: "  Café & Market ", purchaseDate: ReceiptFixtures.draft().purchaseDate, totalCents: 500)
        let second = Receipt(merchantName: "CAFE MARKET", purchaseDate: first.purchaseDate.addingTimeInterval(1), totalCents: 500)
        XCTAssertNotNil(ReceiptStore.duplicate(of: second, among: [first]))
        second.currencyCode = "EUR"
        XCTAssertNil(ReceiptStore.duplicate(of: second, among: [first]))
        second.currencyCode = "USD"
        second.totalCents = 501
        XCTAssertNil(ReceiptStore.duplicate(of: second, among: [first]))
        second.totalCents = 500
        second.purchaseDate = first.purchaseDate.addingTimeInterval(86400)
        XCTAssertNil(ReceiptStore.duplicate(of: second, among: [first]))
        XCTAssertNil(ReceiptStore.duplicate(of: first, among: [first]))
    }

    func testBudgetUpdatesSameMonthSeparatesCurrenciesAndMonths() throws {
        let store = try container()
        let context = store.mainContext
        let month = ReceiptFixtures.draft().purchaseDate
        try BudgetStore.save(amount: "100.00", month: month, currency: "USD", in: context)
        try BudgetStore.save(amount: "200.00", month: month.addingTimeInterval(60), currency: "USD", in: context)
        try BudgetStore.save(amount: "300.00", month: month, currency: "EUR", in: context)
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: month)!
        try BudgetStore.save(amount: "400.00", month: nextMonth, currency: "USD", in: context)
        let budgets = try context.fetch(FetchDescriptor<MonthlyBudget>())
        XCTAssertEqual(budgets.count, 3)
        XCTAssertTrue(budgets.contains { $0.amountCents == 20000 && $0.currencyCode == "USD" })
        XCTAssertThrowsError(try BudgetStore.save(amount: "0", month: month, currency: "USD", in: context))
        XCTAssertThrowsError(try BudgetStore.save(amount: "invalid", month: month, currency: "USD", in: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MonthlyBudget>()), 3)
    }

    func testUpgradePreservesReceiptsAndNewModelsSurviveReopening() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("store")
        let date = ReceiptFixtures.draft().purchaseDate
        do {
            let original = try ModelContainer(for: Receipt.self, ReceiptItem.self, configurations: ModelConfiguration(url: url))
            _ = try ReceiptImportStore.save(ReceiptFixtures.draft(), in: original.mainContext)
        }
        do {
            let upgraded = try container(url: url)
            XCTAssertEqual(try upgraded.mainContext.fetchCount(FetchDescriptor<Receipt>()), 1)
            try BudgetStore.save(amount: "500.00", month: date, currency: "USD", in: upgraded.mainContext)
            let profile = UserProfile(name: "Alex", email: "alex@example.com", phone: "123")
            XCTAssertEqual(profile.avatarSymbol, ProfileAvatar.cat.rawValue)
            profile.avatarSymbol = ProfileAvatar.fish.rawValue
            upgraded.mainContext.insert(profile)
            try upgraded.mainContext.save()
        }
        let reopened = try container(url: url)
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<MonthlyBudget>()).first?.amountCents, 50000)
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<UserProfile>()).first?.name, "Alex")
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<UserProfile>()).first?.avatarSymbol, ProfileAvatar.fish.rawValue)
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<UserProfile>()).first?.email, "alex@example.com")
        XCTAssertEqual(try reopened.mainContext.fetchCount(FetchDescriptor<ReceiptItem>()), 2)
    }
}
