# TakeHome Technical Architecture: Data Models

## Overview

This document defines all data models for TakeHome, including Swift domain models, Core Data entities, CloudKit record types, and Codable structures for remote configuration.

---

## 1. Domain Models (Swift)

### Core Financial Profile

```swift
import Foundation

/// Main user financial profile
struct FinancialProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date

    // Income
    var income: Income
    var payFrequency: PayFrequency

    // Location & Filing
    var state: USState
    var filingStatus: FilingStatus

    // Deductions
    var preTaxDeductions: [Deduction]
    var postTaxDeductions: [Deduction]
    var retirementContributions: RetirementContributions

    // Expenses
    var expenses: [Expense]

    // Household (optional)
    var household: Household?

    // Metadata
    var isActive: Bool
    var lastSyncedAt: Date?

    init(
        id: UUID = UUID(),
        name: String = "My Profile",
        income: Income = Income(),
        payFrequency: PayFrequency = .biWeekly,
        state: USState = .california,
        filingStatus: FilingStatus = .single
    ) {
        self.id = id
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.income = income
        self.payFrequency = payFrequency
        self.state = state
        self.filingStatus = filingStatus
        self.preTaxDeductions = []
        self.postTaxDeductions = []
        self.retirementContributions = RetirementContributions()
        self.expenses = []
        self.household = nil
        self.isActive = true
        self.lastSyncedAt = nil
    }
}
```

### Income Models

```swift
import Foundation

/// Base income information
struct Income: Codable, Equatable {
    var grossAnnualSalary: Decimal
    var bonuses: Decimal
    var otherIncome: Decimal

    var totalGrossAnnual: Decimal {
        grossAnnualSalary + bonuses + otherIncome
    }

    init(
        grossAnnualSalary: Decimal = 0,
        bonuses: Decimal = 0,
        otherIncome: Decimal = 0
    ) {
        self.grossAnnualSalary = grossAnnualSalary
        self.bonuses = bonuses
        self.otherIncome = otherIncome
    }
}

/// Calculated income across all timeframes
struct CalculatedIncome: Codable, Equatable {
    let gross: Decimal
    let net: Decimal
    let timeframes: TimeframeIncome

    var takeHomePercentage: Decimal {
        guard gross > 0 else { return 0 }
        return (net / gross) * 100
    }
}

/// Income broken down by timeframe
struct TimeframeIncome: Codable, Equatable {
    let annual: Decimal
    let monthly: Decimal
    let biWeekly: Decimal
    let weekly: Decimal
    let daily: Decimal
    let hourly: Decimal

    init(annual: Decimal) {
        self.annual = annual
        self.monthly = annual / 12
        self.biWeekly = annual / 26
        self.weekly = annual / 52
        self.daily = annual / 260      // 52 weeks × 5 days
        self.hourly = annual / 2080    // 52 weeks × 40 hours
    }

    /// Custom working hours per week
    init(annual: Decimal, hoursPerWeek: Decimal, daysPerWeek: Decimal = 5) {
        self.annual = annual
        self.monthly = annual / 12
        self.biWeekly = annual / 26
        self.weekly = annual / 52
        self.daily = annual / (52 * daysPerWeek)
        self.hourly = annual / (52 * hoursPerWeek)
    }
}

/// Pay frequency options
enum PayFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly = "weekly"
    case biWeekly = "bi_weekly"
    case semiMonthly = "semi_monthly"
    case monthly = "monthly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekly: return "Weekly (52/year)"
        case .biWeekly: return "Bi-Weekly (26/year)"
        case .semiMonthly: return "Semi-Monthly (24/year)"
        case .monthly: return "Monthly (12/year)"
        }
    }

    var periodsPerYear: Int {
        switch self {
        case .weekly: return 52
        case .biWeekly: return 26
        case .semiMonthly: return 24
        case .monthly: return 12
        }
    }
}
```

### Tax-Related Models

