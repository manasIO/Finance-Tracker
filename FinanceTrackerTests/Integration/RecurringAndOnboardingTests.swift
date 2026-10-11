import XCTest
import SwiftData
@testable import FinanceTracker

@MainActor
final class RecurringAndOnboardingTests: XCTestCase {
    func testBillPaidOnlyOnceAndUnpaidRestoresReservation() throws {
        let container = try LocalStorage.container(inMemory: true)
        let context = container.mainContext
        try RecurringStore.save(name: "Rent", amount: "1000.00", currency: "USD", frequency: "monthly",
                                firstDue: .now, category: "Household", in: context)
        let bills = try context.fetch(FetchDescriptor<RecurringExpense>())
        let occurrence = try XCTUnwrap(RecurringSchedule.occurrences(expenses: bills, payments: [], month: .now).first)
        try RecurringStore.markPaid(occurrence, in: context)
        try RecurringStore.markPaid(occurrence, in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RecurringPayment>()), 1)
        let paid = try context.fetch(FetchDescriptor<RecurringPayment>())
        XCTAssertTrue(RecurringSchedule.occurrences(expenses: bills, payments: paid, month: .now).first?.isPaid == true)
        try RecurringStore.markUnpaid(occurrence, in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RecurringPayment>()), 0)
        XCTAssertFalse(RecurringSchedule.occurrences(expenses: bills, payments: [], month: .now).first?.isPaid ?? true)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Receipt>()), 0)
    }

    func testRemovingSchedulePreservesPaidHistory() throws {
        let container = try LocalStorage.container(inMemory: true)
        let context = container.mainContext
        let bill = RecurringExpense(name: "Wi-Fi", amountCents: 5000)
        context.insert(bill)
        try context.save()
        let occurrence = try XCTUnwrap(RecurringSchedule.occurrences(expenses: [bill], payments: [], month: .now).first)
        try RecurringStore.markPaid(occurrence, in: context)
        try RecurringStore.remove(bill, in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RecurringExpense>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RecurringPayment>()), 1)
    }

    func testInvalidBillCreatesNoPartialRecord() throws {
        let container = try LocalStorage.container(inMemory: true)
        XCTAssertThrowsError(try RecurringStore.save(name: "", amount: "0", currency: "USD", frequency: "monthly",
                                                   firstDue: .now, category: "Other", in: container.mainContext))
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<RecurringExpense>()), 0)
    }

    func testOnboardingSupportsEmptyOptionalFieldsAndUpdatesExistingProfile() throws {
        let container = try LocalStorage.container(inMemory: true)
        let context = container.mainContext
        try ProfileStore.save(name: "", email: "", phone: "", in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserProfile>()), 0)
        try ProfileStore.save(name: "  Alex  ", email: "", phone: "", in: context)
        let profile = try XCTUnwrap(context.fetch(FetchDescriptor<UserProfile>()).first)
        XCTAssertEqual(profile.name, "Alex")
        XCTAssertEqual(profile.email, "")
        profile.avatarSymbol = ProfileAvatar.fish.rawValue
        try ProfileStore.save(name: "Alex Doe", email: "alex@example.com", phone: "", in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserProfile>()), 1)
        XCTAssertEqual(profile.avatarSymbol, ProfileAvatar.fish.rawValue)
    }

    func testExistingStoreUpgradeAndRecurringPersistence() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("store")
        do {
            let old = try ModelContainer(for: Receipt.self, ReceiptItem.self, MonthlyBudget.self, UserProfile.self,
                                         configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
            _ = try ReceiptImportStore.save(ReceiptFixtures.draft(), in: old.mainContext)
        }
        do {
            let upgraded = try ModelContainer(for: Receipt.self, ReceiptItem.self, MonthlyBudget.self, UserProfile.self,
                                              RecurringExpense.self, RecurringPayment.self,
                                              configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
            try RecurringStore.save(name: "Rent", amount: "1000", currency: "USD", frequency: "monthly",
                                    firstDue: .now, category: "Household", in: upgraded.mainContext)
        }
        let reopened = try ModelContainer(for: Receipt.self, ReceiptItem.self, MonthlyBudget.self, UserProfile.self,
                                          RecurringExpense.self, RecurringPayment.self,
                                          configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
        XCTAssertEqual(try reopened.mainContext.fetchCount(FetchDescriptor<Receipt>()), 1)
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<RecurringExpense>()).first?.amountCents, 100000)
    }
}
