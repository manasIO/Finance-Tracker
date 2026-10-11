import FoundationModels

@available(iOS 26.0, *)
@Generable
struct ReceiptExtraction {
    @Guide(description: "Quote the exact receipt text identifying the issuing business: header name, retailer website, or explicit store mention in the footer. Ignore product brands and third-party payment or survey services. nil only when no supporting text exists.")
    var merchantEvidence: String?

    @Guide(description: "Business issuing this receipt, supported by merchantEvidence. Search the full receipt, including the footer. Preserve the business name; nil only when evidence is absent or conflicting.")
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

    @Guide(description: "Printed amount charged for this item, usually the price on the same row as its name. A single item price is the line total even when quantity and unit price are absent. Use decimal dollars such as 3.99, without currency symbols, tax markers, or units. nil only when no price can be reliably associated with the item.")
    var lineTotal: String?

    @Guide(description: "Explicit purchased quantity and unit, such as 0.39 lb; nil if absent. Package size is not purchased quantity.")
    var quantity: String?

    @Guide(description: "Explicit unit price in decimal dollars; nil if absent.")
    var unitPrice: String?

}