```swift
import Foundation

/// IRS filing status
enum FilingStatus: String, Codable, CaseIterable, Identifiable {
    case single = "single"
    case marriedFilingJointly = "married_filing_jointly"
    case marriedFilingSeparately = "married_filing_separately"
    case headOfHousehold = "head_of_household"
    case qualifyingWidower = "qualifying_widower"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .single: return "Single"
        case .marriedFilingJointly: return "Married Filing Jointly"
        case .marriedFilingSeparately: return "Married Filing Separately"
        case .headOfHousehold: return "Head of Household"
        case .qualifyingWidower: return "Qualifying Widow(er)"
        }
    }

    var shortName: String {
        switch self {
        case .single: return "Single"
        case .marriedFilingJointly: return "MFJ"
        case .marriedFilingSeparately: return "MFS"
        case .headOfHousehold: return "HoH"
        case .qualifyingWidower: return "QW"
        }
    }
}

/// Complete tax breakdown
struct TaxBreakdown: Codable, Equatable {
    let federal: FederalTaxResult
    let state: StateTaxResult
    let fica: FICAResult
    let totalTaxes: Decimal

    var effectiveRate: Decimal {
        guard federal.taxableIncome > 0 else { return 0 }
        return totalTaxes / federal.taxableIncome
    }
}

/// Federal tax calculation result
struct FederalTaxResult: Codable, Equatable {
    let taxableIncome: Decimal
    let tax: Decimal
    let marginalBracket: TaxBracket
    let effectiveRate: Decimal
    let bracketBreakdown: [BracketAmount]
}

/// State tax calculation result
struct StateTaxResult: Codable, Equatable {
    let state: USState
    let taxableIncome: Decimal
    let incomeTax: Decimal
    let localTax: Decimal
    let sdi: Decimal           // State Disability Insurance
    let otherTaxes: Decimal
    let totalTax: Decimal
    let effectiveRate: Decimal
    let bracketBreakdown: [BracketAmount]?
}

/// FICA (Social Security + Medicare) result
struct FICAResult: Codable, Equatable {
    let socialSecurity: Decimal
    let socialSecurityWageBase: Decimal
    let medicare: Decimal
    let additionalMedicare: Decimal
    let totalFICA: Decimal

    var socialSecurityRate: Decimal { 0.062 }
    var medicareRate: Decimal { 0.0145 }
    var additionalMedicareRate: Decimal { 0.009 }
}

/// Tax bracket definition
struct TaxBracket: Codable, Equatable, Identifiable {
    let id: UUID
    let floor: Decimal
    let ceiling: Decimal?       // nil for top bracket
    let rate: Decimal
    let baseTax: Decimal

    init(floor: Decimal, ceiling: Decimal?, rate: Decimal, baseTax: Decimal) {
        self.id = UUID()
        self.floor = floor
        self.ceiling = ceiling
        self.rate = rate
        self.baseTax = baseTax
    }
}

/// Amount paid in a specific bracket
struct BracketAmount: Codable, Equatable {
    let bracket: TaxBracket
    let taxableInBracket: Decimal
    let taxPaid: Decimal
}

/// Effective tax rates summary
struct EffectiveRates: Codable, Equatable {
    let federal: Decimal
    let state: Decimal
    let fica: Decimal
    let total: Decimal

    var federalPercent: Decimal { federal * 100 }
    var statePercent: Decimal { state * 100 }
    var ficaPercent: Decimal { fica * 100 }
    var totalPercent: Decimal { total * 100 }
}
```

### US States

```swift
import Foundation

/// All US states with tax-relevant properties
enum USState: String, Codable, CaseIterable, Identifiable {
    case alabama = "AL"
    case alaska = "AK"
    case arizona = "AZ"
    case arkansas = "AR"
    case california = "CA"
    case colorado = "CO"
    case connecticut = "CT"
    case delaware = "DE"
    case florida = "FL"
    case georgia = "GA"
    case hawaii = "HI"
    case idaho = "ID"
    case illinois = "IL"
    case indiana = "IN"
    case iowa = "IA"
    case kansas = "KS"
    case kentucky = "KY"
    case louisiana = "LA"
    case maine = "ME"
    case maryland = "MD"
    case massachusetts = "MA"
    case michigan = "MI"
    case minnesota = "MN"
    case mississippi = "MS"
    case missouri = "MO"
    case montana = "MT"
    case nebraska = "NE"
    case nevada = "NV"
    case newHampshire = "NH"
    case newJersey = "NJ"
    case newMexico = "NM"
    case newYork = "NY"
    case northCarolina = "NC"
    case northDakota = "ND"
    case ohio = "OH"
    case oklahoma = "OK"
    case oregon = "OR"
    case pennsylvania = "PA"
    case rhodeIsland = "RI"
    case southCarolina = "SC"
    case southDakota = "SD"
    case tennessee = "TN"
    case texas = "TX"
    case utah = "UT"
    case vermont = "VT"
    case virginia = "VA"
    case washington = "WA"
    case washingtonDC = "DC"
    case westVirginia = "WV"
    case wisconsin = "WI"
    case wyoming = "WY"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alabama: return "Alabama"
        case .alaska: return "Alaska"
        case .arizona: return "Arizona"
        case .arkansas: return "Arkansas"
        case .california: return "California"
        case .colorado: return "Colorado"
        case .connecticut: return "Connecticut"
        case .delaware: return "Delaware"
        case .florida: return "Florida"
        case .georgia: return "Georgia"
        case .hawaii: return "Hawaii"
        case .idaho: return "Idaho"
        case .illinois: return "Illinois"
        case .indiana: return "Indiana"
        case .iowa: return "Iowa"
        case .kansas: return "Kansas"
        case .kentucky: return "Kentucky"
        case .louisiana: return "Louisiana"
        case .maine: return "Maine"
        case .maryland: return "Maryland"
        case .massachusetts: return "Massachusetts"
        case .michigan: return "Michigan"
        case .minnesota: return "Minnesota"
        case .mississippi: return "Mississippi"
        case .missouri: return "Missouri"
        case .montana: return "Montana"
        case .nebraska: return "Nebraska"
        case .nevada: return "Nevada"
        case .newHampshire: return "New Hampshire"
        case .newJersey: return "New Jersey"
        case .newMexico: return "New Mexico"
        case .newYork: return "New York"
        case .northCarolina: return "North Carolina"
        case .northDakota: return "North Dakota"
        case .ohio: return "Ohio"
        case .oklahoma: return "Oklahoma"
        case .oregon: return "Oregon"
        case .pennsylvania: return "Pennsylvania"
        case .rhodeIsland: return "Rhode Island"
        case .southCarolina: return "South Carolina"
        case .southDakota: return "South Dakota"
        case .tennessee: return "Tennessee"
        case .texas: return "Texas"
        case .utah: return "Utah"
        case .vermont: return "Vermont"
        case .virginia: return "Virginia"
        case .washington: return "Washington"
        case .washingtonDC: return "Washington D.C."
        case .westVirginia: return "West Virginia"
        case .wisconsin: return "Wisconsin"
        case .wyoming: return "Wyoming"
        }
    }

    /// States with no income tax
    var hasNoIncomeTax: Bool {
        switch self {
        case .alaska, .florida, .nevada, .newHampshire,
             .southDakota, .tennessee, .texas, .washington, .wyoming:
            return true
        default:
            return false
        }
    }

    /// States with flat tax rate
    var hasFlatTax: Bool {
        switch self {
        case .colorado, .illinois, .indiana, .kentucky, .massachusetts,
             .michigan, .newHampshire, .northCarolina, .pennsylvania, .utah:
            return true
        default:
            return false
        }
    }

    /// States with local income taxes
    var hasLocalTax: Bool {
        switch self {
        case .alabama, .colorado, .delaware, .indiana, .iowa, .kentucky,
             .maryland, .michigan, .missouri, .newJersey, .newYork, .ohio,
             .oregon, .pennsylvania, .westVirginia:
            return true
        default:
            return false
        }
    }

    /// States with SDI (State Disability Insurance)
    var hasSDI: Bool {
        switch self {
        case .california, .hawaii, .newJersey, .newYork, .rhodeIsland:
            return true
        default:
            return false
        }
    }
}
```

