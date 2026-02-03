import XCTest
import Combine
@testable import TakeHome

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    private var viewModel: OnboardingViewModel!
    private var mockTaxCore: MockTakeHomeCore!
    private var mockProfileRepo: MockFinancialProfileRepository!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        mockTaxCore = MockTakeHomeCore()
        mockProfileRepo = MockFinancialProfileRepository()
        viewModel = OnboardingViewModel(
            taxCore: mockTaxCore,
            profileRepository: mockProfileRepo
        )
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() async throws {
        viewModel = nil
        mockTaxCore = nil
        mockProfileRepo = nil
        cancellables = nil
    }

    // MARK: - Initial State Tests
    func testInitialState() {
        XCTAssertEqual(viewModel.currentStep, .welcome)
        XCTAssertNil(viewModel.calculatedResult)
        XCTAssertFalse(viewModel.isAnimatingReveal)
        XCTAssertEqual(viewModel.grossSalary, "")
        XCTAssertEqual(viewModel.payFrequency, .biWeekly)
        XCTAssertEqual(viewModel.selectedState, .california)
        XCTAssertEqual(viewModel.filingStatus, .single)
        XCTAssertEqual(viewModel.householdType, .single)
        XCTAssertEqual(viewModel.deductionSetupMode, .quick)
    }

    func testProgress_AtWelcome_IsZero() {
        XCTAssertEqual(viewModel.progress, 0)
    }

    // MARK: - Household Type Tests
    func testHouseholdType_Single_DoesNotShowPartnerStep() {
        viewModel.householdType = .single
        let visibleSteps = viewModel.visibleSteps
        XCTAssertFalse(visibleSteps.contains(.partnerIncome))
    }

    func testHouseholdType_TwoIncomes_ShowsPartnerStep() {
        viewModel.householdType = .twoIncomes
        let visibleSteps = viewModel.visibleSteps
        XCTAssertTrue(visibleSteps.contains(.partnerIncome))
    }

    func testHouseholdType_Paired_IsNotAvailable() {
        XCTAssertFalse(HouseholdType.paired.isAvailable)
    }

    // MARK: - Deduction Setup Mode Tests
    func testDeductionSetupMode_Quick_DoesNotShowDetailedSteps() {
        viewModel.deductionSetupMode = .quick
        let visibleSteps = viewModel.visibleSteps
        XCTAssertFalse(visibleSteps.contains(.deductionsPreTax))
        XCTAssertFalse(visibleSteps.contains(.deductionsPostTax))
    }

    func testDeductionSetupMode_Detailed_ShowsDetailedSteps() {
        viewModel.deductionSetupMode = .detailed
        let visibleSteps = viewModel.visibleSteps
        XCTAssertTrue(visibleSteps.contains(.deductionsPreTax))
        XCTAssertTrue(visibleSteps.contains(.deductionsPostTax))
    }

    // MARK: - Conditional Navigation Tests
    func testNavigation_SingleQuick_SkipsPartnerAndDetailedSteps() async {
        viewModel.householdType = .single
        viewModel.deductionSetupMode = .quick
        viewModel.grossSalary = "100000"

        await viewModel.next() // welcome -> householdType
        XCTAssertEqual(viewModel.currentStep, .householdType)

        await viewModel.next() // householdType -> income
        XCTAssertEqual(viewModel.currentStep, .income)

        await viewModel.next() // income -> location (skips partnerIncome)
        XCTAssertEqual(viewModel.currentStep, .location)

        await viewModel.next() // location -> deductionSetup
        XCTAssertEqual(viewModel.currentStep, .deductionSetup)

        await viewModel.next() // deductionSetup -> reveal (skips detailed deductions, calculates)
        XCTAssertEqual(viewModel.currentStep, .reveal)
    }

    func testNavigation_TwoIncomesDetailed_ShowsAllSteps() async {
        viewModel.householdType = .twoIncomes
        viewModel.deductionSetupMode = .detailed
        viewModel.grossSalary = "100000"
        viewModel.partnerName = "Partner"
        viewModel.partnerGrossSalary = "80000"

        await viewModel.next() // welcome -> householdType
        XCTAssertEqual(viewModel.currentStep, .householdType)

        await viewModel.next() // householdType -> income
        XCTAssertEqual(viewModel.currentStep, .income)

        await viewModel.next() // income -> partnerIncome
        XCTAssertEqual(viewModel.currentStep, .partnerIncome)

        await viewModel.next() // partnerIncome -> householdSummary
        XCTAssertEqual(viewModel.currentStep, .householdSummary)

        await viewModel.next() // householdSummary -> location
        XCTAssertEqual(viewModel.currentStep, .location)

        await viewModel.next() // location -> deductionSetup
        XCTAssertEqual(viewModel.currentStep, .deductionSetup)

        await viewModel.next() // deductionSetup -> deductionsPreTax
        XCTAssertEqual(viewModel.currentStep, .deductionsPreTax)

        await viewModel.next() // deductionsPreTax -> deductionsPostTax
        XCTAssertEqual(viewModel.currentStep, .deductionsPostTax)

        await viewModel.next() // deductionsPostTax -> reveal (calculates)
        XCTAssertEqual(viewModel.currentStep, .reveal)
    }

    // MARK: - CanProceed Tests
    func testCanProceed_AtWelcome_ReturnsTrue() {
        XCTAssertTrue(viewModel.canProceed)
    }

    func testCanProceed_AtHouseholdType_ReturnsTrueForAvailableTypes() {
        viewModel.householdType = .single
        XCTAssertTrue(viewModel.canProceed)

        viewModel.householdType = .twoIncomes
        XCTAssertTrue(viewModel.canProceed)
    }

    func testCanProceed_AtIncomeWithEmptySalary_ReturnsFalse() async {
        await viewModel.next() // welcome -> householdType
        await viewModel.next() // householdType -> income
        XCTAssertEqual(viewModel.currentStep, .income)
        XCTAssertFalse(viewModel.canProceed)
    }

    func testCanProceed_AtIncomeWithValidSalary_ReturnsTrue() async {
        await viewModel.next() // welcome -> householdType
        await viewModel.next() // householdType -> income
        viewModel.grossSalary = "100000"
        XCTAssertTrue(viewModel.canProceed)
    }

    func testCanProceed_AtPartnerIncomeWithoutName_ReturnsFalse() async {
        viewModel.householdType = .twoIncomes
        viewModel.grossSalary = "100000"
        viewModel.partnerGrossSalary = "80000"
        viewModel.partnerName = ""

        await viewModel.next() // welcome -> householdType
        await viewModel.next() // householdType -> income
        await viewModel.next() // income -> partnerIncome
        XCTAssertEqual(viewModel.currentStep, .partnerIncome)
        XCTAssertFalse(viewModel.canProceed)
    }

    func testCanProceed_AtPartnerIncomeWithValidData_ReturnsTrue() async {
        viewModel.householdType = .twoIncomes
        viewModel.grossSalary = "100000"
        viewModel.partnerGrossSalary = "80000"
        viewModel.partnerName = "Partner"

        await viewModel.next() // welcome -> householdType
        await viewModel.next() // householdType -> income
        await viewModel.next() // income -> partnerIncome
        XCTAssertEqual(viewModel.currentStep, .partnerIncome)
        XCTAssertTrue(viewModel.canProceed)
    }

    // MARK: - Salary Input Frequency Tests
    func testGrossSalaryDecimal_WithAnnualFrequency_ReturnsAsIs() {
        viewModel.grossSalary = "100000"
        viewModel.salaryInputFrequency = .annual
        XCTAssertEqual(viewModel.grossSalaryDecimal, 100000)
    }

    func testGrossSalaryDecimal_WithMonthlyFrequency_ConvertsToAnnual() {
        viewModel.grossSalary = "10000"
        viewModel.salaryInputFrequency = .monthly
        XCTAssertEqual(viewModel.grossSalaryDecimal, 120000) // 10000 * 12
    }

    func testGrossSalaryDecimal_WithPerPaycheckFrequency_ConvertsToAnnual() {
        viewModel.grossSalary = "4000"
        viewModel.salaryInputFrequency = .perPaycheck
        viewModel.payFrequency = .biWeekly
        XCTAssertEqual(viewModel.grossSalaryDecimal, 104000) // 4000 * 26
    }

    // MARK: - Deduction Entry Tests
    func testDeductionEntries_InitiallyDisabled() {
        for entry in viewModel.deductionEntries {
            XCTAssertFalse(entry.isEnabled)
        }
    }

    func testToggleDeductionEntry_TogglesEnabled() {
        let entry = viewModel.deductionEntries.first!
        XCTAssertFalse(entry.isEnabled)

        viewModel.toggleDeductionEntry(id: entry.id)
        let updatedEntry = viewModel.deductionEntries.first { $0.id == entry.id }!
        XCTAssertTrue(updatedEntry.isEnabled)

        viewModel.toggleDeductionEntry(id: entry.id)
        let toggledBack = viewModel.deductionEntries.first { $0.id == entry.id }!
        XCTAssertFalse(toggledBack.isEnabled)
    }

    func testUpdateDeductionEntry_UpdatesEntry() {
        var entry = viewModel.deductionEntries.first!
        entry.amount = 5000
        entry.isEnabled = true

        viewModel.updateDeductionEntry(entry)

        let updatedEntry = viewModel.deductionEntries.first { $0.id == entry.id }!
        XCTAssertEqual(updatedEntry.amount, 5000)
        XCTAssertTrue(updatedEntry.isEnabled)
    }

    func testTotalPreTaxAnnual_QuickMode_SumsBasicDeductions() {
        viewModel.deductionSetupMode = .quick
        viewModel.traditional401k = "20000"
        viewModel.traditional401kInputType = .dollarAmount
        viewModel.healthInsurance = "5000"
        viewModel.healthInsuranceInputType = .dollarAmount
        XCTAssertEqual(viewModel.totalPreTaxAnnual, 25000)
    }

    func testTotalPreTaxAnnual_DetailedMode_SumsEnabledEntries() {
        viewModel.deductionSetupMode = .detailed
        viewModel.grossSalary = "100000"

        // Enable and set a 401k entry
        if let index = viewModel.deductionEntries.firstIndex(where: { $0.type == .traditional401k }) {
            viewModel.deductionEntries[index].isEnabled = true
            viewModel.deductionEntries[index].amount = 20000
            viewModel.deductionEntries[index].frequency = .annual
            viewModel.deductionEntries[index].inputType = .dollarAmount
        }

        XCTAssertEqual(viewModel.totalPreTaxAnnual, 20000)
    }

    func testTotalPreTaxPercent_CalculatesCorrectly() {
        viewModel.grossSalary = "100000"
        viewModel.salaryInputFrequency = .annual
        viewModel.deductionSetupMode = .quick
        viewModel.traditional401k = "10000"
        viewModel.traditional401kInputType = .dollarAmount
        viewModel.healthInsurance = "5000"
        viewModel.healthInsuranceInputType = .dollarAmount

        XCTAssertEqual(viewModel.totalPreTaxPercent, 15.0, accuracy: 0.01)
    }

    // MARK: - Navigation Tests
    func testBack_SkipsHiddenSteps() async {
        viewModel.householdType = .single
        viewModel.grossSalary = "100000"

        await viewModel.next() // welcome -> householdType
        await viewModel.next() // householdType -> income
        await viewModel.next() // income -> location

        XCTAssertEqual(viewModel.currentStep, .location)

        viewModel.back() // location -> income (skips partnerIncome)
        XCTAssertEqual(viewModel.currentStep, .income)
    }

    func testBack_FromWelcome_StaysAtWelcome() {
        viewModel.back()
        XCTAssertEqual(viewModel.currentStep, .welcome)
    }

    // MARK: - Skip Tests
    func testSkip_AtExpenses_GoesToComplete() async {
        viewModel.grossSalary = "100000"

        // Navigate to expenses
        await viewModel.next() // welcome -> householdType
        await viewModel.next() // householdType -> income
        await viewModel.next() // income -> location
        await viewModel.next() // location -> deductionSetup
        await viewModel.next() // deductionSetup -> reveal (calculates)
        await viewModel.next() // reveal -> expenses

        XCTAssertEqual(viewModel.currentStep, .expenses)

        await viewModel.skip()
        XCTAssertEqual(viewModel.currentStep, .complete)
    }

    func testSkip_AtOtherSteps_DoesNothing() async {
        await viewModel.skip()
        XCTAssertEqual(viewModel.currentStep, .welcome)

        await viewModel.next() // welcome -> householdType
        await viewModel.skip()
        XCTAssertEqual(viewModel.currentStep, .householdType)
    }

    // MARK: - Calculation Tests
    func testCalculateTakeHome_CallsTaxCore() async {
        viewModel.grossSalary = "100000"
        await viewModel.calculateTakeHome()

        XCTAssertEqual(mockTaxCore.calculateTaxesCallCount, 1)
    }

    func testCalculateTakeHome_SetsResult() async {
        viewModel.grossSalary = "100000"
        await viewModel.calculateTakeHome()

        XCTAssertNotNil(viewModel.calculatedResult)
    }

    // MARK: - Save Profile Tests
    func testSaveProfile_SingleHousehold_SavesWithoutPartner() async {
        viewModel.householdType = .single
        viewModel.grossSalary = "100000"

        await viewModel.saveProfile()

        XCTAssertEqual(mockProfileRepo.saveCallCount, 1)
        // The saved profile would have nil partnerProfile
    }

    func testSaveProfile_TwoIncomesHousehold_SavesWithPartner() async {
        viewModel.householdType = .twoIncomes
        viewModel.grossSalary = "100000"
        viewModel.partnerName = "Partner"
        viewModel.partnerGrossSalary = "80000"

        await viewModel.saveProfile()

        XCTAssertEqual(mockProfileRepo.saveCallCount, 1)
        // The saved profile would have a partnerProfile
    }

    // MARK: - Reset Tests
    func testReset_ClearsAllState() async {
        viewModel.grossSalary = "100000"
        viewModel.traditional401k = "20000"
        viewModel.selectedState = .texas
        viewModel.filingStatus = .marriedFilingJointly
        viewModel.householdType = .twoIncomes
        viewModel.partnerName = "Partner"
        viewModel.deductionSetupMode = .detailed
        await viewModel.next() // Move forward

        viewModel.reset()

        XCTAssertEqual(viewModel.currentStep, .welcome)
        XCTAssertEqual(viewModel.grossSalary, "")
        XCTAssertEqual(viewModel.traditional401k, "")
        XCTAssertEqual(viewModel.selectedState, .california)
        XCTAssertEqual(viewModel.filingStatus, .single)
        XCTAssertEqual(viewModel.householdType, .single)
        XCTAssertEqual(viewModel.partnerName, "")
        XCTAssertEqual(viewModel.deductionSetupMode, .quick)
        XCTAssertNil(viewModel.calculatedResult)
    }

    // MARK: - Decimal Conversion Tests
    func testGrossSalaryDecimal_ParsesCorrectly() {
        viewModel.grossSalary = "100,000"
        viewModel.salaryInputFrequency = .annual
        XCTAssertEqual(viewModel.grossSalaryDecimal, 100000)
    }

    func testGrossSalaryDecimal_WithEmptyString_ReturnsZero() {
        viewModel.grossSalary = ""
        XCTAssertEqual(viewModel.grossSalaryDecimal, 0)
    }

    func testTraditional401kDecimal_ParsesCorrectly() {
        viewModel.traditional401k = "20,500"
        viewModel.traditional401kInputType = .dollarAmount
        XCTAssertEqual(viewModel.traditional401kDecimal, 20500)
    }

    func testTraditional401kPercentage_CalculatesCorrectly() {
        viewModel.grossSalary = "100000"
        viewModel.traditional401k = "6"  // 6%
        viewModel.traditional401kInputType = .percentageOfSalary
        XCTAssertEqual(viewModel.traditional401kAnnual, 6000)  // 6% of 100k
    }

    func testTraditional401kPercentage_CapsAtIRSLimit() {
        viewModel.grossSalary = "500000"
        viewModel.traditional401k = "10"  // 10% = $50,000
        viewModel.traditional401kInputType = .percentageOfSalary
        XCTAssertEqual(viewModel.traditional401kAnnual, 23000)  // Capped at $23k
    }

    // MARK: - Available Options Tests
    func testAvailableStates_ReturnsFromTaxCore() {
        XCTAssertEqual(viewModel.availableStates.count, mockTaxCore.allStateCodes.count)
    }

    func testAvailableFilingStatuses_ReturnsFromTaxCore() {
        XCTAssertEqual(viewModel.availableFilingStatuses.count, mockTaxCore.allFilingStatuses.count)
    }

    // MARK: - Visible Steps Tests
    func testVisibleSteps_SingleQuick_HasCorrectCount() {
        viewModel.householdType = .single
        viewModel.deductionSetupMode = .quick
        // welcome, householdType, income, location, deductionSetup, reveal, expenses, complete
        XCTAssertEqual(viewModel.visibleSteps.count, 8)
    }

    func testVisibleSteps_TwoIncomesDetailed_HasCorrectCount() {
        viewModel.householdType = .twoIncomes
        viewModel.deductionSetupMode = .detailed
        // welcome, householdType, income, partnerIncome, householdSummary, location, deductionSetup, deductionsPreTax, deductionsPostTax, reveal, expenses, complete
        XCTAssertEqual(viewModel.visibleSteps.count, 12)
    }
}

