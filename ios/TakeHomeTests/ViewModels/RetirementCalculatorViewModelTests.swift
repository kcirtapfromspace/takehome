import XCTest
@testable import TakeHome

@MainActor
final class RetirementCalculatorViewModelTests: XCTestCase {
    private var viewModel: RetirementCalculatorViewModel!
    private var mockTaxCore: MockTakeHomeCore!
    private var mockProfileRepository: MockFinancialProfileRepository!

    override func setUp() {
        mockTaxCore = MockTakeHomeCore()
        mockProfileRepository = MockFinancialProfileRepository()
        viewModel = RetirementCalculatorViewModel(
            taxCore: mockTaxCore,
            profileRepository: mockProfileRepository
        )
    }

    override func tearDown() {
        viewModel = nil
        mockTaxCore = nil
        mockProfileRepository = nil
    }

    // MARK: - Contribution Limit Tests

    func testContributionLimit_StandardUnder50() {
        viewModel.isOver50 = false
        XCTAssertEqual(viewModel.contributionLimit, 23000)
    }

    func testContributionLimit_Over50WithCatchUp() {
        viewModel.isOver50 = true
        XCTAssertEqual(viewModel.contributionLimit, 30500)
    }

    func testTotalEmployeeContribution() {
        viewModel.traditional401k = 10000
        viewModel.roth401k = 5000
        XCTAssertEqual(viewModel.totalEmployeeContribution, 15000)
    }

    func testRemainingContributionRoom() {
        viewModel.isOver50 = false
        viewModel.traditional401k = 10000
        viewModel.roth401k = 5000
        XCTAssertEqual(viewModel.remainingContributionRoom, 8000) // 23000 - 15000
    }

    func testIsOverLimit_WhenUnderLimit() {
        viewModel.isOver50 = false
        viewModel.traditional401k = 10000
        viewModel.roth401k = 5000
        XCTAssertFalse(viewModel.isOverLimit)
    }

    func testIsOverLimit_WhenOverLimit() {
        viewModel.isOver50 = false
        viewModel.traditional401k = 15000
        viewModel.roth401k = 10000 // Total 25000 > 23000
        XCTAssertTrue(viewModel.isOverLimit)
    }

    func testLimitWarningMessage_WhenUnderLimit() {
        viewModel.isOver50 = false
        viewModel.traditional401k = 10000
        XCTAssertNil(viewModel.limitWarningMessage)
    }

    func testLimitWarningMessage_WhenOverLimit() {
        viewModel.isOver50 = false
        viewModel.traditional401k = 15000
        viewModel.roth401k = 10000 // Total 25000, excess 2000
        XCTAssertNotNil(viewModel.limitWarningMessage)
        XCTAssertTrue(viewModel.limitWarningMessage?.contains("exceed") ?? false)
    }

    // MARK: - Employer Match Tests

    func testEmployerContribution_WhenNoMatch() {
        viewModel.hasEmployerMatch = false
        viewModel.traditional401k = 10000
        XCTAssertEqual(viewModel.employerContribution, 0)
    }

    func testEmployerContribution_WithMatch() async {
        // Set up profile with salary
        let profile = FinancialProfile(
            income: IncomeProfile(grossSalary: 100000)
        )
        mockProfileRepository.setProfile(profile)

        await viewModel.loadData()

        viewModel.hasEmployerMatch = true
        viewModel.employerMatchPercentage = 50 // 50% match
        viewModel.employerMatchCap = 6 // Up to 6% of salary
        viewModel.traditional401k = 6000 // 6% of 100k
        viewModel.vestingPercentage = 100

        // Employee contributing 6% ($6000), employer matches 50% of that = $3000
        XCTAssertEqual(viewModel.employerContribution, 3000)
    }

