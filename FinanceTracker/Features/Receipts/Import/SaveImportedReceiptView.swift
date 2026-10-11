import SwiftUI
import SwiftData

@available(iOS 26.0, *)
struct SaveImportedReceiptView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var draft: ReceiptImportDraft
    @State private var confirmedReview = false
    @State private var saveError: String?
    let onSaved: () -> Void

    private let categories = ["Uncategorized", "Groceries", "Dining", "Household", "Transport", "Health", "Entertainment", "Other"]

    init(extraction: ReceiptExtraction, onSaved: @escaping () -> Void) {
        _draft = State(initialValue: ReceiptImportDraft(extraction: extraction))
        self.onSaved = onSaved
    }

    private var needsConfirmation: Bool {
        draft.report.needsReview || !draft.extractionWarnings.isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("Store name", text: $draft.merchantName)
                DatePicker("Purchase date", selection: $draft.purchaseDate, displayedComponents: .date)
            } header: {
                Text("Purchase")
            } footer: {
                Text("Set the purchase date from your receipt; it starts at today. All amounts are in USD.")
            }

            Section("Receipt amounts") {
                amountField("Subtotal (optional)", text: $draft.subtotal)
                amountField("Total paid", text: $draft.total)
            }

            Section {
                ForEach($draft.taxes) { $tax in
                    amountField("Tax amount", text: $tax.amount)
                }
                .onDelete { draft.taxes.remove(atOffsets: $0) }
                Button("Add tax amount") { draft.taxes.append(.init()) }
            } header: {
                Text("Taxes")
            } footer: {
                Text("Enter 0.00 to confirm zero tax. No tax entries means the tax amount is unknown.")
            }

            Section {
                ForEach($draft.items) { $item in
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Item name", text: $item.name)
                        amountField("Line total", text: $item.lineTotal)
                        HStack {
                            Text("Quantity")
                            TextField("1", text: $item.quantity)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            TextField("Unit (optional)", text: $item.quantityUnit)
                                .multilineTextAlignment(.trailing)
                        }
                        amountField("Unit price (optional)", text: $item.unitPrice)
                        Picker("Category", selection: $item.category) {
                            ForEach(categories, id: \.self) { Text($0).tag($0) }
                        }
                        Picker("Classification", selection: $item.classification) {
                            Text("Unclassified").tag("Unclassified")
                            Text("Need").tag("Need")
                            Text("Want").tag("Want")
                        }
                    }
                    .padding(.vertical, 6)
                }
                .onDelete { draft.items.remove(atOffsets: $0) }
                Button("Add item") { draft.items.append(.init()) }
            } header: {
                Text("Items")
            } footer: {
                Text("Quantity starts at 1 when none was extracted. Confirm quantities and units against the receipt. Enter prices without $ or commas.")
            }

            Section("Review checks") {
                let report = draft.report
                ForEach(report.messages.indices, id: \.self) { index in
                    Text(report.messages[index]).font(.subheadline)
                }
                ForEach(draft.extractionWarnings.indices, id: \.self) { index in
                    Text(draft.extractionWarnings[index]).font(.subheadline)
                }
                if !draft.canSave {
                    Text("Enter a store, total, and at least one named item with a valid line total and positive quantity. Correct any invalid subtotal, tax, or unit price.")
                        .foregroundStyle(.red)
                }
                if needsConfirmation {
                    Toggle("I checked these fields against the receipt", isOn: $confirmedReview)
                }
            }

            if let saveError {
                Section("Couldn't save receipt") {
                    Text(saveError).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Review Receipt")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveReceipt() }
                    .disabled(!draft.canSave || (needsConfirmation && !confirmedReview))
            }
        }
        .onChange(of: draft) { _, _ in
            confirmedReview = false
            saveError = nil
        }
    }

    private func amountField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            TextField("0.00", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }

    private func saveReceipt() {
        do {
            _ = try ReceiptImportStore.save(draft, confirmedReview: confirmedReview, in: modelContext)
            onSaved()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
