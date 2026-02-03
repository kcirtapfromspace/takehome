import Foundation
@testable import TakeHome

/// Mock implementation of TakeHomeCoreProtocol for testing
final class MockTakeHomeCore: TakeHomeCoreProtocol {
    // MARK: - Stubbed Responses
    var stubbedTaxResult: TaxCalculationResult?
    var stubbedScenarioComparison: ScenarioComparison?
    var stubbedTimeframes: TimeframeIncome?
    var stubbedHouseholdSplit: HouseholdSplit?
    var shouldThrowError: AppError?

    // MARK: - Call Tracking
    var calculateTaxesCallCount = 0
    var compareScenariosCallCount = 0
    var convertTimeframesCallCount = 0
    var householdSplitCallCount = 0

    var lastTaxInput: TaxCalculationInput?
    var lastBaseInput: TaxCalculationInput?
    var lastScenarioInput: TaxCalculationInput?
    var lastAnnualAmount: Decimal?

    // MARK: - Protocol Implementation
    var allStateCodes: [USState] {
        USState.allCases
    }

    var allFilingStatuses: [FilingStatus] {
        FilingStatus.allCases
    }

    var version: String {
        "1.0.0-mock"
    }

    var taxYear: UInt32 {
        2024
    }

    func computeTaxes(input: TaxCalculationInput) throws -> TaxCalculationResult {
        calculateTaxesCallCount += 1
        lastTaxInput = input

        if let error = shouldThrowError {
            throw error
        }

        if let result = stubbedTaxResult {
            return result
        }

        // Return a default mock result
        return Self.defaultTaxResult(for: input)
    }

    func computeScenarioComparison(base: TaxCalculationInput, scenario: TaxCalculationInput) throws -> ScenarioComparison {
        compareScenariosCallCount += 1
        lastBaseInput = base
        lastScenarioInput = scenario

        if let error = shouldThrowError {
            throw error
        }

        if let comparison = stubbedScenarioComparison {
            return comparison
        }

        // Return a default mock comparison
        return Self.defaultScenarioComparison(base: base, scenario: scenario)
    }

    func computeTimeframes(annual: Decimal) throws -> TimeframeIncome {
        convertTimeframesCallCount += 1
        lastAnnualAmount = annual

        if let error = shouldThrowError {
            throw error
        }

        if let timeframes = stubbedTimeframes {
            return timeframes
        }

        return TimeframeIncome.fromAnnual(annual)
    }

    func computeHouseholdSplit(
        primaryNet: Decimal,
        partnerNet: Decimal,
        sharedExpense: Decimal,
        method: SplitMethod
    ) throws -> HouseholdSplit {
        householdSplitCallCount += 1

        if let error = shouldThrowError {
            throw error
        }

        if let split = stubbedHouseholdSplit {
            return split
        }

        // Calculate proportional split
        let total = primaryNet + partnerNet
        let primaryRatio = total > 0 ? primaryNet / total : Decimal(0.5)
        let partnerRatio = total > 0 ? partnerNet / total : Decimal(0.5)

        return HouseholdSplit(
            primaryRatio: primaryRatio,
            partnerRatio: partnerRatio,
            primaryAmount: sharedExpense * primaryRatio,
            partnerAmount: sharedExpense * partnerRatio
        )
    }

    func checkStateHasNoIncomeTax(_ state: USState) -> Bool {
        state.hasNoIncomeTax
    }

    // MARK: - Reset
    func reset() {
        stubbedTaxResult = nil
        stubbedScenarioComparison = nil
        stubbedTimeframes = nil
        stubbedHouseholdSplit = nil
        shouldThrowError = nil
        calculateTaxesCallCount = 0
        compareScenariosCallCount = 0
        convertTimeframesCallCount = 0
        householdSplitCallCount = 0
        lastTaxInput = nil
        lastBaseInput = nil
        lastScenarioInput = nil
        lastAnnualAmount = nil
    }

    // MARK: - Default Results
    static func defaultTaxResult(for input: TaxCalculationInput) -> TaxCalculationResult {
        let gross = input.grossIncome
        let taxableIncome = gross - input.preTaxDeductions - input.traditional401k
        let federalTax = taxableIncome * Decimal(0.22) // Simplified 22% bracket
        let stateTax = input.state.hasNoIncomeTax ? Decimal(0) : taxableIncome * Decimal(0.05)
        let socialSecurity = min(gross * Decimal(0.062), Decimal(142800) * Decimal(0.062))
        let medicare = gross * Decimal(0.0145)
        let totalTax = federalTax + stateTax + socialSecurity + medicare
        let netAnnual = gross - totalTax - input.traditional401k - input.preTaxDeductions - input.postTaxDeductions - input.roth401k

        return TaxCalculationResult(
            grossAnnual: gross,
            netAnnual: netAnnual,
            timeframes: TimeframeIncome.fromAnnual(netAnnual),
            takeHomePercentage: gross > 0 ? (netAnnual / gross) * 100 : 0,
            federalTax: federalTax,
            federalEffectiveRate: gross > 0 ? (federalTax / gross) * 100 : 0,
            federalMarginalRate: Decimal(22),
            stateCode: input.state.rawValue,
            stateIncomeTax: stateTax,
            stateLocalTax: 0,
            stateSDI: 0,
            stateTotalTax: stateTax,
            socialSecurity: socialSecurity,
            medicare: medicare,
            additionalMedicare: 0,
            ficaTotal: socialSecurity + medicare,
            totalTaxes: totalTax,
            totalEffectiveRate: gross > 0 ? (totalTax / gross) * 100 : 0
        )
    }

    static func defaultScenarioComparison(base: TaxCalculationInput, scenario: TaxCalculationInput) -> ScenarioComparison {
        let baseResult = defaultTaxResult(for: base)
        let scenarioResult = defaultTaxResult(for: scenario)
        let netDifference = scenarioResult.netAnnual - baseResult.netAnnual

        return ScenarioComparison(
            base: baseResult,
            scenario: scenarioResult,
            netDifference: netDifference,
            monthlyDifference: netDifference / 12,
            isPositive: netDifference > 0
        )
    }
}
