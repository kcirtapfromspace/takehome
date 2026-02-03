import Foundation

// MARK: - Tax Calculation Input
/// Input for tax calculations - maps to Rust FFI
struct TaxCalculationInput: Codable, Equatable {
    var grossIncome: Decimal
    var filingStatus: FilingStatus
    var state: USState
    var preTaxDeductions: Decimal
    var postTaxDeductions: Decimal
    var traditional401k: Decimal
    var roth401k: Decimal

    init(
        grossIncome: Decimal = 0,
        filingStatus: FilingStatus = .single,
        state: USState = .california,
        preTaxDeductions: Decimal = 0,
        postTaxDeductions: Decimal = 0,
        traditional401k: Decimal = 0,
        roth401k: Decimal = 0
    ) {
        self.grossIncome = grossIncome
        self.filingStatus = filingStatus
        self.state = state
        self.preTaxDeductions = preTaxDeductions
        self.postTaxDeductions = postTaxDeductions
        self.traditional401k = traditional401k
        self.roth401k = roth401k
    }
}

// MARK: - Tax Calculation Result
/// Complete tax calculation result
struct TaxCalculationResult: Equatable {
    // Income
    var grossAnnual: Decimal
    var netAnnual: Decimal
    var timeframes: TimeframeIncome
    var takeHomePercentage: Decimal

    // Federal
    var federalTax: Decimal
    var federalEffectiveRate: Decimal
    var federalMarginalRate: Decimal

    // State
    var stateCode: String
    var stateIncomeTax: Decimal
    var stateLocalTax: Decimal
    var stateSDI: Decimal
    var stateTotalTax: Decimal

    // FICA
    var socialSecurity: Decimal
    var medicare: Decimal
    var additionalMedicare: Decimal
    var ficaTotal: Decimal

    // Totals
    var totalTaxes: Decimal
    var totalEffectiveRate: Decimal

    // Convenience computed properties
    var netMonthly: Decimal { timeframes.monthly }
    var netBiWeekly: Decimal { timeframes.biWeekly }
    var netWeekly: Decimal { timeframes.weekly }
    var netDaily: Decimal { timeframes.daily }
    var netHourly: Decimal { timeframes.hourly }
}

// MARK: - Timeframe Income
/// Income broken down by time period
struct TimeframeIncome: Equatable {
    var annual: Decimal
    var monthly: Decimal
    var biWeekly: Decimal
    var weekly: Decimal
    var daily: Decimal
    var hourly: Decimal

    init(
        annual: Decimal = 0,
        monthly: Decimal = 0,
        biWeekly: Decimal = 0,
        weekly: Decimal = 0,
        daily: Decimal = 0,
        hourly: Decimal = 0
    ) {
        self.annual = annual
        self.monthly = monthly
        self.biWeekly = biWeekly
        self.weekly = weekly
        self.daily = daily
        self.hourly = hourly
    }

    /// Create from annual amount using standard conversion factors
    static func fromAnnual(_ annual: Decimal) -> TimeframeIncome {
        TimeframeIncome(
            annual: annual,
            monthly: annual / 12,
            biWeekly: annual / 26,
            weekly: annual / 52,
            daily: annual / 260,
            hourly: annual / 2080
        )
    }
}

// MARK: - Filing Status
enum FilingStatus: String, Codable, CaseIterable, Identifiable {
    case single
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
        case .qualifyingWidower: return "Qualifying Widower"
        }
    }
}

// MARK: - US State
enum USState: String, Codable, CaseIterable, Identifiable {
    case alabama = "AL"
    case alaska = "AK"
    case arizona = "AZ"
    case arkansas = "AR"
    case california = "CA"
    case colorado = "CO"
    case connecticut = "CT"
    case delaware = "DE"
    case districtOfColumbia = "DC"
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
        case .districtOfColumbia: return "District of Columbia"
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
        case .westVirginia: return "West Virginia"
        case .wisconsin: return "Wisconsin"
        case .wyoming: return "Wyoming"
        }
    }

    /// States with no state income tax
    var hasNoIncomeTax: Bool {
        switch self {
        case .alaska, .florida, .nevada, .newHampshire, .southDakota, .tennessee, .texas, .washington, .wyoming:
            return true
        default:
            return false
        }
    }
}
