import Foundation
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Receipt.purchaseDate, order: .reverse)
    private var receipts: [Receipt]

    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        addSampleReceipt()
                    } label: {
                        Label("Add sample receipt", systemImage: "plus")
                    }
                }

                Section("Saved receipts") {
                    if receipts.isEmpty {
                        Text("No receipts yet. Add a sample to get started.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(receipts) { receipt in
                        NavigationLink {
                            ReceiptDetailView(receipt: receipt)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(receipt.merchantName)
                                        .font(.headline)

                                    Text(
                                        receipt.purchaseDate,
                                        format: .dateTime.month().day().year()
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(
                                    dollars(receipt.totalCents),
                                    format: .currency(
                                        code: receipt.currencyCode
                                    )
                                )
                            }
                        }
                    }
                    .onDelete(perform: deleteReceipts)
                }
            }
            .navigationTitle("Finance Tracker")
            .alert("Couldn't save changes", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func addSampleReceipt() {
        let receipt = Receipt(
            merchantName: "Sample Grocery Store",
            totalCents: 1247
        )

        let milk = ReceiptItem(
            name: "Milk",
            unitPriceCents: 399,
            lineTotalCents: 399,
            category: "Groceries",
            isLuxury: false
        )

        let apples = ReceiptItem(
            name: "Apples",
            quantity: 2,
            unitPriceCents: 149,
            lineTotalCents: 298,
            category: "Groceries",
            isLuxury: false
        )

        let cookies = ReceiptItem(
            name: "Cookies",
            unitPriceCents: 550,
            lineTotalCents: 550,
            category: "Groceries",
            isLuxury: true
        )

        receipt.items = [milk, apples, cookies]

        modelContext.insert(receipt)
        saveChanges()
    }

    private func deleteReceipts(at offsets: IndexSet) {
        let receiptsToDelete = offsets.map { receipts[$0] }

        for receipt in receiptsToDelete {
            modelContext.delete(receipt)
        }

        saveChanges()
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

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

#Preview {
    ContentView()
        .modelContainer(
            for: [Receipt.self, ReceiptItem.self],
            inMemory: true
        )
}
