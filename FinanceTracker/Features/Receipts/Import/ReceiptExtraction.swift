import FoundationModels

@available(iOS 26.0, *)
@Generable
struct ReceiptExtraction {
    @Guide(description: "Merchant name from the receipt; nil if unknown.")
    var merchantName: String?

    var items: [ExtractedReceiptItem]

    @Guide(description: "Subtotal in decimal dollars without currency symbols; nil if missing.")
    var subtotal: String?

    @Guide(description: "Each separately printed tax amount in decimal dollars.")
    var taxAmounts: [String]

    @Guide(description: "Final purchase total in decimal dollars; nil if unclear.")
    var total: String?

    @Guide(description: "Missing fields, ambiguous price assignments, or inconsistent totals.")
    var warnings: [String]
}

@available(iOS 26.0, *)
@Generable
struct ExtractedReceiptItem {
    @Guide(description: "Item description as printed. Do not invent a product or brand.")
    var name: String

    @Guide(description: "Explicit purchased quantity and unit, such as 0.39 lb; nil if absent. Package size is not purchased quantity.")
    var quantity: String?

    @Guide(description: "Explicit unit price in decimal dollars; nil if absent.")
    var unitPrice: String?

    @Guide(description: "Extended item line total in decimal dollars; nil if uncertain.")
    var lineTotal: String?
}
