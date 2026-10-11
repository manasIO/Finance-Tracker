import XCTest
@testable import FinanceTracker

final class DashboardGreetingTests: XCTestCase {
    func testGreetingChangesAtLocalNoonAndUsesOptionalFirstName() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 5 * 3600)!
        func date(_ hour: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: hour))!
        }
        XCTAssertEqual(DashboardGreeting.message(name: "  Manas Tiwari  ", at: date(11), calendar: calendar), "Good morning, Manas")
        XCTAssertEqual(DashboardGreeting.message(name: "Manas", at: date(12), calendar: calendar), "Good evening, Manas")
        XCTAssertEqual(DashboardGreeting.message(name: nil, at: date(0), calendar: calendar), "Good morning")
        XCTAssertEqual(DashboardGreeting.message(name: " \n ", at: date(23), calendar: calendar), "Good evening")
    }
}
