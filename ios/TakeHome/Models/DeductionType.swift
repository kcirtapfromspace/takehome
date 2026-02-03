import Foundation

// MARK: - Deduction Type
/// All supported payroll deduction types
enum DeductionType: String, Codable, CaseIterable, Identifiable {
    // Pre-tax retirement
    case traditional401k
    case roth401k
    case traditional403b
    case traditional457b

    // Pre-tax insurance
    case healthInsurance
    case dentalInsurance
    case visionInsurance

    // Pre-tax savings accounts
    case hsa
    case fsa
    case dependentCareFSA

    // Pre-tax benefits
    case commuterTransit
    case commuterParking
    case lifeInsurance

    // Post-tax
    case unionDues
    case garnishments
    case charitableDonations
    case otherPreTax
    case otherPostTax

    var id: String { rawValue }

    var isPreTax: Bool {
        switch self {
        case .roth401k, .unionDues, .garnishments, .charitableDonations, .otherPostTax:
            return false
        default:
            return true
        }
    }

    var displayName: String {
        switch self {
        case .traditional401k:
            return "Traditional 401(k)"
        case .roth401k:
            return "Roth 401(k)"
        case .traditional403b:
            return "403(b)"
        case .traditional457b:
            return "457(b)"
        case .healthInsurance:
            return "Health Insurance"
        case .dentalInsurance:
            return "Dental Insurance"
        case .visionInsurance:
            return "Vision Insurance"
        case .hsa:
            return "HSA"
        case .fsa:
            return "FSA"
        case .dependentCareFSA:
            return "Dependent Care FSA"
        case .commuterTransit:
            return "Commuter Transit"
        case .commuterParking:
            return "Commuter Parking"
        case .lifeInsurance:
            return "Life Insurance"
        case .unionDues:
            return "Union Dues"
        case .garnishments:
            return "Garnishments"
        case .charitableDonations:
            return "Charitable Donations"
        case .otherPreTax:
            return "Other Pre-Tax"
        case .otherPostTax:
            return "Other Post-Tax"
        }
    }

    var description: String {
        switch self {
        case .traditional401k:
            return "Reduces taxable income now; taxed on withdrawal in retirement"
        case .roth401k:
            return "Contributed after-tax; grows and withdraws tax-free"
        case .traditional403b:
            return "Retirement plan for nonprofit, education, and government workers"
        case .traditional457b:
            return "Deferred compensation plan for state/local government employees"
        case .healthInsurance:
            return "Your portion of employer-sponsored health insurance premiums"
        case .dentalInsurance:
            return "Dental coverage premiums"
        case .visionInsurance:
            return "Vision coverage premiums"
        case .hsa:
            return "Health Savings Account - triple tax advantaged"
        case .fsa:
            return "Flexible Spending Account for medical expenses"
        case .dependentCareFSA:
            return "FSA for childcare and dependent care expenses"
        case .commuterTransit:
            return "Pre-tax transit passes and vanpooling"
        case .commuterParking:
            return "Pre-tax qualified parking expenses"
        case .lifeInsurance:
            return "Group term life insurance premiums (may have pre-tax limit)"
        case .unionDues:
            return "Union membership fees"
        case .garnishments:
            return "Court-ordered wage garnishments"
        case .charitableDonations:
            return "Payroll deductions for charitable giving"
        case .otherPreTax:
            return "Other pre-tax deductions not listed"
        case .otherPostTax:
            return "Other post-tax deductions not listed"
        }
    }

    var icon: String {
        switch self {
        case .traditional401k, .roth401k, .traditional403b, .traditional457b:
            return "building.columns.fill"
        case .healthInsurance:
            return "heart.fill"
        case .dentalInsurance:
            return "mouth.fill"
        case .visionInsurance:
            return "eye.fill"
        case .hsa, .fsa, .dependentCareFSA:
            return "banknote.fill"
        case .commuterTransit:
            return "bus.fill"
        case .commuterParking:
            return "parkingsign.circle.fill"
        case .lifeInsurance:
            return "shield.fill"
        case .unionDues:
            return "person.3.fill"
        case .garnishments:
            return "doc.text.fill"
        case .charitableDonations:
            return "gift.fill"
        case .otherPreTax, .otherPostTax:
            return "ellipsis.circle.fill"
        }
    }

    /// IRS annual limit for 2024 (nil if no specific limit)
    var annualLimit: Decimal? {
        switch self {
        case .traditional401k, .roth401k:
            return 23000  // 2024 limit for under 50
        case .traditional403b:
            return 23000
        case .traditional457b:
            return 23000
        case .hsa:
            return 4150   // 2024 individual limit
        case .fsa:
            return 3200   // 2024 limit
        case .dependentCareFSA:
            return 5000   // 2024 limit (married filing jointly)
        case .commuterTransit:
            return 3150   // 2024 limit ($315/month * 12, approximated)
        case .commuterParking:
            return 3150   // 2024 limit
        default:
            return nil
        }
    }

    /// Catch-up contribution limit for age 50+ (if applicable)
    var catchUpLimit: Decimal? {
        switch self {
        case .traditional401k, .roth401k, .traditional403b:
            return 7500   // 2024 catch-up limit
        case .traditional457b:
            return 7500
        case .hsa:
            return 1000   // 2024 catch-up limit (age 55+)
        default:
            return nil
        }
    }

    /// All pre-tax deduction types
    static var preTaxTypes: [DeductionType] {
        allCases.filter { $0.isPreTax }
    }

    /// All post-tax deduction types
    static var postTaxTypes: [DeductionType] {
        allCases.filter { !$0.isPreTax }
    }
}
