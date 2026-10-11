import SwiftUI
import SwiftData

struct BudgetEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var amount: String
    @State private var error: String?
    let month: Date
    let currency: String

    init(month: Date, currency: String, amountCents: Int64?) {
        self.month = month
        self.currency = currency
        _amount = State(initialValue: amountCents.map { NSDecimalNumber(decimal: Decimal($0) / 100).stringValue } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(month, format: .dateTime.month(.wide).year())
                    HStack {
                        Text("Budget (\(currency))")
                        TextField("500.00", text: $amount)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                } footer: {
                    Text("This budget applies to this month and currency only. Receipts and paid bills count as spending; unpaid recurring bills reserve their scheduled amounts.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color("AppBackground"))
            .navigationTitle("Monthly budget")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .alert("Couldn't save budget", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    private func save() {
        do {
            try BudgetStore.save(amount: amount, month: month, currency: currency, in: context)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
