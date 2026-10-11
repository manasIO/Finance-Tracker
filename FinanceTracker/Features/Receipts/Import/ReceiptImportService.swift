import Foundation

@available(iOS 26.0, *)
@MainActor
struct ReceiptImportService {
    var recognizeText: (Data) async throws -> String
    var extractReceipt: (String) async throws -> ReceiptExtraction

    init() {
        let ocrService = ReceiptOCRService()
        let aiService = ReceiptAIService()
        recognizeText = { try await ocrService.recognizeText(in: $0) }
        extractReceipt = { try await aiService.extractReceipt(from: $0) }
    }

    func analyze(_ data: Data, onRecognizedText: (String) -> Void = { _ in }) async throws -> ReceiptExtraction {
        try Task.checkCancellation()
        guard data.count <= 25 * 1024 * 1024 else { throw ImportError.imageTooLarge }
        let text = try await recognizeText(data)
        try Task.checkCancellation()
        onRecognizedText(text)
        let receipt = try await extractReceipt(text)
        try Task.checkCancellation()
        return receipt
    }

    enum ImportError: LocalizedError {
        case imageTooLarge
        var errorDescription: String? { "Choose a photo smaller than 25 MB." }
    }
}
