import Foundation
import SwiftData

@MainActor
enum RecurringStore {
    static func save(name: String, amount: String, currency: String, frequency: String, firstDue: Date,
                     category: String, needsSplit: Bool = false, existing: RecurringExpense? = nil, in context: ModelContext) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let cents = ReceiptValidator.cents(from: amount), cents > 0,
              ["monthly", "daily"].contains(frequency), ["USD", "EUR", "GBP", "CAD", "AUD", "INR"].contains(currency) else {
            throw StoreError.invalidFields
        }
        let expense = existing ?? RecurringExpense(name: name, amountCents: cents)
        expense.needsSplit = needsSplit
        expense.name = name
        expense.amountCents = cents
        expense.currencyCode = currency
        expense.frequency = frequency
        expense.firstDueDate = Calendar.current.startOfDay(for: firstDue)
        expense.category = category
        if existing == nil { context.insert(expense) }
        try persist(context)
    }

    static func markPaid(_ occurrence: RecurringSchedule.Occurrence, at date: Date = .now, in context: ModelContext) throws {
        let key = occurrence.id
        let descriptor = FetchDescriptor<RecurringPayment>(predicate: #Predicate { $0.occurrenceID == key })
        guard try context.fetchCount(descriptor) == 0 else { return }
        context.insert(RecurringPayment(occurrence: occurrence, paidDate: date))
        try persist(context)
    }

    static func markUnpaid(_ occurrence: RecurringSchedule.Occurrence, in context: ModelContext) throws {
        let key = occurrence.id
        for payment in try context.fetch(FetchDescriptor<RecurringPayment>(predicate: #Predicate { $0.occurrenceID == key })) {
            context.delete(payment)
        }
        try persist(context)
    }

    static func remove(_ expense: RecurringExpense, in context: ModelContext) throws {
        context.delete(expense)
        try persist(context)
    }

    private static func persist(_ context: ModelContext) throws {
        do { try context.save() } catch { context.rollback(); throw error }
    }

    enum StoreError: LocalizedError {
        case invalidFields
        var errorDescription: String? { "Enter a name, a positive amount, and a supported currency and frequency." }
    }
}
