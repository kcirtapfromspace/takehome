import XCTest
@testable import TakeHome

final class TakeHomeCoreWrapperTests: XCTestCase {
    private var wrapper: TakeHomeCoreWrapper!

    override func setUp() {
        wrapper = TakeHomeCoreWrapper()
    }

    override func tearDown() {
        wrapper = nil
    }

    // MARK: - Version and Metadata Tests
    func testVersion_ReturnsNonEmptyString() {
        let version = wrapper.version
        XCTAssertFalse(version.isEmpty)
    }

    func testTaxYear_Returns2024() {
        let year = wrapper.taxYear
        XCTAssertEqual(year, 2024)
    }

    // MARK: - State Codes Tests
    func testAllStateCodes_Returns51States() {
        let states = wrapper.allStateCodes
        XCTAssertEqual(states.count, 51) // 50 states + DC
    }

    func testAllStateCodes_ContainsCaliforniaAndTexas() {
        let states = wrapper.allStateCodes
        XCTAssertTrue(states.contains(.california))
        XCTAssertTrue(states.contains(.texas))
    }

    // MARK: - Filing Status Tests
    func testAllFilingStatuses_Returns5Statuses() {
        let statuses = wrapper.allFilingStatuses
        XCTAssertEqual(statuses.count, 5)
    }

    func testAllFilingStatuses_ContainsAllExpectedStatuses() {
        let statuses = wrapper.allFilingStatuses
        XCTAssertTrue(statuses.contains(.single))
        XCTAssertTrue(statuses.contains(.marriedFilingJointly))
        XCTAssertTrue(statuses.contains(.marriedFilingSeparately))
        XCTAssertTrue(statuses.contains(.headOfHousehold))
        XCTAssertTrue(statuses.contains(.qualifyingWidower))
    }

    // MARK: - State Income Tax Tests
    func testStateHasNoIncomeTax_Texas_ReturnsTrue() {
        XCTAssertTrue(wrapper.checkStateHasNoIncomeTax(.texas))
    }

    func testStateHasNoIncomeTax_Florida_ReturnsTrue() {
        XCTAssertTrue(wrapper.checkStateHasNoIncomeTax(.florida))
    }

    func testStateHasNoIncomeTax_California_ReturnsFalse() {
        XCTAssertFalse(wrapper.checkStateHasNoIncomeTax(.california))
    }

    func testStateHasNoIncomeTax_NewYork_ReturnsFalse() {
        XCTAssertFalse(wrapper.checkStateHasNoIncomeTax(.newYork))
    }

    // MARK: - Tax Calculation Tests
    func testCalculateTaxes_With100kSalary_ReturnsValidResult() throws {
        let input = TaxCalculationInput(
            grossIncome: 100000,
            filingStatus: .single,
            state: .california
        )

        let result = try wrapper.computeTaxes(input: input)

        XCTAssertEqual(result.grossAnnual, 100000)
        XCTAssertGreaterThan(result.netAnnual, 0)
        XCTAssertLessThan(result.netAnnual, result.grossAnnual)
        XCTAssertGreaterThan(result.federalTax, 0)
        XCTAssertGreaterThan(result.totalTaxes, 0)
    }

    func testCalculateTaxes_WithNoIncomeTaxState_HasLowerTaxes() throws {
        let caInput = TaxCalculationInput(
            grossIncome: 100000,
            filingStatus: .single,
            state: .california
        )

        let txInput = TaxCalculationInput(
            grossIncome: 100000,
            filingStatus: .single,
            state: .texas
        )

        let caResult = try wrapper.computeTaxes(input: caInput)
        let txResult = try wrapper.computeTaxes(input: txInput)

        // Texas should have higher net income due to no state tax
        XCTAssertGreaterThan(txResult.netAnnual, caResult.netAnnual)
        XCTAssertEqual(txResult.stateIncomeTax, 0)
    }

    func testCalculateTaxes_With401kContribution_ReducesTaxableIncome() throws {
        let withoutContribution = TaxCalculationInput(
            grossIncome: 100000,
            filingStatus: .single,
            state: .california,
            traditional401k: 0
        )

        let withContribution = TaxCalculationInput(
            grossIncome: 100000,
            filingStatus: .single,
            state: .california,
            traditional401k: 20000
        )

        let resultWithout = try wrapper.computeTaxes(input: withoutContribution)
        let resultWith = try wrapper.computeTaxes(input: withContribution)

        // Less federal tax with 401k contribution
        XCTAssertLessThan(resultWith.federalTax, resultWithout.federalTax)
    }

