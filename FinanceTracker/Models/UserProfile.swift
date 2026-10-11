import SwiftData

@Model
final class UserProfile {
    var avatarSymbol: String = "cat.fill"
    var name: String = ""
    var email: String = ""
    var phone: String = ""

    init(name: String = "", email: String = "", phone: String = "") {
        self.name = name
        self.email = email
        self.phone = phone
    }
}
