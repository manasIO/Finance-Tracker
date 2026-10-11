import XCTest
@testable import FinanceTracker

@MainActor
final class ReceiptImportServiceTests: XCTestCase {
    private enum Failure: Error { case ocr, ai }

    func testPassesExactOCRTextToAIAndReportsProgress() async throws {
        let text = "Example Grocery\nMilk | 3.99\nvisit example.com"
        var service = ReceiptImportService()
        var events: [String] = []
        service.recognizeText = { data in
            XCTAssertEqual(data, Data([1, 2, 3]))
            events.append("ocr")
            return text
        }
        service.extractReceipt = { input in
            XCTAssertEqual(input, text)
            events.append("ai")
            return ReceiptFixtures.extraction()
        }
        let result = try await service.analyze(Data([1, 2, 3])) { recognized in
            XCTAssertEqual(recognized, text)
            events.append("progress")
        }
        XCTAssertEqual(events, ["ocr", "progress", "ai"])
        XCTAssertEqual(result.merchantName, "Example Grocery")
        XCTAssertEqual(result.items.count, 2)
    }

    func testOversizedPhotoNeverCallsOCRorAI() async {
        var service = ReceiptImportService()
        service.recognizeText = { _ in XCTFail("OCR should not run"); return "" }
        service.extractReceipt = { _ in XCTFail("AI should not run"); return ReceiptFixtures.extraction() }
        do {
            _ = try await service.analyze(Data(count: 25 * 1024 * 1024 + 1))
            XCTFail("Oversized photo accepted")
        } catch ReceiptImportService.ImportError.imageTooLarge {
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    func testOCRFailureDoesNotRunAI() async {
        var service = ReceiptImportService()
        service.recognizeText = { _ in throw Failure.ocr }
        service.extractReceipt = { _ in XCTFail("AI should not run"); return ReceiptFixtures.extraction() }
        do {
            _ = try await service.analyze(Data([1]))
            XCTFail("OCR failure swallowed")
        } catch Failure.ocr {
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    func testAIFailureIsReturnedToCaller() async {
        var service = ReceiptImportService()
        service.recognizeText = { _ in "Example Grocery" }
        service.extractReceipt = { _ in throw Failure.ai }
        do {
            _ = try await service.analyze(Data([1]))
            XCTFail("AI failure swallowed")
        } catch Failure.ai {
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    func testCancelledImportDoesNotReturnStaleReceipt() async {
        var service = ReceiptImportService()
        service.recognizeText = { _ in "Example Grocery" }
        service.extractReceipt = { _ in
            // Simulate a model call that completes even after cancellation.
            withUnsafeCurrentTask { $0?.cancel() }
            return ReceiptFixtures.extraction()
        }
        let task = Task { try await service.analyze(Data([1])) }
        do {
            _ = try await task.value
            XCTFail("Cancelled import returned a receipt")
        } catch is CancellationError {
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    func testCancellationAfterOCRPreventsAI() async {
        var service = ReceiptImportService()
        service.recognizeText = { _ in
            withUnsafeCurrentTask { $0?.cancel() }
            return "Example Grocery"
        }
        service.extractReceipt = { _ in XCTFail("AI should not run"); return ReceiptFixtures.extraction() }
        let task = Task { try await service.analyze(Data([1])) }
        do {
            _ = try await task.value
            XCTFail("Cancelled OCR continued")
        } catch is CancellationError {
        } catch { XCTFail("Unexpected error: \(error)") }
    }
}
