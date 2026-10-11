import Foundation
import SwiftUI

struct ReceiptDetailView: View {
    let receipt: Receipt

    var body: some View {
        List {
            Section("Purchase") {
                LabeledContent("Store", value: receipt.merchantName)

                LabeledContent("Total") {
                    Text(
                        dollars(receipt.totalCents),
                        format: .currency(code: receipt.currencyCode)
                    )
                }
            }

            Section("Items") {
                ForEach(
                    receipt.items.sorted { $0.name < $1.name }
                ) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.headline)

                            Text(
                                "Quantity: \(item.quantity.description)"
                            )

                            Text(
                                "\(item.category) • \(classification(for: item))"
                            )
                        }
                        .font(.caption)

                        Spacer()

                        Text(
                            dollars(item.lineTotalCents),
                            format: .currency(code: receipt.currencyCode)
                        )
                    }
                }
            }
        }
        .navigationTitle("Receipt")
    }

    private func classification(for item: ReceiptItem) -> String {
        guard let isLuxury = item.isLuxury else {
            return "Unclassified"
        }

        return isLuxury ? "Want" : "Need"
    }
}


// Convert stored cents to dollars only for display.
private func dollars(_ cents: Int64) -> Decimal {
    Decimal(cents) / Decimal(100)
}
