import XCTest
@testable import TakeHome

/// Integration tests that verify the Rust FFI layer works correctly
/// These tests use the actual Rust core (not mocks) to verify real calculations
final class RustCoreIntegrationTests: XCTestCase {
    private var wrapper: TakeHomeCoreWrapper!

    override func setUp() {
        wrapper = TakeHomeCoreWrapper()
    }

    override func tearDown() {
        wrapper = nil
    }

    // MARK: - Tax Calculation Integration Tests

    func testRealTaxCalculation_SingleFiler_California_100k() throws {
        // This is a real integration test using actual tax brackets
        let input = TaxCalculationInput(
            grossIncome: 100000,
            filingStatus: .single,
            state: .california
        )

        let result = try wrapper.computeTaxes(input: input)

        // Verify the result is reasonable
        XCTAssertEqual(result.grossAnnual, 100000)
        XCTAssertGreaterThan(result.netAnnual, 50000) // Net should be more than half
        XCTAssertLessThan(result.netAnnual, 90000) // Net should be less than 90%

        // Federal tax should be calculated (varies by tax year, ~$13-20k for 100k single)
        XCTAssertGreaterThan(result.federalTax, 10000)
        XCTAssertLessThan(result.federalTax, 25000)

        // California state tax should be non-zero
        XCTAssertGreaterThan(result.stateIncomeTax, 0)

        // FICA taxes
        XCTAssertGreaterThan(result.socialSecurity, 6000) // ~6.2% of 100k
        XCTAssertGreaterThan(result.medicare, 1400) // ~1.45% of 100k

        // Timeframes should be calculated correctly (within rounding tolerance)
        XCTAssertEqual(Double(truncating: result.netMonthly as NSNumber),
                       Double(truncating: (result.netAnnual / 12) as NSNumber),
                       accuracy: 0.01)
    }

    func testRealTaxCalculation_MarriedFilingJointly_Texas_150k() throws {
        let input = TaxCalculationInput(
            grossIncome: 150000,
            filingStatus: .marriedFilingJointly,
            state: .texas // No state income tax
        )

        let result = try wrapper.computeTaxes(input: input)

        // Texas has no state income tax
        XCTAssertEqual(result.stateIncomeTax, 0)

        // Net should be higher than California equivalent
        let caInput = TaxCalculationInput(
            grossIncome: 150000,
            filingStatus: .marriedFilingJointly,
            state: .california
        )
        let caResult = try wrapper.computeTaxes(input: caInput)

        XCTAssertGreaterThan(result.netAnnual, caResult.netAnnual)
    }

    func testRealTaxCalculation_With401kContribution() throws {
        let withoutContrib = TaxCalculationInput(
            grossIncome: 100000,
            filingStatus: .single,
            state: .california,
            traditional401k: 0
        )

        let withContrib = TaxCalculationInput(
            grossIncome: 100000,
            filingStatus: .single,
            state: .california,
            traditional401k: 20000
        )

        let resultWithout = try wrapper.computeTaxes(input: withoutContrib)
        let resultWith = try wrapper.computeTaxes(input: withContrib)

        // 401k reduces taxable income, so federal tax should be lower
        XCTAssertLessThan(resultWith.federalTax, resultWithout.federalTax)

        // But net annual should also be lower (money went to 401k)
        XCTAssertLessThan(resultWith.netAnnual, resultWithout.netAnnual)

        // Tax savings should be meaningful
        let taxSavings = resultWithout.totalTaxes - resultWith.totalTaxes
        XCTAssertGreaterThan(taxSavings, 3000) // Should save at least $3k in taxes on $20k contrib
    }

    func testRealTaxCalculation_SocialSecurityWageBaseCap() throws {
        let input = TaxCalculationInput(
            grossIncome: 200000, // Above SS wage base cap (~$160k in 2024)
            filingStatus: .single,
            state: .texas
        )

        let result = try wrapper.computeTaxes(input: input)

        // Social Security should be capped at the wage base (varies by year)
        // For $200k income, SS should be capped, not calculated on full amount
        let uncappedSS = Decimal(200000) * Decimal(0.062) // $12,400 if not capped
        XCTAssertLessThan(result.socialSecurity, uncappedSS) // Must be less than uncapped amount

        // Medicare has no cap
        let expectedMedicare = Decimal(200000) * Decimal(0.0145)
        XCTAssertEqual(Double(truncating: result.medicare as NSNumber),
                       Double(truncating: expectedMedicare as NSNumber),
                       accuracy: 10)
    }

    // MARK: - Scenario Comparison Integration Tests

    func testRealScenarioComparison_Raise() throws {
        let base = TaxCalculationInput(
            grossIncome: 100000,
            filingStatus: .single,
            state: .california
        )

        let scenario = TaxCalculationInput(
            grossIncome: 120000, // $20k raise
            filingStatus: .single,
            state: .california
        )

        let comparison = try wrapper.computeScenarioComparison(base: base, scenario: scenario)

        XCTAssertTrue(comparison.isPositive)
        XCTAssertGreaterThan(comparison.netDifference, 0)

        // Net increase should be less than $20k due to taxes
        XCTAssertLessThan(comparison.netDifference, 20000)

        // Monthly difference should be positive
        XCTAssertGreaterThan(comparison.monthlyDifference, 0)
    }