### Deductions

```swift
import Foundation

/// Types of deductions
enum DeductionType: String, Codable, CaseIterable {
    case healthInsurance = "health_insurance"
    case dentalInsurance = "dental_insurance"
    case visionInsurance = "vision_insurance"
    case hsa = "hsa"
    case fsa = "fsa"
    case commuter = "commuter"
    case lifeInsurance = "life_insurance"
    case disabilityInsurance = "disability_insurance"
    case unionDues = "union_dues"
    case other = "other"

    var displayName: String {
        switch self {
        case .healthInsurance: return "Health Insurance"
        case .dentalInsurance: return "Dental Insurance"
        case .visionInsurance: return "Vision Insurance"
        case .hsa: return "HSA Contribution"
        case .fsa: return "FSA Contribution"
        case .commuter: return "Commuter Benefits"
        case .lifeInsurance: return "Life Insurance"
        case .disabilityInsurance: return "Disability Insurance"
        case .unionDues: return "Union Dues"
        case .other: return "Other"
        }
    }

    var isPreTax: Bool {
        switch self {
        case .healthInsurance, .dentalInsurance, .visionInsurance,
             .hsa, .fsa, .commuter:
            return true
        default:
            return false
        }
    }
}

/// Individual deduction entry
struct Deduction: Identifiable, Codable, Equatable {
    let id: UUID
    var type: DeductionType
    var name: String
    var amount: Decimal
    var frequency: DeductionFrequency
    var isPreTax: Bool

    var annualAmount: Decimal {
        switch frequency {
        case .perPaycheck(let periods):
            return amount * Decimal(periods)
        case .monthly:
            return amount * 12
        case .annual:
            return amount
        }
    }

    init(
        id: UUID = UUID(),
        type: DeductionType,
        name: String? = nil,
        amount: Decimal,
        frequency: DeductionFrequency = .monthly,
        isPreTax: Bool? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name ?? type.displayName
        self.amount = amount
        self.frequency = frequency
        self.isPreTax = isPreTax ?? type.isPreTax
    }
}

/// How often a deduction is applied
enum DeductionFrequency: Codable, Equatable {
    case perPaycheck(periodsPerYear: Int)
    case monthly
    case annual
}

/// Summary of all deductions
struct DeductionsSummary: Codable, Equatable {
    let preTax: Decimal
    let postTax: Decimal
    let retirement: RetirementContributions?

    var total: Decimal {
        preTax + postTax + (retirement?.totalContributions ?? 0)
    }
}
```

### Retirement Contributions