// MARK: - Deduction Entry Tests
@MainActor
final class DeductionEntryTests: XCTestCase {

    func testAnnualAmount_DollarAmount_Annual() {
        let entry = DeductionEntry(
            type: .traditional401k,
            amount: 20000,
            frequency: .annual,
            inputType: .dollarAmount,
            isEnabled: true
        )
        XCTAssertEqual(entry.annualAmount(grossSalary: 100000, payFrequency: .biWeekly), 20000)
    }

    func testAnnualAmount_DollarAmount_Monthly() {
        let entry = DeductionEntry(
            type: .healthInsurance,
            amount: 500,
            frequency: .monthly,
            inputType: .dollarAmount,
            isEnabled: true
        )
        XCTAssertEqual(entry.annualAmount(grossSalary: 100000, payFrequency: .biWeekly), 6000)
    }

    func testAnnualAmount_DollarAmount_PerPaycheck() {
        let entry = DeductionEntry(
            type: .unionDues,  // Use a type without IRS limit to test frequency conversion
            amount: 200,
            frequency: .perPaycheck,
            inputType: .dollarAmount,
            isEnabled: true
        )
        XCTAssertEqual(entry.annualAmount(grossSalary: 100000, payFrequency: .biWeekly), 5200) // 200 * 26
    }

