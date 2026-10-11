import SwiftUI
import PhotosUI

@available(iOS 26.0, *)
struct ReceiptImportView: View {
    private struct ImportedReceipt: Identifiable {
        let id = UUID()
        let extraction: ReceiptExtraction
    }

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var importedReceipt: ImportedReceipt?
    @State private var isProcessing = false
    @State private var progressMessage = ""
    @State private var errorMessage: String?
    @State private var didSave = false
    #if DEBUG
    @State private var recognizedText = ""
    #endif

    private let importService = ReceiptImportService()

    var body: some View {
        List {
            OnDeviceAIStatusView()

            Section {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Choose receipt photo", systemImage: "photo")
                }
                .disabled(isProcessing)

                if isProcessing {
                    ProgressView(progressMessage)
                }
            } footer: {
                Text("Your receipt is analyzed on your device. Review the details before saving.")
            }

            if let error = errorMessage {
                Section("Couldn't analyze receipt") {
                    Text(error).foregroundStyle(.red)
                    Button("Try again") {
                        selectedPhoto = nil
                        errorMessage = nil
                    }
                    NavigationLink("Enter receipt manually") {
                        AddReceiptView()
                    }
                }
            }

            #if DEBUG
            // Raw OCR is available to developers, never in release builds.
            if !recognizedText.isEmpty {
                Section {
                    DisclosureGroup("Debug: recognized text") {
                        Text(recognizedText)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            #endif
        }
        .navigationTitle("Import Receipt")
        .sheet(item: $importedReceipt, onDismiss: {
            // Close the import screen only after the review sheet has closed.
            if didSave { dismiss() }
        }) { receipt in
            NavigationStack {
                SaveImportedReceiptView(extraction: receipt.extraction) {
                    didSave = true
                    importedReceipt = nil
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { importedReceipt = nil }
                    }
                }
            }
        }
        .task(id: selectedPhoto) {
            guard let photo = selectedPhoto else { return }
            await importReceipt(from: photo)
        }
    }

    @MainActor
    private func importReceipt(from photo: PhotosPickerItem) async {
        isProcessing = true
        errorMessage = nil
        didSave = false
        progressMessage = "Reading receipt…"
        #if DEBUG
        recognizedText = ""
        #endif
        defer { isProcessing = false }

        do {
            guard let data = try await photo.loadTransferable(type: Data.self) else {
                errorMessage = "Couldn't load the selected photo."
                return
            }
            let extraction = try await importService.analyze(data) { text in
                #if DEBUG
                recognizedText = text
                #endif
                progressMessage = "Analyzing receipt…"
            }
            importedReceipt = ImportedReceipt(extraction: extraction)
        } catch is CancellationError {
            // Leaving the screen cancels the import.
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        ReceiptImportView()
    }
}