```swift
import Foundation

/// Retirement contribution details
struct RetirementContributions: Codable, Equatable {
    var traditional401k: Decimal
    var roth401k: Decimal
    var employerMatch: Decimal
    var matchPercentage: Decimal      // e.g., 0.03 for 3%
    var vestingPercentage: Decimal    // e.g., 1.0 for fully vested

    var totalContributions: Decimal {
        traditional401k + roth401k
    }

    var totalWithMatch: Decimal {
        totalContributions + vestedEmployerMatch
    }

    var vestedEmployerMatch: Decimal {
        employerMatch * vestingPercentage
    }

    init(
        traditional401k: Decimal = 0,
        roth401k: Decimal = 0,
        employerMatch: Decimal = 0,
        matchPercentage: Decimal = 0,
        vestingPercentage: Decimal = 1.0
    ) {
        self.traditional401k = traditional401k
        self.roth401k = roth401k
        self.employerMatch = employerMatch
        self.matchPercentage = matchPercentage
        self.vestingPercentage = vestingPercentage
    }
}

/// Retirement contribution limits (updated annually)
struct RetirementLimits: Codable {
    let year: Int
    let limit401k: Decimal
    let catchUp401k: Decimal          // Age 50+
    let catchUpAge: Int
    let limitIRA: Decimal
    let catchUpIRA: Decimal

    /// 2024 limits
    static let defaults2024 = RetirementLimits(
        year: 2024,
        limit401k: 23000,
        catchUp401k: 7500,
        catchUpAge: 50,
        limitIRA: 7000,
        catchUpIRA: 1000
    )

    func maxContribution(age: Int, is401k: Bool) -> Decimal {
        if is401k {
            return age >= catchUpAge ? limit401k + catchUp401k : limit401k
        } else {
            return age >= catchUpAge ? limitIRA + catchUpIRA : limitIRA
        }
    }
}
```

### Expenses

```swift
import Foundation

/// Expense category based on PRD structure
enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case debt = "debt"
    case home = "home"
    case necessities = "necessities"
    case tech = "tech"
    case entertainment = "entertainment"
    case vehicle = "vehicle"
    case education = "education"
    case finance = "finance"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .debt: return "Debt/Fixed"
        case .home: return "Home"
        case .necessities: return "Necessities"
        case .tech: return "Tech/Tools"
        case .entertainment: return "Entertainment"
        case .vehicle: return "Vehicle"
        case .education: return "Education"
        case .finance: return "Finance"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .debt: return "creditcard.fill"
        case .home: return "house.fill"
        case .necessities: return "cart.fill"
        case .tech: return "laptopcomputer"
        case .entertainment: return "tv.fill"
        case .vehicle: return "car.fill"
        case .education: return "book.fill"
        case .finance: return "banknote.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    /// Recommended percentage of net income
    var recommendedPercentage: Decimal? {
        switch self {
        case .debt: return 0.30      // Housing 30% rule
        case .home: return 0.05
        case .necessities: return 0.15
        case .vehicle: return 0.10
        default: return nil
        }
    }
}

/// Individual expense entry
struct Expense: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var category: ExpenseCategory
    var amount: Decimal
    var frequency: ExpenseFrequency
    var isShared: Bool               // For household mode
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    var annualAmount: Decimal {
        switch frequency {
        case .daily:
            return amount * 365
        case .weekly:
            return amount * 52
        case .biWeekly:
            return amount * 26
        case .monthly:
            return amount * 12
        case .quarterly:
            return amount * 4
        case .annual:
            return amount
        case .oneTime:
            return amount
        }
    }

    var monthlyAmount: Decimal {
        annualAmount / 12
    }

    init(
        id: UUID = UUID(),
        name: String,
        category: ExpenseCategory,
        amount: Decimal,
        frequency: ExpenseFrequency = .monthly,
        isShared: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.amount = amount
        self.frequency = frequency
        self.isShared = isShared
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

/// How often an expense occurs
enum ExpenseFrequency: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case biWeekly = "bi_weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case annual = "annual"
    case oneTime = "one_time"

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .biWeekly: return "Bi-Weekly"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .annual: return "Annual"
        case .oneTime: return "One-Time"
        }
    }
}

/// Category-level expense summary
struct ExpenseCategorySummary: Identifiable, Equatable {
    let id: String
    let category: ExpenseCategory
    let totalAnnual: Decimal
    let totalMonthly: Decimal
    let expenses: [Expense]
    let percentageOfNet: Decimal

    var isOverRecommended: Bool {
        guard let recommended = category.recommendedPercentage else { return false }
        return percentageOfNet > recommended
    }
}
```

### Household