    func testAnnualAmount_Percentage_Annual() {
        let entry = DeductionEntry(
            type: .traditional401k,
            amount: 10, // 10%
            frequency: .annual,
            inputType: .percentageOfSalary,
            isEnabled: true
        )
        XCTAssertEqual(entry.annualAmount(grossSalary: 100000, payFrequency: .biWeekly), 10000)
    }

    func testAnnualAmount_Percentage_IgnoresFrequency() {
        // Regression test: Percentage deductions should NOT multiply by pay periods
        // Previously, 7% with perPaycheck frequency incorrectly became 7% * 26 = 182%
        let entry = DeductionEntry(
            type: .roth401k,
            amount: 7, // 7%
            frequency: .perPaycheck,  // This should be IGNORED for percentages
            inputType: .percentageOfSalary,
            isEnabled: true
        )
        // Should be 7% of salary, NOT multiplied by pay periods
        XCTAssertEqual(entry.annualAmount(grossSalary: 250000, payFrequency: .biWeekly), 17500)
    }

    func testAnnualAmount_Percentage_IgnoresMonthlyFrequency() {
        // Another regression test with monthly frequency
        let entry = DeductionEntry(
            type: .traditional401k,
            amount: 6, // 6%
            frequency: .monthly,  // This should be IGNORED for percentages
            inputType: .percentageOfSalary,
            isEnabled: true
        )
        // Should be 6% of salary = 6000, NOT 6000 * 12 = 72000
        XCTAssertEqual(entry.annualAmount(grossSalary: 100000, payFrequency: .biWeekly), 6000)
    }

