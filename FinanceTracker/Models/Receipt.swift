import Foundation
import SwiftData

@Model
final class Receipt {
    var id: UUID
    var merchantName: String
    var purchaseDate: Date
    var currencyCode: String

    // Money is stored in cents: $12.50 = 1250
    var totalCents: Int64

    @Relationship(
            deleteRule: .cascade,
            inverse: \ReceiptItem.receipt
    )

    var items: [ReceiptItem] = []

    init(
        merchantName: String,
        purchaseDate: Date = .now,
        currencyCode: String = "USD",
        totalCents: Int64 = 0
    ){
        self.id = UUID()
        self.merchantName = merchantName
        self.purchaseDate = purchaseDate
        self.currencyCode = currencyCode
        self.totalCents = totalCents
    }
}