```swift
import Foundation

/// Household configuration for dual-income/expense sharing
struct Household: Codable, Equatable {
    var partner: PartnerProfile
    var sharedExpenses: [Expense]
    var splitMethod: SplitMethod
    var splitOverrides: [UUID: SplitOverride]  // Override per expense

    /// Calculate split for the primary user
    func primarySplit(primaryNet: Decimal) -> HouseholdSplit {
        let totalNet = primaryNet + partner.netIncome
        let primaryRatio = totalNet > 0 ? primaryNet / totalNet : 0.5

        let sharedTotal = sharedExpenses.reduce(Decimal.zero) { $0 + $1.monthlyAmount }

        switch splitMethod {
        case .proportional:
            return HouseholdSplit(
                primaryRatio: primaryRatio,
                partnerRatio: 1 - primaryRatio,
                primaryAmount: sharedTotal * primaryRatio,
                partnerAmount: sharedTotal * (1 - primaryRatio)
            )
        case .equal:
            return HouseholdSplit(
                primaryRatio: 0.5,
                partnerRatio: 0.5,
                primaryAmount: sharedTotal * 0.5,
                partnerAmount: sharedTotal * 0.5
            )
        case .custom(let primaryPercent):
            return HouseholdSplit(
                primaryRatio: primaryPercent,
                partnerRatio: 1 - primaryPercent,
                primaryAmount: sharedTotal * primaryPercent,
                partnerAmount: sharedTotal * (1 - primaryPercent)
            )
        }
    }
}

/// Partner's simplified profile
struct PartnerProfile: Codable, Equatable {
    var name: String
    var grossIncome: Decimal
    var netIncome: Decimal
    var state: USState?

    init(
        name: String = "Partner",
        grossIncome: Decimal = 0,
        netIncome: Decimal = 0,
        state: USState? = nil
    ) {
        self.name = name
        self.grossIncome = grossIncome
        self.netIncome = netIncome
        self.state = state
    }
}

/// How to split shared expenses
enum SplitMethod: Codable, Equatable {
    case proportional          // Based on income ratio
    case equal                 // 50/50
    case custom(Decimal)       // Custom primary percentage

    var displayName: String {
        switch self {
        case .proportional: return "Proportional to Income"
        case .equal: return "Equal (50/50)"
        case .custom(let pct): return "Custom (\(Int(pct * 100))%)"
        }
    }
}

/// Override for specific expense
struct SplitOverride: Codable, Equatable {
    let expenseId: UUID
    let method: SplitMethod
}

/// Calculated household split
struct HouseholdSplit: Equatable {
    let primaryRatio: Decimal
    let partnerRatio: Decimal
    let primaryAmount: Decimal
    let partnerAmount: Decimal

    var primaryPercent: Decimal { primaryRatio * 100 }
    var partnerPercent: Decimal { partnerRatio * 100 }
}
```

### Scenarios

```swift
import Foundation

/// Scenario for what-if analysis
struct Scenario: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var type: ScenarioType
    var changes: ScenarioChanges
    var createdAt: Date
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        name: String,
        type: ScenarioType,
        changes: ScenarioChanges
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.changes = changes
        self.createdAt = Date()
        self.isFavorite = false
    }
}

/// Types of scenarios
enum ScenarioType: String, Codable, CaseIterable {
    case raise = "raise"
    case stateMove = "state_move"
    case retirement = "retirement"
    case newJob = "new_job"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .raise: return "Salary Raise"
        case .stateMove: return "Move to New State"
        case .retirement: return "Retirement Change"
        case .newJob: return "New Job"
        case .custom: return "Custom Scenario"
        }
    }

    var icon: String {
        switch self {
        case .raise: return "arrow.up.circle.fill"
        case .stateMove: return "map.fill"
        case .retirement: return "building.columns.fill"
        case .newJob: return "briefcase.fill"
        case .custom: return "slider.horizontal.3"
        }
    }
}

/// Changes applied in a scenario
struct ScenarioChanges: Codable, Equatable {
    var newGrossIncome: Decimal?
    var newState: USState?
    var newFilingStatus: FilingStatus?
    var newRetirementContributions: RetirementContributions?
    var additionalDeductions: [Deduction]?
    var removedDeductionIds: [UUID]?
}

/// Comparison between base and scenario
struct ScenarioComparison: Equatable {
    let base: TaxCalculationResult
    let scenario: TaxCalculationResult
    let netDifference: Decimal
    let monthlyDifference: Decimal

    var netDifferencePercent: Decimal {
        guard base.income.net > 0 else { return 0 }
        return (netDifference / base.income.net) * 100
    }

    var isPositive: Bool {
        netDifference > 0
    }
}
```

---

## 2. Core Data Schema

### Entity Definitions

```swift
// MARK: - Core Data Model (TakeHome.xcdatamodeld)

/*
 Entity: FinancialProfileEntity
 Attributes:
   - id: UUID (required)
   - name: String (required)
   - createdAt: Date (required)
   - updatedAt: Date (required)
   - grossAnnualSalary: Decimal (required)
   - bonuses: Decimal (optional)
   - otherIncome: Decimal (optional)
   - payFrequency: String (required)
   - stateCode: String (required)
   - filingStatus: String (required)
   - isActive: Bool (required)
   - lastSyncedAt: Date (optional)
   - householdData: Data (optional, JSON)
 Relationships:
   - deductions: [DeductionEntity] (to-many, cascade delete)
   - expenses: [ExpenseEntity] (to-many, cascade delete)
   - retirementContribution: RetirementContributionEntity (to-one, cascade delete)

 Entity: DeductionEntity
 Attributes:
   - id: UUID (required)
   - type: String (required)
   - name: String (required)
   - amount: Decimal (required)
   - frequencyType: String (required)
   - frequencyValue: Int32 (optional)
   - isPreTax: Bool (required)
 Relationships:
   - profile: FinancialProfileEntity (to-one, nullify)

 Entity: ExpenseEntity
 Attributes:
   - id: UUID (required)
   - name: String (required)
   - category: String (required)
   - amount: Decimal (required)
   - frequency: String (required)
   - isShared: Bool (required)
   - notes: String (optional)
   - createdAt: Date (required)
   - updatedAt: Date (required)
 Relationships:
   - profile: FinancialProfileEntity (to-one, nullify)

 Entity: RetirementContributionEntity
 Attributes:
   - id: UUID (required)
   - traditional401k: Decimal (required)
   - roth401k: Decimal (required)
   - employerMatch: Decimal (required)
   - matchPercentage: Decimal (required)
   - vestingPercentage: Decimal (required)
 Relationships:
   - profile: FinancialProfileEntity (to-one, nullify)

 Entity: ScenarioEntity
 Attributes:
   - id: UUID (required)
   - name: String (required)
   - type: String (required)
   - changesData: Data (required, JSON)
   - createdAt: Date (required)
   - isFavorite: Bool (required)
 Relationships:
   - profile: FinancialProfileEntity (to-one, nullify)
*/
```

