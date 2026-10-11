import Foundation
import CoreGraphics
import ImageIO
import Vision

actor ReceiptOCRService {
    private struct TextBlock {
        let text: String
        let box: CGRect
    }

    private struct TextRow {
        // Keep the first block as a fixed alignment reference.
        let anchor: CGRect
        var blocks: [TextBlock]
    }

    func recognizeText(in data: Data) throws -> String {
        try Task.checkCancellation()

        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            nil
        ) else {
            throw OCRError.invalidImage
        }

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

        let blocks: [TextBlock] = (request.results ?? []).compactMap {
            observation in

            guard let candidate = observation.topCandidates(1).first else {
                return nil
            }

            let text = candidate.string.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard !text.isEmpty else {
                return nil
            }

            return TextBlock(
                text: text,
                box: observation.boundingBox
            )
        }

        guard !blocks.isEmpty else {
            throw OCRError.noTextFound
        }

        return reconstructRows(from: blocks)
    }

    private func reconstructRows(from blocks: [TextBlock]) -> String {
        // Vision's origin is bottom-left, so higher Y comes first.
        let topToBottom = blocks.sorted { first, second in
            if first.box.midY == second.box.midY {
                return first.box.minX < second.box.minX
            }

            return first.box.midY > second.box.midY
        }

        var rows: [TextRow] = []

        for block in topToBottom {
            var bestRowIndex: Int?
            var smallestDistance = CGFloat.greatestFiniteMagnitude

            for index in rows.indices {
                let anchor = rows[index].anchor

                guard belongsToSameRow(block.box, anchor) else {
                    continue
                }

                let distance = abs(block.box.midY - anchor.midY)

                if distance < smallestDistance {
                    smallestDistance = distance
                    bestRowIndex = index
                }
            }

            if let index = bestRowIndex {
                rows[index].blocks.append(block)
            } else {
                rows.append(
                    TextRow(
                        anchor: block.box,
                        blocks: [block]
                    )
                )
            }
        }

        let orderedRows = rows.sorted {
            $0.anchor.midY > $1.anchor.midY
        }

        return orderedRows.map { row in
            row.blocks
                .sorted { $0.box.minX < $1.box.minX }
                .map { $0.text }
                .joined(separator: " | ")
        }
        .joined(separator: "\n")
    }

    private func belongsToSameRow(
        _ first: CGRect,
        _ second: CGRect
    ) -> Bool {
        let smallerHeight = min(first.height, second.height)

        guard smallerHeight > 0 else {
            return false
        }

        let verticalOverlap = max(
            CGFloat.zero,
            min(first.maxY, second.maxY)
                - max(first.minY, second.minY)
        )

        let centerDistance = abs(first.midY - second.midY)

        return verticalOverlap >= smallerHeight * 0.5
            && centerDistance <= smallerHeight * 0.6
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
