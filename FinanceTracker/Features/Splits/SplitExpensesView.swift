import SwiftUI
import SwiftData

struct SplitExpensesView: View {
    @Environment(\.modelContext) private var context
    @Query private var receipts: [Receipt]
    @Query private var payments: [RecurringPayment]
    @State private var error: String?

    private var entries: [SplitExpenseSource] {
        (receipts.map(SplitExpenseSource.purchase) + payments.map(SplitExpenseSource.bill))
            .filter { $0.pending || $0.resolvedAt != nil }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                Text("Flag purchases to split later, then mark them resolved when you've settled up. Spending keeps the full purchase amount.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Needs splitting") {
                if entries.allSatisfy({ !$0.pending }) {
                    Text("Nothing waiting to be split.").foregroundStyle(.secondary)
                }
                ForEach(entries.filter(\.pending)) { entry in row(entry) }
            }
            Section("Resolved history") {
                if entries.allSatisfy(\.pending) {
                    Text("Resolved purchases will appear here.").foregroundStyle(.secondary)
                }
                ForEach(entries.filter { !$0.pending }) { entry in row(entry) }
            }
        }
        .scrollContentBackground(.hidden).background(Color("AppBackground"))
        .navigationTitle("Split expenses")
        .alert("Couldn't save changes", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }

    private func row(_ entry: SplitExpenseSource) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.name).font(.headline)
                    Text(entry.date, format: .dateTime.month().day().year()).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(entry.amount, format: .currency(code: entry.currency))
            }
            if case .purchase(let receipt) = entry {
                NavigationLink("View purchase") { ReceiptDetailView(receipt: receipt) }
            }
            if let date = entry.resolvedAt, !entry.pending {
                Text("Resolved \(date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button {
                do { try SplitStore.setPending(!entry.pending, for: entry, in: context) }
                catch { self.error = error.localizedDescription }
            } label: {
                Label(entry.pending ? "Mark resolved" : "Needs splitting again",
                      systemImage: entry.pending ? "checkmark.circle" : "arrow.uturn.backward")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 6)
    }
}