### Core Data Stack

```swift
import CoreData
import Combine

protocol CoreDataStackProtocol {
    var viewContext: NSManagedObjectContext { get }
    var backgroundContext: NSManagedObjectContext { get }

    func save() throws
    func observe<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate?
    ) -> AnyPublisher<[T], Error>
}

final class CoreDataStack: CoreDataStackProtocol {

    static let shared = CoreDataStack(modelName: "TakeHome")

    private let container: NSPersistentCloudKitContainer

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    var backgroundContext: NSManagedObjectContext {
        container.newBackgroundContext()
    }

    init(modelName: String) {
        container = NSPersistentCloudKitContainer(name: modelName)

        // Configure for CloudKit sync
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No persistent store description found")
        }

        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func save() throws {
        let context = viewContext
        if context.hasChanges {
            try context.save()
        }
    }

    func observe<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate? = nil
    ) -> AnyPublisher<[T], Error> {
        let request = T.fetchRequest() as! NSFetchRequest<T>
        request.predicate = predicate
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]

        return NSFetchedResultsControllerPublisher(
            fetchRequest: request,
            context: viewContext
        )
        .eraseToAnyPublisher()
    }
}

// In-memory stack for testing
#if DEBUG
final class InMemoryCoreDataStack: CoreDataStackProtocol {
    private let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext { container.viewContext }
    var backgroundContext: NSManagedObjectContext { container.newBackgroundContext() }

    init(modelName: String) {
        container = NSPersistentContainer(name: modelName)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("In-memory store failed: \(error)")
            }
        }
    }

    func save() throws {
        if viewContext.hasChanges {
            try viewContext.save()
        }
    }

    func observe<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate?
    ) -> AnyPublisher<[T], Error> {
        Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
}
#endif
```

### Entity Conversions

```swift
import CoreData

// MARK: - FinancialProfile <-> Entity

extension FinancialProfile {
    init(entity: FinancialProfileEntity) {
        self.id = entity.id ?? UUID()
        self.name = entity.name ?? "Profile"
        self.createdAt = entity.createdAt ?? Date()
        self.updatedAt = entity.updatedAt ?? Date()

        self.income = Income(
            grossAnnualSalary: entity.grossAnnualSalary as Decimal? ?? 0,
            bonuses: entity.bonuses as Decimal? ?? 0,
            otherIncome: entity.otherIncome as Decimal? ?? 0
        )

        self.payFrequency = PayFrequency(rawValue: entity.payFrequency ?? "") ?? .biWeekly
        self.state = USState(rawValue: entity.stateCode ?? "") ?? .california
        self.filingStatus = FilingStatus(rawValue: entity.filingStatus ?? "") ?? .single

        self.preTaxDeductions = (entity.deductions as? Set<DeductionEntity>)?
            .filter { $0.isPreTax }
            .map { Deduction(entity: $0) } ?? []

        self.postTaxDeductions = (entity.deductions as? Set<DeductionEntity>)?
            .filter { !$0.isPreTax }
            .map { Deduction(entity: $0) } ?? []

        if let retirementEntity = entity.retirementContribution {
            self.retirementContributions = RetirementContributions(entity: retirementEntity)
        } else {
            self.retirementContributions = RetirementContributions()
        }

        self.expenses = (entity.expenses as? Set<ExpenseEntity>)?
            .map { Expense(entity: $0) } ?? []

        if let householdData = entity.householdData {
            self.household = try? JSONDecoder().decode(Household.self, from: householdData)
        } else {
            self.household = nil
        }

        self.isActive = entity.isActive
        self.lastSyncedAt = entity.lastSyncedAt
    }

    func populate(entity: FinancialProfileEntity) {
        entity.id = id
        entity.name = name
        entity.createdAt = createdAt
        entity.updatedAt = Date()

        entity.grossAnnualSalary = income.grossAnnualSalary as NSDecimalNumber
        entity.bonuses = income.bonuses as NSDecimalNumber
        entity.otherIncome = income.otherIncome as NSDecimalNumber

        entity.payFrequency = payFrequency.rawValue
        entity.stateCode = state.rawValue
        entity.filingStatus = filingStatus.rawValue
        entity.isActive = isActive
        entity.lastSyncedAt = lastSyncedAt

        if let household = household {
            entity.householdData = try? JSONEncoder().encode(household)
        }
    }
}

// MARK: - Deduction <-> Entity

extension Deduction {
    init(entity: DeductionEntity) {
        self.id = entity.id ?? UUID()
        self.type = DeductionType(rawValue: entity.type ?? "") ?? .other
        self.name = entity.name ?? ""
        self.amount = entity.amount as Decimal? ?? 0
        self.isPreTax = entity.isPreTax

        if let freqType = entity.frequencyType {
            switch freqType {
            case "per_paycheck":
                self.frequency = .perPaycheck(periodsPerYear: Int(entity.frequencyValue))
            case "monthly":
                self.frequency = .monthly
            case "annual":
                self.frequency = .annual
            default:
                self.frequency = .monthly
            }
        } else {
            self.frequency = .monthly
        }
    }
}

// MARK: - Expense <-> Entity

extension Expense {
    init(entity: ExpenseEntity) {
        self.id = entity.id ?? UUID()
        self.name = entity.name ?? ""
        self.category = ExpenseCategory(rawValue: entity.category ?? "") ?? .other
        self.amount = entity.amount as Decimal? ?? 0
        self.frequency = ExpenseFrequency(rawValue: entity.frequency ?? "") ?? .monthly
        self.isShared = entity.isShared
        self.notes = entity.notes
        self.createdAt = entity.createdAt ?? Date()
        self.updatedAt = entity.updatedAt ?? Date()
    }
}

// MARK: - RetirementContributions <-> Entity

extension RetirementContributions {
    init(entity: RetirementContributionEntity) {
        self.traditional401k = entity.traditional401k as Decimal? ?? 0
        self.roth401k = entity.roth401k as Decimal? ?? 0
        self.employerMatch = entity.employerMatch as Decimal? ?? 0
        self.matchPercentage = entity.matchPercentage as Decimal? ?? 0
        self.vestingPercentage = entity.vestingPercentage as Decimal? ?? 1.0
    }
}
```

