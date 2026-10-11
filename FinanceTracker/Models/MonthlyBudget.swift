import Foundation
import SwiftData

@Model
final class MonthlyBudget {
    var month: Date
    var currencyCode: String
    var amountCents: Int64

    init(month: Date, currencyCode: String, amountCents: Int64) {
        self.month = Calendar.current.dateInterval(of: .month, for: month)!.start
        self.currencyCode = currencyCode
        self.amountCents = amountCents
    }
}