    func testEmployerContribution_CappedAtMatchCap() async {
        let profile = FinancialProfile(
            income: IncomeProfile(grossSalary: 100000)
        )
        mockProfileRepository.setProfile(profile)

        await viewModel.loadData()

        viewModel.hasEmployerMatch = true
        viewModel.employerMatchPercentage = 50
        viewModel.employerMatchCap = 6 // Cap at 6% of salary
        viewModel.traditional401k = 20000 // 20% of salary
        viewModel.vestingPercentage = 100

        // Even though contributing 20%, match is capped at 6%
        // 6% of 100k = 6000, 50% match = 3000
        XCTAssertEqual(viewModel.employerContribution, 3000)
    }

    func testVestedEmployerContribution() async {
        let profile = FinancialProfile(
            income: IncomeProfile(grossSalary: 100000)
        )
        mockProfileRepository.setProfile(profile)

        await viewModel.loadData()

        viewModel.hasEmployerMatch = true
        viewModel.employerMatchPercentage = 50
        viewModel.employerMatchCap = 6
        viewModel.traditional401k = 6000
        viewModel.vestingPercentage = 50 // Only 50% vested

        // Employer contribution is 3000, but only 50% vested = 1500
        XCTAssertEqual(viewModel.vestedEmployerContribution, 1500)
    }

    func testTotalRetirementContribution() async {
        let profile = FinancialProfile(
            income: IncomeProfile(grossSalary: 100000)
        )
        mockProfileRepository.setProfile(profile)

        await viewModel.loadData()

        viewModel.hasEmployerMatch = true
        viewModel.employerMatchPercentage = 50
        viewModel.employerMatchCap = 6
        viewModel.traditional401k = 6000
        viewModel.roth401k = 4000
        viewModel.vestingPercentage = 100

        // Employee: 10000, Employer: 3000 (50% of 6% of 100k)
        XCTAssertEqual(viewModel.totalRetirementContribution, 13000)
    }

    // MARK: - Max Contribution Tests

    func testSetMaxTraditional() {
        viewModel.isOver50 = false
        viewModel.roth401k = 5000
        viewModel.setMaxTraditional()
        XCTAssertEqual(viewModel.traditional401k, 18000) // 23000 - 5000
    }

    func testSetMaxRoth() {
        viewModel.isOver50 = false
        viewModel.traditional401k = 10000
        viewModel.setMaxRoth()
        XCTAssertEqual(viewModel.roth401k, 13000) // 23000 - 10000
    }

    func testSetMaxTraditional_DoesNotGoNegative() {
        viewModel.isOver50 = false
        viewModel.roth401k = 25000 // Over limit
        viewModel.setMaxTraditional()
        XCTAssertEqual(viewModel.traditional401k, 0)
    }

    // MARK: - Tax Calculation Tests

    func testRecalculateAll_WithValidSalary() async {
        let profile = FinancialProfile(
            income: IncomeProfile(grossSalary: 100000),
            location: LocationProfile(state: .california, filingStatus: .single)
        )
        mockProfileRepository.setProfile(profile)

        await viewModel.loadData()

        viewModel.traditional401k = 10000
        viewModel.roth401k = 5000

        // Wait for debounce
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertNotNil(viewModel.resultWithContributions)
        XCTAssertNotNil(viewModel.resultWithoutContributions)
        XCTAssertNotNil(viewModel.traditionalOnlyResult)
        XCTAssertNotNil(viewModel.rothOnlyResult)
    }

    func testRecalculateAll_WithZeroSalary() async {
        let profile = FinancialProfile(
            income: IncomeProfile(grossSalary: 0)
        )
        mockProfileRepository.setProfile(profile)

        await viewModel.loadData()
        await viewModel.recalculateAll()

        XCTAssertNil(viewModel.resultWithContributions)
        XCTAssertNil(viewModel.resultWithoutContributions)
    }

    func testAnnualTaxSavings_WithTraditional401k() async {
        let profile = FinancialProfile(
            income: IncomeProfile(grossSalary: 100000),
            location: LocationProfile(state: .california, filingStatus: .single)
        )
        mockProfileRepository.setProfile(profile)

        await viewModel.loadData()

        viewModel.traditional401k = 20000
        viewModel.roth401k = 0

        await viewModel.recalculateAll()

        // Traditional 401k should produce tax savings
        XCTAssertGreaterThan(viewModel.annualTaxSavings, 0)
    }

