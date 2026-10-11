import Foundation

enum ProfileAvatar: String, CaseIterable {
    case cat = "cat.fill"
    case dog = "dog.fill"
    case bird = "bird.fill"
    case tortoise = "tortoise.fill"
    case fish = "fish.fill"

    var name: String {
        switch self {
        case .cat: "Cat"
        case .dog: "Dog"
        case .bird: "Bird"
        case .tortoise: "Tortoise"
        case .fish: "Fish"
        }
    }
}
