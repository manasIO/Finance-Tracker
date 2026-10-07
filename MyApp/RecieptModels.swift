import Foundation
import SwiftData

@Model
final class Receipt {
    var id: UUID
    var merchantName: String
    var purchaseData: Date
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
        purchareDate: Date = .now,
        currencyCode: String = "USD",
        totalCents: Int64 = 0
    ){
        self.id = UUID()
        self.merchantName = merchantName
        self.purchaseData = purchareDate
        self.currencyCode = currencyCode
        self.totalCents = totalCents
    }
}

@Model
final class ReceiptItem{
    var id: UUID
    var name: String
    
    // Support fractional quantities such as 1.5lb of apples
    var quantity: Decimal
    
    // Optional because a receipt may only show the line total
    var unitPriceCents: Int64?
    var lineTotalCents: Int64
    
    var category: String
    
    // nil = unclassifies, false = need, true = want
    var isLuxury: Bool?
    
    var receipt: Receipt?
    
    init(
        name: String,
        quantity: Decimal = 1,
        unitPriceCents: Int64? = nil,
        lineTotalCents: Int64,
        category: String = "Uncategorized",
        isLuxury: Bool? = nil
    ){
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.unitPriceCents = unitPriceCents
        self.lineTotalCents = lineTotalCents
        self.category = category
        self.isLuxury = isLuxury
    }
}