---

## 3. CloudKit Record Types

### Record Definitions

```swift
import CloudKit

/// CloudKit record type constants
enum CKRecordTypes {
    static let financialProfile = "FinancialProfile"
    static let deduction = "Deduction"
    static let expense = "Expense"
    static let retirementContribution = "RetirementContribution"
    static let scenario = "Scenario"
}

/// CloudKit field keys
enum CKFieldKeys {
    enum Profile {
        static let name = "name"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
        static let grossAnnualSalary = "grossAnnualSalary"
        static let bonuses = "bonuses"
        static let otherIncome = "otherIncome"
        static let payFrequency = "payFrequency"
        static let stateCode = "stateCode"
        static let filingStatus = "filingStatus"
        static let isActive = "isActive"
        static let householdData = "householdData"
    }

    enum Deduction {
        static let type = "type"
        static let name = "name"
        static let amount = "amount"
        static let frequencyType = "frequencyType"
        static let frequencyValue = "frequencyValue"
        static let isPreTax = "isPreTax"
        static let profile = "profile"
    }

    enum Expense {
        static let name = "name"
        static let category = "category"
        static let amount = "amount"
        static let frequency = "frequency"
        static let isShared = "isShared"
        static let notes = "notes"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
        static let profile = "profile"
    }
}
```

### CloudKit Sync Service

```swift
import CloudKit
import Combine
import CoreData

protocol CloudKitSyncProtocol {
    func sync(entity: NSManagedObject)
    func delete(recordID: String)
    func fetchRemoteChanges() -> AnyPublisher<Void, Error>
}

final class CloudKitSyncService: CloudKitSyncProtocol {

    private let container: CKContainer
    private let database: CKDatabase
    private let coreDataStack: CoreDataStackProtocol

    init(container coreDataStack: CoreDataStackProtocol) {
        self.container = CKContainer(identifier: "iCloud.com.takehome.app")
        self.database = container.privateCloudDatabase
        self.coreDataStack = coreDataStack
    }

    func sync(entity: NSManagedObject) {
        // Convert to CloudKit record and save
        guard let record = convertToRecord(entity) else { return }

        database.save(record) { savedRecord, error in
            if let error = error {
                print("CloudKit sync failed: \(error)")
            }
        }
    }

    func delete(recordID: String) {
        let recordID = CKRecord.ID(recordName: recordID)
        database.delete(withRecordID: recordID) { _, error in
            if let error = error {
                print("CloudKit delete failed: \(error)")
            }
        }
    }

    func fetchRemoteChanges() -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            // Fetch changes using CKFetchRecordZoneChangesOperation
            // Apply changes to Core Data
            promise(.success(()))
        }
        .eraseToAnyPublisher()
    }

    private func convertToRecord(_ entity: NSManagedObject) -> CKRecord? {
        // Implementation depends on entity type
        return nil
    }
}
```

---

## 4. Remote Config Schema

### Tax Data JSON Structure

