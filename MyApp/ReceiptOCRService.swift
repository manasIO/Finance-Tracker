import Foundation
import ImageIO
import Vision

actor ReceiptOCRService {
    func recognizeText(in data: Data) throws -> String {
        try Task.checkCancellation()

        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            nil
        ) else {
            throw OCRError.invalidImage
        }

        // Resize large photos and apply their orientation.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 3000
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            throw OCRError.invalidImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(
            cgImage: image,
            orientation: .up,
            options: [:]
        )

        try handler.perform([request])
        try Task.checkCancellation()

        let lines = (request.results ?? []).compactMap {
            $0.topCandidates(1).first?.string
        }

        guard !lines.isEmpty else {
            throw OCRError.noTextFound
        }

        return lines.joined(separator: "\n")
    }

    enum OCRError: LocalizedError {
        case invalidImage
        case noTextFound

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "Couldn't read this image. Try another photo."
            case .noTextFound:
                return "No text was found. Try a clearer receipt photo."
            }
        }
    }
}