    func testAnnualAmount_CapsAtIRSLimit() {
        // 10% of $500k = $50k, but 401k limit is $23k
        let entry = DeductionEntry(
            type: .traditional401k,
            amount: 10, // 10%
            frequency: .annual,
            inputType: .percentageOfSalary,
            isEnabled: true
        )
        // Should cap at $23,000 (2024 401k limit)
        XCTAssertEqual(entry.annualAmount(grossSalary: 500000, payFrequency: .biWeekly), 23000)
    }

    func testAnnualAmount_DollarAmount_CapsAtIRSLimit() {
        // $1000/paycheck * 26 = $26,000, but 401k limit is $23k
        let entry = DeductionEntry(
            type: .roth401k,
            amount: 1000,
            frequency: .perPaycheck,
            inputType: .dollarAmount,
            isEnabled: true
        )
        // Should cap at $23,000 (2024 401k limit)
        XCTAssertEqual(entry.annualAmount(grossSalary: 250000, payFrequency: .biWeekly), 23000)
    }

    func testAnnualAmount_RespectLimitFalse_ReturnsUncappedAmount() {
        // When respectLimit is false, should return the full calculated amount
        let entry = DeductionEntry(
            type: .traditional401k,
            amount: 10, // 10%
            frequency: .annual,
            inputType: .percentageOfSalary,
            isEnabled: true
        )
        // 10% of $500k = $50k (uncapped)
        XCTAssertEqual(entry.annualAmount(grossSalary: 500000, payFrequency: .biWeekly, respectLimit: false), 50000)
    }

