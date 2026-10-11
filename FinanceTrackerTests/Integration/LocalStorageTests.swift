import XCTest
import SwiftData
@testable import FinanceTracker

@MainActor
final class LocalStorageTests: XCTestCase {
    func testBackupExclusionIsSetOnLocalDataDirectory() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try LocalStorage.excludeFromBackup(url)
        XCTAssertEqual(try url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
    }

    func testTestsUseMemoryAndConfigurationKeepsExistingStoreLocation() throws {
        let configuration = try LocalStorage.configuration(inMemory: true)
        XCTAssertTrue(configuration.isStoredInMemoryOnly)
        XCTAssertNil(configuration.cloudKitContainerIdentifier)
        XCTAssertEqual(configuration.url, ModelConfiguration(isStoredInMemoryOnly: true).url)
        let container = try LocalStorage.container(inMemory: true)
        XCTAssertTrue(container.configurations.allSatisfy { $0.isStoredInMemoryOnly })
    }
}
