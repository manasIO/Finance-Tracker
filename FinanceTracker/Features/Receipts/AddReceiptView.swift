import Foundation
import SwiftUI
import SwiftData

// Temporary form data—not a saved SwiftData model.
private struct ItemDraft: Identifiable {
    let id = UUID()
    var name = ""
    var amount = ""
    var category = "Groceries"
    var classification = "Unclassified"
}

struct AddReceiptView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var merchantName = ""
    @State private var purchaseDate = Date()
    @State private var items = [ItemDraft()]

    @State private var showingError = false
    @State private var errorMessage = ""

    private let categories = [
        "Groceries", "Dining", "Household",
        "Transport", "Health", "Entertainment", "Other"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Receipt") {
                    TextField("Store name", text: $merchantName)

                    DatePicker(
                        "Purchase date",
                        selection: $purchaseDate,
                        displayedComponents: .date
                    )
                }

                Section {
                    ForEach($items) { $item in
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Item name", text: $item.name)

                            TextField(
                                "Line total in USD, e.g. 3.99",
                                text: $item.amount
                            )
                            .keyboardType(.decimalPad)

                            Picker("Category", selection: $item.category) {
                                ForEach(categories, id: \.self) { category in
                                    Text(category).tag(category)
                                }
                            }

                            Picker(
                                "Classification",
                                selection: $item.classification
                            ) {
                                Text("Unclassified").tag("Unclassified")
                                Text("Need").tag("Need")
                                Text("Want").tag("Want")
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete { offsets in
                        items.remove(atOffsets: offsets)
                    }

                    Button {
                        items.append(ItemDraft())
                    } label: {
                        Label("Add another item", systemImage: "plus")
                    }
                } header: {
                    Text("Items")
                } footer: {
                    Text(
                        "Enter each line's total, not its unit price. "
                        + "Use a decimal point, without $ or commas. "
                        + "Tax and discounts will come in a later step."
                    )
                }

                Section("Calculated total") {
                    if let total = calculatedTotalCents {
                        Text(
                            Decimal(total) / Decimal(100),
                            format: .currency(code: "USD")
                        )
                        .font(.headline)
                    } else {
                        Text("Enter a valid amount for every item.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New Receipt")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveReceipt()
                    }
                    .disabled(!canSave)
                }
            }
            .interactiveDismissDisabled()
            .alert("Couldn't save receipt", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var calculatedTotalCents: Int64? {
        guard !items.isEmpty else { return nil }

        var total: Int64 = 0

        for item in items {
            guard let cents = parseCents(item.amount) else {
                return nil
            }

            let result = total.addingReportingOverflow(cents)
            guard !result.overflow else { return nil }
            total = result.partialValue
        }

        return total
    }

    private var canSave: Bool {
        !merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && calculatedTotalCents != nil
        && items.allSatisfy {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func saveReceipt() {
        guard canSave, let total = calculatedTotalCents else {
            return
        }

        let receipt = Receipt(
            merchantName: merchantName.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            purchaseDate: purchaseDate,
            totalCents: total
        )

        var savedItems: [ReceiptItem] = []

        for draft in items {
            guard let cents = parseCents(draft.amount) else {
                return
            }

            let isLuxury: Bool?
            switch draft.classification {
            case "Need":
                isLuxury = false
            case "Want":
                isLuxury = true
            default:
                isLuxury = nil
            }

            savedItems.append(
                ReceiptItem(
                    name: draft.name.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    lineTotalCents: cents,
                    category: draft.category,
                    isLuxury: isLuxury
                )
            )
        }

        print(
            "Container models:",
            modelContext.container.schema.entities.map { $0.name }
        )

        modelContext.insert(receipt)

        print("Pending inserts:", modelContext.insertedModelsArray.count)

        let beforeSave = try? modelContext.fetch(
            FetchDescriptor<Receipt>()
        )
        print("Receipt count before save:", beforeSave?.count as Any)


        for item in savedItems {
            modelContext.insert(item)
            item.receipt = receipt
        }

        do {
            try modelContext.save()

            let savedReceipts = try modelContext.fetch(
                FetchDescriptor<Receipt>()
            )

            print("Saved receipt count:", savedReceipts.count)
            print("Saved merchants:", savedReceipts.map { $0.merchantName })

            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    // Convert text directly to integer cents without using Double.
    private func parseCents(_ input: String) -> Int64? {
        let text = input.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard text.range(
            of: #"^[0-9]{1,9}(\.[0-9]{1,2})?$"#,
            options: .regularExpression
        ) != nil else {
            return nil
        }

        let parts = text.split(
            separator: ".",
            omittingEmptySubsequences: false
        )

        guard let dollars = Int64(String(parts[0])) else {
            return nil
        }

        let fraction = parts.count == 2 ? String(parts[1]) : ""
        let paddedFraction = fraction.padding(
            toLength: 2,
            withPad: "0",
            startingAt: 0
        )

        guard let cents = Int64(paddedFraction) else {
            return nil
        }

        return dollars * 100 + cents
    }
}

#Preview {
    AddReceiptView()
        .modelContainer(
            for: [Receipt.self, ReceiptItem.self],
            inMemory: true
        )
}