    func testRealScenarioComparison_StateMove() throws {
        let californiaBase = TaxCalculationInput(
            grossIncome: 150000,
            filingStatus: .single,
            state: .california
        )

        let texasScenario = TaxCalculationInput(
            grossIncome: 150000,
            filingStatus: .single,
            state: .texas
        )

        let comparison = try wrapper.computeScenarioComparison(base: californiaBase, scenario: texasScenario)

        // Moving to Texas should increase net income
        XCTAssertTrue(comparison.isPositive)
        XCTAssertGreaterThan(comparison.netDifference, 5000) // Should save significant taxes
    }

    // MARK: - Timeframe Conversion Integration Tests

    func testRealTimeframeConversion() throws {
        let annual = Decimal(120000)
        let timeframes = try wrapper.computeTimeframes(annual: annual)

        XCTAssertEqual(timeframes.annual, 120000)
        XCTAssertEqual(timeframes.monthly, 10000)

        // Verify bi-weekly is correct (120000 / 26)
        XCTAssertEqual(Double(truncating: timeframes.biWeekly as NSNumber),
                       4615.38,
                       accuracy: 0.01)

        // Verify hourly is correct (120000 / 2080)
        XCTAssertEqual(Double(truncating: timeframes.hourly as NSNumber),
                       57.69,
                       accuracy: 0.01)
    }

    // MARK: - Household Split Integration Tests

    func testRealHouseholdSplit_Proportional() throws {
        let split = try wrapper.computeHouseholdSplit(
            primaryNet: 8000,
            partnerNet: 2000,
            sharedExpense: 2000,
            method: .proportional
        )

        // 80% / 20% split
        XCTAssertEqual(Double(truncating: split.primaryRatio as NSNumber), 0.8, accuracy: 0.01)
        XCTAssertEqual(Double(truncating: split.partnerRatio as NSNumber), 0.2, accuracy: 0.01)

        // Primary pays $1600, partner pays $400
        XCTAssertEqual(Double(truncating: split.primaryAmount as NSNumber), 1600, accuracy: 1)
        XCTAssertEqual(Double(truncating: split.partnerAmount as NSNumber), 400, accuracy: 1)
    }

    func testRealHouseholdSplit_Equal() throws {
        let split = try wrapper.computeHouseholdSplit(
            primaryNet: 8000,
            partnerNet: 2000,
            sharedExpense: 2000,
            method: .equal
        )

        // 50% / 50% split regardless of income
        XCTAssertEqual(Double(truncating: split.primaryRatio as NSNumber), 0.5, accuracy: 0.01)
        XCTAssertEqual(Double(truncating: split.partnerRatio as NSNumber), 0.5, accuracy: 0.01)

        // Each pays $1000
        XCTAssertEqual(Double(truncating: split.primaryAmount as NSNumber), 1000, accuracy: 1)
        XCTAssertEqual(Double(truncating: split.partnerAmount as NSNumber), 1000, accuracy: 1)
    }

    // MARK: - All States Integration Test

    func testAllStatesCalculateTaxes() throws {
        // Verify that tax calculation works for all 51 states
        for state in wrapper.allStateCodes {
            let input = TaxCalculationInput(
                grossIncome: 100000,
                filingStatus: .single,
                state: state
            )

            let result = try wrapper.computeTaxes(input: input)

            // All states should produce valid results
            XCTAssertGreaterThan(result.netAnnual, 0, "State \(state.rawValue) failed")
            XCTAssertLessThan(result.netAnnual, 100000, "State \(state.rawValue) failed")
        }
    }

    // MARK: - Edge Cases

    func testEdgeCase_ZeroIncome() throws {
        let input = TaxCalculationInput(
            grossIncome: 0,
            filingStatus: .single,
            state: .california
        )

        let result = try wrapper.computeTaxes(input: input)

        XCTAssertEqual(result.grossAnnual, 0)
        XCTAssertEqual(result.netAnnual, 0)
        XCTAssertEqual(result.federalTax, 0)
    }

    func testEdgeCase_HighIncome() throws {
        let input = TaxCalculationInput(
            grossIncome: 1000000, // $1M income
            filingStatus: .single,
            state: .california
        )

        let result = try wrapper.computeTaxes(input: input)

        // At $1M, effective rate should be significant
        // Note: totalEffectiveRate is returned as a decimal (e.g., 0.35 for 35%), not percentage
        let effectiveRatePercent = Double(truncating: result.totalEffectiveRate as NSNumber)
        // If returned as decimal fraction, multiply by 100
        let rateToCheck = effectiveRatePercent < 1 ? effectiveRatePercent * 100 : effectiveRatePercent
        XCTAssertGreaterThan(rateToCheck, 25)
        XCTAssertLessThan(rateToCheck, 60)

        // Net should still be substantial
        XCTAssertGreaterThan(result.netAnnual, 450000)
    }
}