    func testAnnualAmount_NoLimit_ReturnsFullAmount() {
        // Deductions without IRS limits should return full amount
        let entry = DeductionEntry(
            type: .unionDues,
            amount: 500,
            frequency: .monthly,
            inputType: .dollarAmount,
            isEnabled: true
        )
        // $500/month * 12 = $6,000 (no cap for union dues)
        XCTAssertEqual(entry.annualAmount(grossSalary: 100000, payFrequency: .biWeekly), 6000)
    }

    func testAnnualAmount_DisabledEntry_ReturnsZero() {
        let entry = DeductionEntry(
            type: .traditional401k,
            amount: 20000,
            frequency: .annual,
            inputType: .dollarAmount,
            isEnabled: false
        )
        XCTAssertEqual(entry.annualAmount(grossSalary: 100000, payFrequency: .biWeekly), 0)
    }

    func testExceedsLimit_UnderLimit_ReturnsFalse() {
        let entry = DeductionEntry(
            type: .traditional401k,
            amount: 20000,
            frequency: .annual,
            inputType: .dollarAmount,
            isEnabled: true
        )
        XCTAssertFalse(entry.exceedsLimit(grossSalary: 100000, payFrequency: .biWeekly))
    }

    func testExceedsLimit_OverLimit_ReturnsTrue() {
        let entry = DeductionEntry(
            type: .traditional401k,
            amount: 30000, // Over 23000 limit
            frequency: .annual,
            inputType: .dollarAmount,
            isEnabled: true
        )
        XCTAssertTrue(entry.exceedsLimit(grossSalary: 100000, payFrequency: .biWeekly))
    }
}

