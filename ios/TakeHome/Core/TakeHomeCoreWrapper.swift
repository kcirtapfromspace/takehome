import Foundation

// MARK: - Protocol
/// Protocol defining the interface for tax calculations
/// This allows for dependency injection and easy mocking in tests
protocol TakeHomeCoreProtocol {
    func computeTaxes(input: TaxCalculationInput) throws -> TaxCalculationResult
    func computeScenarioComparison(base: TaxCalculationInput, scenario: TaxCalculationInput) throws -> ScenarioComparison
    func computeTimeframes(annual: Decimal) throws -> TimeframeIncome
    func computeHouseholdSplit(
        primaryNet: Decimal,
        partnerNet: Decimal,
        sharedExpense: Decimal,
        method: SplitMethod
    ) throws -> HouseholdSplit

    var allStateCodes: [USState] { get }
    var allFilingStatuses: [FilingStatus] { get }
    var version: String { get }
    var taxYear: UInt32 { get }

    func checkStateHasNoIncomeTax(_ state: USState) -> Bool
}

// MARK: - Implementation
/// Wrapper around the Rust FFI for Swift-friendly API
final class TakeHomeCoreWrapper: TakeHomeCoreProtocol {

    // MARK: - Properties
    var allStateCodes: [USState] {
        getAllStateCodes().compactMap { USState(rawValue: $0) }
    }

    var allFilingStatuses: [FilingStatus] {
        getAllFilingStatuses().compactMap { FilingStatus(rawValue: $0) }
    }

    var version: String {
        getVersion()
    }

    var taxYear: UInt32 {
        getTaxYear()
    }

    // MARK: - Tax Calculations
    func computeTaxes(input: TaxCalculationInput) throws -> TaxCalculationResult {
        let ffiResult = try calculateTaxes(
            grossIncome: input.grossIncome.description,
            filingStatus: input.filingStatus.rawValue,
            stateCode: input.state.rawValue,
            preTaxDeductions: input.preTaxDeductions.description,
            postTaxDeductions: input.postTaxDeductions.description,
            traditional401k: input.traditional401k.description,
            roth401k: input.roth401k.description
        )
        return try TaxCalculationResult(from: ffiResult)
    }

    func computeScenarioComparison(base: TaxCalculationInput, scenario: TaxCalculationInput) throws -> ScenarioComparison {
        let ffiResult = try compareScenarios(
            baseGross: base.grossIncome.description,
            baseFilingStatus: base.filingStatus.rawValue,
            baseState: base.state.rawValue,
            basePreTax: base.preTaxDeductions.description,
            basePostTax: base.postTaxDeductions.description,
            baseTraditional401k: base.traditional401k.description,
            baseRoth401k: base.roth401k.description,
            scenarioGross: scenario.grossIncome.description,
            scenarioFilingStatus: scenario.filingStatus.rawValue,
            scenarioState: scenario.state.rawValue,
            scenarioPreTax: scenario.preTaxDeductions.description,
            scenarioPostTax: scenario.postTaxDeductions.description,
            scenarioTraditional401k: scenario.traditional401k.description,
            scenarioRoth401k: scenario.roth401k.description
        )
        return try ScenarioComparison(from: ffiResult)
    }

    func computeTimeframes(annual: Decimal) throws -> TimeframeIncome {
        let ffiResult = try convertTimeframes(annual: annual.description)
        return try TimeframeIncome(from: ffiResult)
    }

    func computeHouseholdSplit(
        primaryNet: Decimal,
        partnerNet: Decimal,
        sharedExpense: Decimal,
        method: SplitMethod
    ) throws -> HouseholdSplit {
        let methodString: String
        switch method {
        case .proportional:
            methodString = "proportional"
        case .equal:
            methodString = "equal"
        case .custom(let percentage):
            methodString = "custom:\(percentage)"
        }

        let ffiResult = try calculateHouseholdSplit(
            primaryNet: primaryNet.description,
            partnerNet: partnerNet.description,
            sharedExpense: sharedExpense.description,
            splitMethod: methodString
        )
        return try HouseholdSplit(from: ffiResult)
    }

    func checkStateHasNoIncomeTax(_ state: USState) -> Bool {
        stateHasNoIncomeTax(stateCode: state.rawValue)
    }
}

// MARK: - App Error
enum AppError: LocalizedError {
    case invalidDecimal(String)
    case invalidFilingStatus(String)
    case invalidState(String)
    case calculationError(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidDecimal(let msg): return "Invalid decimal: \(msg)"
        case .invalidFilingStatus(let msg): return "Invalid filing status: \(msg)"
        case .invalidState(let msg): return "Invalid state: \(msg)"
        case .calculationError(let msg): return "Calculation error: \(msg)"
        case .unknown(let msg): return "Unknown error: \(msg)"
        }
    }

    init(from taxCalcError: TaxCalcError) {
        switch taxCalcError {
        case .InvalidDecimal(let message):
            self = .invalidDecimal(message)
        case .InvalidFilingStatus(let message):
            self = .invalidFilingStatus(message)
        case .InvalidState(let message):
            self = .invalidState(message)
        case .CalculationError(let message):
            self = .calculationError(message)
        }
    }
}
