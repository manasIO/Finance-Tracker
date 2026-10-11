import Foundation

enum DashboardGreeting {
    static func message(name: String?, at date: Date, calendar: Calendar = .current) -> String {
        let greeting = calendar.component(.hour, from: date) < 12 ? "Good morning" : "Good evening"
        // Use the first word of the optional profile name for a personal greeting.
        guard let firstName = name?.split(whereSeparator: \.isWhitespace).first else { return greeting }
        return "\(greeting), \(firstName)"
    }
}
