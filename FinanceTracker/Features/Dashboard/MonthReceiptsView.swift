import SwiftUI
import SwiftData

struct MonthReceiptsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var payments: [RecurringPayment]
    @Query private var receipts: [Receipt]
    @State private var deletionError: String?
    let month: Date
    let currencyCode: String

    init(month: Date, currencyCode: String, calendar: Calendar = .current, now: Date = .now) {
        self.month = month
        self.currencyCode = currencyCode
        let end = calendar.date(byAdding: .month, value: 1, to: month) ?? month
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let cutoff = min(end, tomorrow)
        _payments = Query(filter: #Predicate<RecurringPayment> {
            $0.paidDate >= month && $0.paidDate < cutoff && $0.currencyCode == currencyCode
        }, sort: \RecurringPayment.paidDate, order: .reverse)
        _receipts = Query(
            filter: #Predicate<Receipt> {
                $0.purchaseDate >= month && $0.purchaseDate < cutoff && $0.currencyCode == currencyCode
            },
            sort: \Receipt.purchaseDate,
            order: .reverse
        )
    }

    var body: some View {
        List {
            if receipts.isEmpty && payments.isEmpty {
                ContentUnavailableView("No spending this month", systemImage: "receipt")
            } else {
                Section {
                    LabeledContent("Recorded spending") {
                        Text((receipts.reduce(Decimal(0)) { $0 + Decimal($1.totalCents) }
                              + payments.reduce(Decimal(0)) { $0 + Decimal($1.amountCents) }) / 100,
                             format: .currency(code: currencyCode))
                    }
                }
                if !payments.isEmpty {
                    Section {
                        ForEach(payments) { payment in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(payment.name).font(.headline)
                                    Text(payment.paidDate, format: .dateTime.month().day()).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(Decimal(payment.amountCents) / 100, format: .currency(code: currencyCode))
                            }
                        }
                        .onDelete { offsets in
                            let selected = offsets.map { payments[$0] }
                            selected.forEach { modelContext.delete($0) }
                            saveDeletion()
                        }
                    } header: { Text("Paid recurring bills") }
                    footer: { Text("Swipe left to remove a payment. The recurring schedule is kept.") }
                }
                Section {
                    ForEach(receipts) { receipt in
                        NavigationLink {
                            ReceiptDetailView(receipt: receipt)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(receipt.merchantName).font(.headline)
                                    Text(receipt.purchaseDate, format: .dateTime.month().day())
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(Decimal(receipt.totalCents) / 100, format: .currency(code: currencyCode))
                            }
                        }
                    }
                    .onDelete(perform: deleteReceipts)
                } header: { Text("Receipts") }
                footer: { Text("Open a receipt to delete it, or swipe left on a row.") }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("AppBackground"))
        .navigationTitle(month.formatted(.dateTime.month(.wide).year()))
        .toolbar {
            if !receipts.isEmpty || !payments.isEmpty {
                EditButton()
            }
        }
        .alert("Couldn't delete receipt", isPresented: Binding(
            get: { deletionError != nil },
            set: { if !$0 { deletionError = nil } }
        )) {
            Button("OK", role: .cancel) { deletionError = nil }
        } message: {
            Text(deletionError ?? "")
        }
    }

    private func deleteReceipts(at offsets: IndexSet) {
        // Capture the selected rows before deletion changes the query results.
        let selected = offsets.map { receipts[$0] }
        for receipt in selected {
            modelContext.delete(receipt)
        }
        saveDeletion()
    }

    private func saveDeletion() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            deletionError = error.localizedDescription
        }
    }
}