    func testTakeHomeReduction() async {
        let profile = FinancialProfile(
            income: IncomeProfile(grossSalary: 100000),
            location: LocationProfile(state: .california, filingStatus: .single)
        )
        mockProfileRepository.setProfile(profile)

        await viewModel.loadData()

        viewModel.traditional401k = 10000
        viewModel.roth401k = 5000

        await viewModel.recalculateAll()

        // Contributing to 401k should reduce take-home pay
        XCTAssertGreaterThan(viewModel.takeHomeReduction, 0)
    }

    // MARK: - Comparison Tests

    func testTraditionalVsRothComparison() async {
        let profile = FinancialProfile(
            income: IncomeProfile(grossSalary: 100000),
            location: LocationProfile(state: .california, filingStatus: .single)
        )
        mockProfileRepository.setProfile(profile)

        await viewModel.loadData()

        viewModel.traditional401k = 10000
        viewModel.roth401k = 10000

        await viewModel.recalculateAll()

        // Traditional should give higher take-home than Roth (pre-tax vs post-tax)
        XCTAssertGreaterThan(viewModel.traditionalNetMonthly, viewModel.rothNetMonthly)
        XCTAssertGreaterThan(viewModel.traditionalVsRothDifference, 0)
    }

    // MARK: - Slider Tests

    func testSliderBounds_Under50() {
        viewModel.isOver50 = false
        XCTAssertEqual(viewModel.maxSliderValueDollar, 23000)
    }

    func testSliderBounds_Over50() {
        viewModel.isOver50 = true
        XCTAssertEqual(viewModel.maxSliderValueDollar, 30500)
    }

    func testPercentageMode_Toggle() {
        XCTAssertTrue(viewModel.usePercentageMode) // Default is percentage mode
        viewModel.usePercentageMode = false
        XCTAssertFalse(viewModel.usePercentageMode)
    }

    func testPercentageSlider_CalculatesCorrectly() async {
        let profile = FinancialProfile(
            income: IncomeProfile(grossSalary: 100000)
        )
        mockProfileRepository.setProfile(profile)
        await viewModel.loadData()

        // Set 10% via percentage slider
        viewModel.traditional401kPercentSlider = 10.0

        // Should equal $10,000
        XCTAssertEqual(viewModel.traditional401k, 10000)
        XCTAssertEqual(viewModel.traditional401kPercent, 10.0, accuracy: 0.1)
    }

    func testSliderValueBinding() {
        viewModel.traditional401kSliderValue = 15000
        XCTAssertEqual(viewModel.traditional401k, 15000)

        viewModel.roth401kSliderValue = 8000
        XCTAssertEqual(viewModel.roth401k, 8000)
    }

    // MARK: - Save Tests

    func testSaveContributions() async {
        let profile = FinancialProfile(
            income: IncomeProfile(grossSalary: 100000)
        )
        mockProfileRepository.setProfile(profile)

        await viewModel.loadData()

        viewModel.traditional401k = 15000
        viewModel.roth401k = 5000

        await viewModel.saveContributions()

        XCTAssertGreaterThan(mockProfileRepository.saveCallCount, 0)

        // Load the saved profile to verify
        let savedProfile = try? await mockProfileRepository.load()
        XCTAssertEqual(savedProfile?.deductions.traditional401k, 15000)
        XCTAssertEqual(savedProfile?.deductions.roth401k, 5000)
    }

    // MARK: - Profile Loading Tests

    func testLoadFromProfile() async {
        let profile = FinancialProfile(
            income: IncomeProfile(grossSalary: 150000),
            location: LocationProfile(state: .texas, filingStatus: .marriedFilingJointly),
            deductions: DeductionProfile(
                traditional401k: 12000,
                roth401k: 3000,
                healthInsurance: 500,
                hsa: 300
            )
        )
        mockProfileRepository.setProfile(profile)

        await viewModel.loadData()

        XCTAssertEqual(viewModel.traditional401k, 12000)
        XCTAssertEqual(viewModel.roth401k, 3000)
    }
}