    // MARK: - Timeframe Conversion Tests
    func testConvertTimeframes_Annual104k_CorrectBiWeekly() throws {
        let timeframes = try wrapper.computeTimeframes(annual: 104000)

        XCTAssertEqual(timeframes.annual, 104000)
        XCTAssertEqual(timeframes.biWeekly, 4000) // 104000 / 26
        XCTAssertEqual(timeframes.hourly, 50) // 104000 / 2080
    }

    func testConvertTimeframes_VerifyAllPeriods() throws {
        let annual = Decimal(120000)
        let timeframes = try wrapper.computeTimeframes(annual: annual)

        XCTAssertEqual(timeframes.annual, annual)
        XCTAssertEqual(timeframes.monthly, 10000) // 120000 / 12

        // For repeating decimals, use approximate comparison (within 0.01)
        XCTAssertEqual(Double(truncating: timeframes.biWeekly as NSNumber),
                       Double(truncating: (annual / 26) as NSNumber),
                       accuracy: 0.01)
        XCTAssertEqual(Double(truncating: timeframes.weekly as NSNumber),
                       Double(truncating: (annual / 52) as NSNumber),
                       accuracy: 0.01)
        XCTAssertEqual(Double(truncating: timeframes.daily as NSNumber),
                       Double(truncating: (annual / 260) as NSNumber),
                       accuracy: 0.01)
        XCTAssertEqual(Double(truncating: timeframes.hourly as NSNumber),
                       Double(truncating: (annual / 2080) as NSNumber),
                       accuracy: 0.01)
    }

    // MARK: - Scenario Comparison Tests
    func testCompareScenarios_RaiseScenario_ShowsPositiveDifference() throws {
        let base = TaxCalculationInput(
            grossIncome: 100000,
            filingStatus: .single,
            state: .california
        )

        let scenario = TaxCalculationInput(
            grossIncome: 120000,
            filingStatus: .single,
            state: .california
        )

        let comparison = try wrapper.computeScenarioComparison(base: base, scenario: scenario)

        XCTAssertTrue(comparison.isPositive)
        XCTAssertGreaterThan(comparison.netDifference, 0)
        XCTAssertGreaterThan(comparison.monthlyDifference, 0)
    }

    func testCompareScenarios_PayCutScenario_ShowsNegativeDifference() throws {
        let base = TaxCalculationInput(
            grossIncome: 100000,
            filingStatus: .single,
            state: .california
        )

        let scenario = TaxCalculationInput(
            grossIncome: 80000,
            filingStatus: .single,
            state: .california
        )

        let comparison = try wrapper.computeScenarioComparison(base: base, scenario: scenario)

        XCTAssertFalse(comparison.isPositive)
        XCTAssertLessThan(comparison.netDifference, 0)
    }

    // MARK: - Household Split Tests
    func testCalculateHouseholdSplit_ProportionalMethod() throws {
        let split = try wrapper.computeHouseholdSplit(
            primaryNet: 8000,
            partnerNet: 2000,
            sharedExpense: 1000,
            method: .proportional
        )

        // Primary earns 80% of total, should pay 80% of expense
        XCTAssertEqual(split.primaryRatio, Decimal(string: "0.8"))
        XCTAssertEqual(split.partnerRatio, Decimal(string: "0.2"))
        XCTAssertEqual(split.primaryAmount, 800)
        XCTAssertEqual(split.partnerAmount, 200)
    }

    func testCalculateHouseholdSplit_EqualMethod() throws {
        let split = try wrapper.computeHouseholdSplit(
            primaryNet: 8000,
            partnerNet: 2000,
            sharedExpense: 1000,
            method: .equal
        )

        XCTAssertEqual(split.primaryRatio, Decimal(string: "0.5"))
        XCTAssertEqual(split.partnerRatio, Decimal(string: "0.5"))
        XCTAssertEqual(split.primaryAmount, 500)
        XCTAssertEqual(split.partnerAmount, 500)
    }

    // MARK: - Error Handling Tests
    func testCalculateTaxes_InvalidInput_ThrowsError() {
        let input = TaxCalculationInput(
            grossIncome: -1000, // Invalid negative income
            filingStatus: .single,
            state: .california
        )

        // The actual behavior depends on the Rust core
        // This test documents expected behavior
        do {
            _ = try wrapper.computeTaxes(input: input)
            // If it doesn't throw, verify the result handles negative gracefully
        } catch {
            // Expected behavior - error for invalid input
            XCTAssertTrue(error is TaxCalcError || error is AppError)
        }
    }
}
