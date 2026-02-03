import Foundation

// MARK: - Financial Profile
/// Complete financial profile for a user
struct FinancialProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var income: IncomeProfile
    var location: LocationProfile
    var deductions: DeductionProfile
    var householdType: HouseholdType
    var partnerProfile: PartnerProfile?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "My Profile",
        income: IncomeProfile = IncomeProfile(),
        location: LocationProfile = LocationProfile(),
        deductions: DeductionProfile = DeductionProfile(),
        householdType: HouseholdType = .single,
        partnerProfile: PartnerProfile? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.income = income
        self.location = location
        self.deductions = deductions
        self.householdType = householdType
        self.partnerProfile = partnerProfile
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Convert to TaxCalculationInput for the core engine
    func toTaxInput() -> TaxCalculationInput {
        TaxCalculationInput(
            grossIncome: income.grossSalary,
            filingStatus: location.filingStatus,
            state: location.state,
            preTaxDeductions: deductions.preTaxTotal,
            postTaxDeductions: deductions.postTaxTotal,
            traditional401k: deductions.traditional401k,
            roth401k: deductions.roth401k
        )
    }
}

// MARK: - Income Profile
struct IncomeProfile: Codable, Equatable {
    var grossSalary: Decimal
    var payFrequency: PayFrequency
    var bonusAnnual: Decimal

    init(
        grossSalary: Decimal = 0,
        payFrequency: PayFrequency = .biWeekly,
        bonusAnnual: Decimal = 0
    ) {
        self.grossSalary = grossSalary
        self.payFrequency = payFrequency
        self.bonusAnnual = bonusAnnual
    }

    var totalAnnualIncome: Decimal {
        grossSalary + bonusAnnual
    }
}

// MARK: - Location Profile
struct LocationProfile: Codable, Equatable {
    var state: USState
    var filingStatus: FilingStatus

    init(
        state: USState = .california,
        filingStatus: FilingStatus = .single
    ) {
        self.state = state
        self.filingStatus = filingStatus
    }
}

// MARK: - Deduction Profile
struct DeductionProfile: Codable, Equatable {
    // Legacy fields for backward compatibility
    var traditional401k: Decimal
    var roth401k: Decimal
    var healthInsurance: Decimal
    var hsa: Decimal
    var fsa: Decimal
    var otherPreTax: Decimal
    var otherPostTax: Decimal

    // Full itemized entries (new)
    var entries: [DeductionEntry]

    init(
        traditional401k: Decimal = 0,
        roth401k: Decimal = 0,
        healthInsurance: Decimal = 0,
        hsa: Decimal = 0,
        fsa: Decimal = 0,
        otherPreTax: Decimal = 0,
        otherPostTax: Decimal = 0,
        entries: [DeductionEntry] = []
    ) {
        self.traditional401k = traditional401k
        self.roth401k = roth401k
        self.healthInsurance = healthInsurance
        self.hsa = hsa
        self.fsa = fsa
        self.otherPreTax = otherPreTax
        self.otherPostTax = otherPostTax
        self.entries = entries
    }

    /// Pre-tax total from legacy fields (for backward compatibility)
    var preTaxTotal: Decimal {
        healthInsurance + hsa + fsa + otherPreTax
    }

    /// Post-tax total from legacy fields (for backward compatibility)
    var postTaxTotal: Decimal {
        otherPostTax
    }

    /// Pre-tax total from itemized entries
    func preTaxTotalFromEntries(grossSalary: Decimal, payFrequency: PayFrequency) -> Decimal {
        entries
            .filter { $0.type.isPreTax && $0.isEnabled }
            .reduce(Decimal(0)) { sum, entry in
                sum + entry.annualAmount(grossSalary: grossSalary, payFrequency: payFrequency)
            }
    }

    /// Post-tax total from itemized entries
    func postTaxTotalFromEntries(grossSalary: Decimal, payFrequency: PayFrequency) -> Decimal {
        entries
            .filter { !$0.type.isPreTax && $0.isEnabled }
            .reduce(Decimal(0)) { sum, entry in
                sum + entry.annualAmount(grossSalary: grossSalary, payFrequency: payFrequency)
            }
    }

    /// Get the 401k total from entries (traditional only, for tax calculation)
    func traditional401kFromEntries(grossSalary: Decimal, payFrequency: PayFrequency) -> Decimal {
        entries
            .first { $0.type == .traditional401k && $0.isEnabled }?
            .annualAmount(grossSalary: grossSalary, payFrequency: payFrequency) ?? 0
    }

    /// Get the Roth 401k total from entries
    func roth401kFromEntries(grossSalary: Decimal, payFrequency: PayFrequency) -> Decimal {
        entries
            .first { $0.type == .roth401k && $0.isEnabled }?
            .annualAmount(grossSalary: grossSalary, payFrequency: payFrequency) ?? 0
    }
}

// MARK: - Pay Frequency
enum PayFrequency: String, Codable, CaseIterable {
    case weekly
    case biWeekly = "bi_weekly"
    case semiMonthly = "semi_monthly"
    case monthly

    var periodsPerYear: Int {
        switch self {
        case .weekly: return 52
        case .biWeekly: return 26
        case .semiMonthly: return 24
        case .monthly: return 12
        }
    }

    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .biWeekly: return "Bi-Weekly"
        case .semiMonthly: return "Semi-Monthly"
        case .monthly: return "Monthly"
        }
    }
}