```swift
import Foundation

/// Remote tax configuration root
struct RemoteTaxConfig: Codable {
    let version: String
    let effectiveDate: String
    let expirationDate: String?
    let federal: FederalTaxConfig
    let fica: FICAConfig
    let states: [String: StateTaxConfig]
    let retirement: RetirementConfig
}

/// Federal tax configuration
struct FederalTaxConfig: Codable {
    let year: Int
    let standardDeduction: [String: Decimal]  // Keyed by FilingStatus
    let brackets: [String: [TaxBracketConfig]]  // Keyed by FilingStatus
}

/// Tax bracket from remote config
struct TaxBracketConfig: Codable {
    let floor: Decimal
    let ceiling: Decimal?
    let rate: Decimal
    let baseTax: Decimal
}

/// FICA configuration
struct FICAConfig: Codable {
    let socialSecurityRate: Decimal
    let socialSecurityWageBase: Decimal
    let medicareRate: Decimal
    let additionalMedicareRate: Decimal
    let additionalMedicareThreshold: [String: Decimal]  // By filing status
}

/// State tax configuration
struct StateTaxConfig: Codable {
    let stateCode: String
    let stateName: String
    let taxType: StateTaxType
    let flatRate: Decimal?
    let brackets: [String: [TaxBracketConfig]]?  // By filing status
    let standardDeduction: [String: Decimal]?
    let personalExemption: Decimal?
    let localTaxInfo: LocalTaxInfo?
    let sdiRate: Decimal?
    let sdiWageBase: Decimal?
    let specialRules: [String]?
}

/// State tax type
enum StateTaxType: String, Codable {
    case noTax = "no_tax"
    case flatRate = "flat_rate"
    case progressive = "progressive"
}

/// Local tax information
struct LocalTaxInfo: Codable {
    let hasLocalTax: Bool
    let averageRate: Decimal?
    let majorCities: [CityTaxInfo]?
}

/// City-specific tax info
struct CityTaxInfo: Codable {
    let city: String
    let rate: Decimal
}

/// Retirement limits configuration
struct RetirementConfig: Codable {
    let year: Int
    let limit401k: Decimal
    let catchUp401k: Decimal
    let catchUpAge: Int
    let limitIRA: Decimal
    let catchUpIRA: Decimal
    let limit403b: Decimal
    let limit457: Decimal
}
```

### Example Tax Data JSON

```json
{
  "version": "2024.1.0",
  "effectiveDate": "2024-01-01",
  "expirationDate": "2024-12-31",
  "federal": {
    "year": 2024,
    "standardDeduction": {
      "single": 14600,
      "married_filing_jointly": 29200,
      "married_filing_separately": 14600,
      "head_of_household": 21900
    },
    "brackets": {
      "single": [
        { "floor": 0, "ceiling": 11600, "rate": 0.10, "baseTax": 0 },
        { "floor": 11600, "ceiling": 47150, "rate": 0.12, "baseTax": 1160 },
        { "floor": 47150, "ceiling": 100525, "rate": 0.22, "baseTax": 5426 },
        { "floor": 100525, "ceiling": 191950, "rate": 0.24, "baseTax": 17168.50 },
        { "floor": 191950, "ceiling": 243725, "rate": 0.32, "baseTax": 39110.50 },
        { "floor": 243725, "ceiling": 609350, "rate": 0.35, "baseTax": 55678.50 },
        { "floor": 609350, "ceiling": null, "rate": 0.37, "baseTax": 183647.25 }
      ],
      "married_filing_jointly": [
        { "floor": 0, "ceiling": 23200, "rate": 0.10, "baseTax": 0 },
        { "floor": 23200, "ceiling": 94300, "rate": 0.12, "baseTax": 2320 },
        { "floor": 94300, "ceiling": 201050, "rate": 0.22, "baseTax": 10852 },
        { "floor": 201050, "ceiling": 383900, "rate": 0.24, "baseTax": 34337 },
        { "floor": 383900, "ceiling": 487450, "rate": 0.32, "baseTax": 78221 },
        { "floor": 487450, "ceiling": 731200, "rate": 0.35, "baseTax": 111357 },
        { "floor": 731200, "ceiling": null, "rate": 0.37, "baseTax": 196669.50 }
      ]
    }
  },
  "fica": {
    "socialSecurityRate": 0.062,
    "socialSecurityWageBase": 168600,
    "medicareRate": 0.0145,
    "additionalMedicareRate": 0.009,
    "additionalMedicareThreshold": {
      "single": 200000,
      "married_filing_jointly": 250000,
      "married_filing_separately": 125000,
      "head_of_household": 200000
    }
  },
  "retirement": {
    "year": 2024,
    "limit401k": 23000,
    "catchUp401k": 7500,
    "catchUpAge": 50,
    "limitIRA": 7000,
    "catchUpIRA": 1000,
    "limit403b": 23000,
    "limit457": 23000
  }
}
```

---

## Summary

| Model Category | Purpose | Persistence |
|---------------|---------|-------------|
| **Domain Models** | Business logic, calculations | In-memory |
| **Core Data Entities** | Local persistence | SQLite + CloudKit |
| **CloudKit Records** | Cross-device sync | iCloud |
| **Remote Config** | Tax data updates | JSON API |

All models use `Decimal` for financial precision and are designed for offline-first operation with eventual consistency via CloudKit sync.
