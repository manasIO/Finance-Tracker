import SwiftUI
import PhotosUI
import AVFoundation

@available(iOS 26.0, *)
struct ReceiptImportView: View {
    enum Source { case photoLibrary, camera }
    var source: Source = .photoLibrary

    private struct CapturedPhoto {
        let id = UUID()
        let data: Data
    }

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
    @State private var showingCamera = false
    @State private var didOpenCamera = false
    @State private var cameraAccessDenied = false
    @State private var pendingPhoto: CapturedPhoto?
    @State private var capturedPhoto: CapturedPhoto?
    #if DEBUG
    @State private var recognizedText = ""
    #endif

    private let importService = ReceiptImportService()

    var body: some View {
        List {
            Section {
                if isProcessing {
                    ReceiptAnalysisProgressView(stage: progressMessage)
                } else if source == .camera {
                    Button {
                        Task { await openCamera() }
                    } label: {
                        Label("Take receipt photo", systemImage: "camera")
                    }
                    .disabled(isProcessing)
                } else {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose receipt photo", systemImage: "photo")
                    }
                    .disabled(isProcessing)
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
                        if source == .camera { Task { await openCamera() } }
                    }
                    if cameraAccessDenied {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
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
                    DisclosureGroup("Extracted text from receipt") {
                        Text(recognizedText)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(Color("AppBackground"))
        .navigationTitle(source == .camera ? "Take Receipt Photo" : "Import Receipt")
        .fullScreenCover(isPresented: $showingCamera, onDismiss: {
            // Wait for the camera to close before starting analysis and review.
            capturedPhoto = pendingPhoto
            pendingPhoto = nil
        }) {
            ReceiptCameraView(onCapture: { data in
                pendingPhoto = CapturedPhoto(data: data)
                showingCamera = false
            }, onCancel: {
                showingCamera = false
            }, onError: { message in
                errorMessage = message
                showingCamera = false
            })
            .ignoresSafeArea()
        }
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
        .task {
            if source == .camera && !didOpenCamera {
                didOpenCamera = true
                await openCamera()
            }
        }
        .task(id: capturedPhoto?.id) {
            guard let photo = capturedPhoto else { return }
            await importReceipt(loadData: { photo.data })
        }
        .task(id: selectedPhoto) {
            guard let photo = selectedPhoto else { return }
            await importReceipt(loadData: { try await photo.loadTransferable(type: Data.self) })
        }
    }

    @MainActor
    private func openCamera() async {
        errorMessage = nil
        cameraAccessDenied = false
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = "This device has no available camera. Import a photo or enter the receipt manually."
            return
        }
        let allowed: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: allowed = true
        case .notDetermined: allowed = await AVCaptureDevice.requestAccess(for: .video)
        default: allowed = false
        }
        guard !Task.isCancelled else { return }
        if allowed {
            pendingPhoto = nil
            showingCamera = true
        } else {
            cameraAccessDenied = true
            errorMessage = "Camera access is unavailable. Allow camera access in Settings, or import a receipt photo."
        }
    }

    @MainActor
    private func importReceipt(loadData: () async throws -> Data?) async {
        isProcessing = true
        errorMessage = nil
        didSave = false
        progressMessage = "Reading receipt…"
        #if DEBUG
        recognizedText = ""
        #endif
        defer { isProcessing = false }

        do {
            guard let data = try await loadData() else {
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
