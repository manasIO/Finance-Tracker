import Foundation
import SwiftUI
import SwiftData

struct ReceiptListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Receipt.purchaseDate, order: .reverse)
    private var receipts: [Receipt]

    @State private var searchText = ""

    private var visibleReceipts: [Receipt] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? receipts : receipts.filter { $0.merchantName.localizedCaseInsensitiveContains(query) }
    }

    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingQuickExpense = false
    @State private var showingAddReceipt = false

    var body: some View {
        NavigationStack {
            List {
                OnDeviceAIStatusView()

                Section {
                    Button { showingQuickExpense = true } label: {
                        receiptAction("Quick expense", detail: "Just an amount — no receipt needed", icon: "plus.circle.fill")
                    }
                }

                Section("Add a receipt") {
                    NavigationLink{
                        ReceiptImportView()
                    } label: {
                        receiptAction("Import photo", detail: "Choose a receipt from your photos", icon: "photo")
                    }
                    NavigationLink {
                        ReceiptImportView(source: .camera)
                    } label: {
                        receiptAction("Take photo", detail: "Scan a receipt with your camera", icon: "camera")
                    }
                    Button {
                        showingAddReceipt = true
                    } label: {
                        receiptAction("Enter manually", detail: "Add a purchase without a photo", icon: "square.and.pencil")
                    }
                }

                Section {
                    if receipts.isEmpty {
                        Text("No purchases yet. Add a quick expense or import a receipt to get started.")
                            .foregroundStyle(.secondary)
                    }

                    if !receipts.isEmpty && visibleReceipts.isEmpty {
                        Text("No purchases match your search.").foregroundStyle(.secondary)
                    }

                    ForEach(visibleReceipts) { receipt in
                        NavigationLink {
                            ReceiptDetailView(receipt: receipt)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(receipt.merchantName).font(.headline)
                                        if receipt.needsSplit {
                                            Image(systemName: "person.2.fill").foregroundStyle(Color.accentColor)
                                                .accessibilityLabel("Needs splitting")
                                        }
                                    }
                                    if receipt.isQuickExpense { Text("Quick expense").font(.caption).foregroundStyle(.secondary) }

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
                } header: { Text("Saved purchases") }
                footer: {
                    if !receipts.isEmpty { Text("Open a receipt to delete it, or swipe left on a row.") }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color("AppBackground"))
            .navigationTitle("Receipts")
            .searchable(text: $searchText, prompt: "Search by store or description")
            .sheet(isPresented: $showingQuickExpense) { QuickExpenseView() }
            .sheet(isPresented: $showingAddReceipt){
                    AddReceiptView()
                    .modelContainer(modelContext.container)
            }
            .alert("Couldn't save changes", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func receiptAction(_ title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 40, height: 40)
                .background(Color("SummaryBackground"), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func deleteReceipts(at offsets: IndexSet) {
        let receiptsToDelete = offsets.map { visibleReceipts[$0] }

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


// Convert stored cents to dollars only for display.
private func dollars(_ cents: Int64) -> Decimal {
    Decimal(cents) / Decimal(100)
}

#Preview {
    ReceiptListView()
        .modelContainer(
            for: [Receipt.self, ReceiptItem.self],
            inMemory: true
        )
}
