import Foundation
import SwiftUI
import PhotosUI

struct ReceiptImportView: View {
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var recognizedText = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingAIReview = false

    private let ocrService = ReceiptOCRService()

    var body: some View {
        List {
            OnDeviceAIStatusView()
            Section {
                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images
                ) {
                    Label(
                        "Choose receipt photo",
                        systemImage: "photo"
                    )
                }
                .disabled(isProcessing)

                if isProcessing {
                    ProgressView("Loading photo and reading text…")
                }
            } footer: {
                Text(
                    "Text recognition happens on your device. "
                    + "This feature does not send the receipt to an AI service."
                )
            }

            if let errorMessage {
                Section("Couldn't read receipt") {
                    Text(errorMessage)
                        .foregroundStyle(.red)

                    Button("Try again") {
                        selectedPhoto = nil
                    }
                }
            }

            if !recognizedText.isEmpty {
                Section("Recognized text") {
                    Text(recognizedText)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            if #available(iOS 26.0, *) {
                Section {
                    Button("Prepare for on-device AI") {
                        showingAIReview = true
                    }
                    .disabled(isProcessing)
                }
            }
            }
        }
        .navigationTitle("Import Receipt")
        .sheet(isPresented: $showingAIReview) {
            if #available(iOS 26.0, *) {
                ReceiptAIReviewView(ocrText: recognizedText)
            }
        }
        .task(id: selectedPhoto) {
            guard let photo = selectedPhoto else {
                return
            }

            await readPhoto(photo)
        }
    }

    @MainActor
    private func readPhoto(_ photo: PhotosPickerItem) async {
        isProcessing = true
        errorMessage = nil
        recognizedText = ""

        defer {
            isProcessing = false
        }

        do {
            guard let data = try await photo.loadTransferable(
                type: Data.self
            ) else {
                errorMessage = "Couldn't load the selected photo."
                return
            }

            // Limit the image size accepted by this first version.
            guard data.count <= 25 * 1024 * 1024 else {
                errorMessage = "Choose a photo smaller than 25 MB."
                return
            }

            let text = try await ocrService.recognizeText(in: data)

            try Task.checkCancellation()
            recognizedText = text
        } catch is CancellationError {
            // Leaving the screen cancels the task.
        } catch {
            guard !Task.isCancelled else {
                return
            }

            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        ReceiptImportView()
    }
}
