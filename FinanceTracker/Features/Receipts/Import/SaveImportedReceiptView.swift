import SwiftUI
import SwiftData

@available(iOS 26.0, *)
struct SaveImportedReceiptView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var draft: ReceiptImportDraft
    @State private var saveError: String?
    @State private var duplicateMessage: String?
    let onSaved: () -> Void

    private let categories = ItemCategory.allCases.map(\.rawValue)

    init(extraction: ReceiptExtraction, onSaved: @escaping () -> Void) {
        _draft = State(initialValue: ReceiptImportDraft(extraction: extraction))
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            Section {
                TextField("Store name", text: $draft.merchantName)
                DatePicker("Purchase date", selection: $draft.purchaseDate, displayedComponents: .date)
                amountField("Total paid", text: $draft.total)
                Toggle("Needs splitting", isOn: $draft.needsSplit)
            } header: {
                Text("Purchase")
            } footer: {
                Text("Set the purchase date from your receipt; it starts at today. All amounts are in USD.")
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
                        if item.category == "Groceries" {
                            Picker("Food spending", selection: $item.foodChoice) {
                                ForEach(FoodChoice.allCases, id: \.self) { Text($0.label).tag($0.rawValue) }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .onDelete { draft.items.remove(atOffsets: $0) }
                Button("Add item") { draft.items.append(.init()) }
            } header: {
                Text("Items")
            } footer: {
                Text("Categories and Need/Want labels are suggestions. Change any that don’t fit your purchase. Quantity starts at 1 when missing.")
            }

        }
        .scrollContentBackground(.hidden)
        .background(Color("AppBackground"))
        .navigationTitle("Review Receipt")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveReceipt() }
            }
        }
        .alert("Couldn't save receipt", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
        .alert("Possible duplicate", isPresented: Binding(
            get: { duplicateMessage != nil },
            set: { if !$0 { duplicateMessage = nil } }
        )) {
            Button("Cancel", role: .cancel) { duplicateMessage = nil }
            Button("Save anyway") { duplicateMessage = nil; saveReceipt(allowDuplicate: true) }
        } message: {
            Text(duplicateMessage ?? "")
        }
        .onChange(of: draft) { _, _ in
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

    private func saveReceipt(allowDuplicate: Bool = false) {
        do {
            _ = try ReceiptImportStore.save(draft, in: modelContext, allowDuplicate: allowDuplicate)
            onSaved()
        } catch let error as ReceiptStore.SaveError {
            duplicateMessage = error.localizedDescription
        } catch {
            saveError = error.localizedDescription
        }
    }
}
