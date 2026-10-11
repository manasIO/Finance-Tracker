import Foundation

enum RecurringSchedule {
    struct Occurrence: Identifiable {
        let id: String
        let expenseID: UUID
        let name: String
        let amountCents: Int64
        let currencyCode: String
        let category: String
        let dueDate: Date
        let isPaid: Bool
        var needsSplit = false
        var amount: Decimal { Decimal(amountCents) / 100 }
    }

    static func occurrences(expenses: [RecurringExpense], payments: [RecurringPayment], month: Date,
                            calendar: Calendar = .current) -> [Occurrence] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let days = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let paid = Dictionary(payments.map { ($0.occurrenceID, $0) }, uniquingKeysWith: { first, _ in first })
        var result: [String: Occurrence] = [:]
        for expense in expenses where expense.amountCents > 0 {
            let first = calendar.startOfDay(for: expense.firstDueDate)
            let end = expense.endDate.map { calendar.startOfDay(for: $0) }
            let dueDay = min(calendar.component(.day, from: first), days.count)
            for day in days where expense.frequency == "daily" || (expense.frequency == "monthly" && day == dueDay) {
                guard let date = calendar.date(byAdding: .day, value: day - 1, to: interval.start),
                      date >= first, end == nil || date <= end! else { continue }
                let components = calendar.dateComponents([.year, .month, .day], from: date)
                let key = "\(expense.id.uuidString):\(components.year!)-\(components.month!)-\(components.day!)"
                let monthlyPayment = expense.frequency == "monthly" ? payments.first {
                    $0.expenseID == expense.id && interval.contains($0.dueDate)
                } : nil
                if let payment = paid[key] ?? monthlyPayment {
                    result[payment.occurrenceID] = occurrence(payment)
                } else {
                    result[key] = Occurrence(id: key, expenseID: expense.id, name: expense.name,
                                             amountCents: expense.amountCents, currencyCode: expense.currencyCode,
                                             category: expense.category, dueDate: date, isPaid: false, needsSplit: expense.needsSplit)
                }
            }
        }
        // Paid records remain visible after a schedule is removed or changed.
        for payment in payments where interval.contains(payment.dueDate) {
            result[payment.occurrenceID] = occurrence(payment)
        }
        return result.values.sorted { $0.dueDate == $1.dueDate ? $0.name < $1.name : $0.dueDate < $1.dueDate }
    }

    private static func occurrence(_ payment: RecurringPayment) -> Occurrence {
        Occurrence(id: payment.occurrenceID, expenseID: payment.expenseID, name: payment.name,
                   amountCents: payment.amountCents, currencyCode: payment.currencyCode,
                   category: payment.category, dueDate: payment.dueDate, isPaid: true, needsSplit: payment.needsSplit)
    }
}
