import Foundation

// MARK: - Deduction Frequency
/// Frequency at which a deduction amount is specified
enum DeductionFrequency: String, Codable, CaseIterable, Identifiable {
    case annual
    case monthly
    case perPaycheck

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .annual:
            return "Annual"
        case .monthly:
            return "Monthly"
        case .perPaycheck:
            return "Per Check"
        }
    }

    var shortName: String {
        switch self {
        case .annual:
            return "/yr"
        case .monthly:
            return "/mo"
        case .perPaycheck:
            return "/check"
        }
    }

    /// Convert an amount to annual based on this frequency and pay frequency
    func toAnnual(_ amount: Decimal, payFrequency: PayFrequency) -> Decimal {
        switch self {
        case .annual:
            return amount
        case .monthly:
            return amount * 12
        case .perPaycheck:
            return amount * Decimal(payFrequency.periodsPerYear)
        }
    }

    /// Convert an annual amount to this frequency
    func fromAnnual(_ annual: Decimal, payFrequency: PayFrequency) -> Decimal {
        switch self {
        case .annual:
            return annual
        case .monthly:
            return annual / 12
        case .perPaycheck:
            return annual / Decimal(payFrequency.periodsPerYear)
        }
    }
}
