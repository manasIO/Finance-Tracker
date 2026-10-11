import Foundation

enum SplitExpenseSource: Identifiable {
    case purchase(Receipt)
    case bill(RecurringPayment)

    var id: String {
        switch self {
        case .purchase(let receipt): "purchase:\(receipt.id)"
        case .bill(let payment): "bill:\(payment.occurrenceID)"
        }
    }
    var name: String {
        switch self {
        case .purchase(let receipt): receipt.merchantName
        case .bill(let payment): payment.name
        }
    }
    var amount: Decimal {
        switch self {
        case .purchase(let receipt): Decimal(receipt.totalCents) / 100
        case .bill(let payment): Decimal(payment.amountCents) / 100
        }
    }
    var currency: String {
        switch self {
        case .purchase(let receipt): receipt.currencyCode
        case .bill(let payment): payment.currencyCode
        }
    }
    var date: Date {
        switch self {
        case .purchase(let receipt): receipt.purchaseDate
        case .bill(let payment): payment.paidDate
        }
    }
    var pending: Bool {
        switch self {
        case .purchase(let receipt): receipt.needsSplit
        case .bill(let payment): payment.needsSplit
        }
    }
    var resolvedAt: Date? {
        switch self {
        case .purchase(let receipt): receipt.splitResolvedAt
        case .bill(let payment): payment.splitResolvedAt
        }
    }
}
