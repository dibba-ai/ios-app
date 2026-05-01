import Foundation

public enum GoalOption: String, CaseIterable, Identifiable, Sendable {
    case retire, business, kids, travel, house, car, emergency, save

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .retire: return "Retire earlier"
        case .business: return "Start new business"
        case .kids: return "Raise kids"
        case .travel: return "Travel"
        case .house: return "Buy a house"
        case .car: return "New car"
        case .emergency: return "Build emergency fund"
        case .save: return "Save for better future"
        }
    }

    public var emoji: String {
        switch self {
        case .retire: return "🌅"
        case .business: return "🌐"
        case .kids: return "👶"
        case .travel: return "✈️"
        case .house: return "🏠"
        case .car: return "🚗"
        case .emergency: return "👛"
        case .save: return "🐷"
        }
    }
}

public enum OccupationOption: String, CaseIterable, Identifiable, Sendable {
    case employed, freelancer, business, student, sabbatical, unemployed

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .employed: return "Employed"
        case .freelancer: return "Freelancer"
        case .business: return "Own Business"
        case .student: return "Student"
        case .sabbatical: return "Sabbatical"
        case .unemployed: return "Unemployed"
        }
    }

    public var emoji: String {
        switch self {
        case .employed: return "💼"
        case .freelancer: return "💻"
        case .business: return "🏢"
        case .student: return "🎓"
        case .sabbatical: return "✈️"
        case .unemployed: return "🏠"
        }
    }
}

public enum HousingOption: String, CaseIterable, Identifiable, Sendable {
    case owner, rent_apt, rent_house, coliving

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .owner: return "Own Property"
        case .rent_apt: return "Rental Apartment"
        case .rent_house: return "Rental House/Villa"
        case .coliving: return "Co-living / Shared"
        }
    }

    public var emoji: String {
        switch self {
        case .owner: return "🏡"
        case .rent_apt: return "🏢"
        case .rent_house: return "🏠"
        case .coliving: return "👥"
        }
    }
}

public enum TransportOption: String, CaseIterable, Identifiable, Sendable {
    case own_car, rental_car, public_transport

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .own_car: return "Own Car"
        case .rental_car: return "Rental Car"
        case .public_transport: return "Public Transport"
        }
    }

    public var emoji: String {
        switch self {
        case .own_car: return "🚗"
        case .rental_car: return "🚙"
        case .public_transport: return "🚌"
        }
    }
}

public enum AgeOption: String, CaseIterable, Identifiable, Sendable {
    case under_20, twenties = "20s", thirties = "30s", forties = "40s", fifty_plus = "50_plus"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .under_20: return "Under 20"
        case .twenties: return "20s"
        case .thirties: return "30s"
        case .forties: return "40s"
        case .fifty_plus: return "50+"
        }
    }

    public var emoji: String {
        switch self {
        case .under_20: return "🎓"
        case .twenties: return "🎉"
        case .thirties: return "🌱"
        case .forties: return "🌳"
        case .fifty_plus: return "🌅"
        }
    }
}
