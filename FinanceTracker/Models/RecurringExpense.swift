import Foundation
import SwiftData

@Model
final class RecurringExpense {
    var needsSplit: Bool = false
    var id: UUID
    var name: String
    var amountCents: Int64
    var currencyCode: String
    var frequency: String
    var firstDueDate: Date
    var endDate: Date?
    var category: String

    init(name: String, amountCents: Int64, currencyCode: String = "USD", frequency: String = "monthly",
         firstDueDate: Date = .now, category: String = "Household") {
        id = UUID()
        self.name = name
        self.amountCents = amountCents
        self.currencyCode = currencyCode
        self.frequency = frequency
        self.firstDueDate = firstDueDate
        self.category = category
    }
}

@Model
final class RecurringPayment {
    var needsSplit: Bool = false
    var splitResolvedAt: Date? = nil
    var occurrenceID: String
    var expenseID: UUID
    var name: String
    var amountCents: Int64
    var currencyCode: String
    var category: String
    var dueDate: Date
    var paidDate: Date

    // Snapshot paid costs so editing or removing a schedule preserves history.
    init(occurrence: RecurringSchedule.Occurrence, paidDate: Date = .now) {
        needsSplit = occurrence.needsSplit
        occurrenceID = occurrence.id
        expenseID = occurrence.expenseID
        name = occurrence.name
        amountCents = occurrence.amountCents
        currencyCode = occurrence.currencyCode
        category = occurrence.category
        dueDate = occurrence.dueDate
        self.paidDate = paidDate
    }
}