// MARK: - Deduction Frequency Tests
@MainActor
final class DeductionFrequencyTests: XCTestCase {

    func testToAnnual_Annual() {
        let annual = DeductionFrequency.annual.toAnnual(1000, payFrequency: .biWeekly)
        XCTAssertEqual(annual, 1000)
    }

    func testToAnnual_Monthly() {
        let annual = DeductionFrequency.monthly.toAnnual(1000, payFrequency: .biWeekly)
        XCTAssertEqual(annual, 12000)
    }

    func testToAnnual_PerPaycheck_BiWeekly() {
        let annual = DeductionFrequency.perPaycheck.toAnnual(1000, payFrequency: .biWeekly)
        XCTAssertEqual(annual, 26000)
    }

    func testToAnnual_PerPaycheck_Weekly() {
        let annual = DeductionFrequency.perPaycheck.toAnnual(1000, payFrequency: .weekly)
        XCTAssertEqual(annual, 52000)
    }

    func testFromAnnual_Annual() {
        let amount = DeductionFrequency.annual.fromAnnual(12000, payFrequency: .biWeekly)
        XCTAssertEqual(amount, 12000)
    }

    func testFromAnnual_Monthly() {
        let amount = DeductionFrequency.monthly.fromAnnual(12000, payFrequency: .biWeekly)
        XCTAssertEqual(amount, 1000)
    }

