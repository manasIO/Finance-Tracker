import Foundation
import SwiftUI
import SwiftData

struct ReceiptDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDeletion = false
    @State private var deletionError: String?
    let receipt: Receipt

    var body: some View {
        List {
            Section("Purchase") {
                LabeledContent(receipt.isQuickExpense ? "Description" : "Store", value: receipt.merchantName)
                LabeledContent("Date") {
                    Text(receipt.purchaseDate, format: .dateTime.month().day().year())
                }
                if let subtotal = receipt.subtotalCents {
                    LabeledContent("Subtotal") {
                        Text(dollars(subtotal), format: .currency(code: receipt.currencyCode))
                    }
                }
                if let tax = receipt.taxCents {
                    LabeledContent("Tax") {
                        Text(dollars(tax), format: .currency(code: receipt.currencyCode))
                    }
                }

                LabeledContent("Total") {
                    Text(
                        dollars(receipt.totalCents),
                        format: .currency(code: receipt.currencyCode)
                    )
                }
            }

            Section {
                Toggle("Needs splitting", isOn: Binding(
                    get: { receipt.needsSplit },
                    set: { value in
                        do { try SplitStore.setPending(value, for: .purchase(receipt), in: modelContext) }
                        catch { deletionError = error.localizedDescription }
                    }
                ))
                NavigationLink("View split history") { SplitExpensesView() }
            }

            if receipt.isQuickExpense, let item = receipt.items.first {
                Section("Category") {
                    Picker("Category", selection: Binding(
                        get: { item.category },
                        set: { value in
                            item.category = value
                            do { try modelContext.save() }
                            catch { modelContext.rollback(); deletionError = error.localizedDescription }
                        }
                    )) {
                        ForEach(ItemCategory.allCases, id: \.self) { Text($0.rawValue).tag($0.rawValue) }
                    }
                }
            } else {
                Section("Items") {
                    ForEach(
                        receipt.items.sorted { $0.name < $1.name }
                    ) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.headline)

                                Text(
                                    "Quantity: \(item.quantity.description)\(item.quantityUnit.map { " " + $0 } ?? "")"
                                )

                                Text(
                                    "\(item.category) • \(classification(for: item))"
                                )
                                if item.category == "Groceries" {
                                    Picker("Food spending", selection: Binding(
                                        get: { item.foodChoice ?? FoodChoice.unclassified.rawValue },
                                        set: { value in
                                            item.foodChoice = value
                                            do { try modelContext.save() }
                                            catch { modelContext.rollback(); deletionError = error.localizedDescription }
                                        }
                                    )) {
                                        ForEach(FoodChoice.allCases, id: \.self) { Text($0.label).tag($0.rawValue) }
                                    }
                                }
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
            Section {
                Button(role: .destructive) { confirmingDeletion = true } label: {
                    Label(receipt.isQuickExpense ? "Delete expense" : "Delete receipt", systemImage: "trash")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("AppBackground"))
        .navigationTitle(receipt.isQuickExpense ? "Expense" : "Receipt")
        .confirmationDialog(receipt.isQuickExpense ? "Delete this expense?" : "Delete this receipt?", isPresented: $confirmingDeletion, titleVisibility: .visible) {
            Button(receipt.isQuickExpense ? "Delete expense" : "Delete receipt", role: .destructive) { deleteReceipt() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the purchase and updates your spending totals.")
        }
        .alert("Couldn't save changes", isPresented: Binding(
            get: { deletionError != nil },
            set: { if !$0 { deletionError = nil } }
        )) {
            Button("OK", role: .cancel) { deletionError = nil }
        } message: { Text(deletionError ?? "") }
    }

    private func deleteReceipt() {
        modelContext.delete(receipt)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            deletionError = error.localizedDescription
        }
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
