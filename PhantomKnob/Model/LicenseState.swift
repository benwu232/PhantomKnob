import Foundation

public enum LicenseState: Equatable {
    case trialing(daysRemaining: Int)
    case licensed
    case free
    
    public var daysRemaining: Int? {
        switch self {
        case .trialing(let days):
            return days
        default:
            return nil
        }
    }
    
    public var isPremiumActive: Bool {
        switch self {
        case .trialing, .licensed:
            return true
        case .free:
            return false
        }
    }
    
    public var hasStyleCustomization: Bool {
        switch self {
        case .trialing, .licensed:
            return true
        case .free:
            return false
        }
    }
    
    public var hasCloudSync: Bool {
        switch self {
        case .trialing, .licensed:
            return true
        case .free:
            return false
        }
    }
    
    public var activationDelay: Double {
        switch self {
        case .free:
            return 2.0
        case .trialing, .licensed:
            return 0.0
        }
    }
    
    public var sessionLimitSeconds: Double? {
        switch self {
        case .free:
            return 900.0
        case .trialing, .licensed:
            return nil
        }
    }
}