    func testFromAnnual_PerPaycheck_BiWeekly() {
        let amount = DeductionFrequency.perPaycheck.fromAnnual(26000, payFrequency: .biWeekly)
        XCTAssertEqual(amount, 1000)
    }
}

// MARK: - Household Type Tests
@MainActor
final class HouseholdTypeTests: XCTestCase {

    func testSingle_IsAvailable() {
        XCTAssertTrue(HouseholdType.single.isAvailable)
    }

    func testTwoIncomes_IsAvailable() {
        XCTAssertTrue(HouseholdType.twoIncomes.isAvailable)
    }

    func testPaired_IsNotAvailable() {
        XCTAssertFalse(HouseholdType.paired.isAvailable)
    }

    func testDisplayNames() {
        XCTAssertEqual(HouseholdType.single.displayName, "Single")
        XCTAssertEqual(HouseholdType.twoIncomes.displayName, "Two Incomes")
        XCTAssertEqual(HouseholdType.paired.displayName, "Paired Accounts")
    }
}

// MARK: - Deduction Type Tests
@MainActor
final class DeductionTypeTests: XCTestCase {

    func testPreTaxTypes() {
        let preTax = DeductionType.preTaxTypes
        XCTAssertTrue(preTax.contains(.traditional401k))
        XCTAssertTrue(preTax.contains(.healthInsurance))
        XCTAssertTrue(preTax.contains(.hsa))
        XCTAssertFalse(preTax.contains(.roth401k))
        XCTAssertFalse(preTax.contains(.unionDues))
    }

    func testPostTaxTypes() {
        let postTax = DeductionType.postTaxTypes
        XCTAssertTrue(postTax.contains(.roth401k))
        XCTAssertTrue(postTax.contains(.unionDues))
        XCTAssertTrue(postTax.contains(.otherPostTax))
        XCTAssertFalse(postTax.contains(.traditional401k))
        XCTAssertFalse(postTax.contains(.hsa))
    }

    func testAnnualLimits() {
        XCTAssertEqual(DeductionType.traditional401k.annualLimit, 23000)
        XCTAssertEqual(DeductionType.hsa.annualLimit, 4150)
        XCTAssertNil(DeductionType.unionDues.annualLimit)
    }
}
