import XCTest
import Combine
@testable import TakeHome

@MainActor
final class IncomeViewModelTests: XCTestCase {
    private var viewModel: IncomeViewModel!
    private var mockCore: MockTakeHomeCore!
    private var mockProfileRepo: MockFinancialProfileRepository!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        mockCore = MockTakeHomeCore()
        mockProfileRepo = MockFinancialProfileRepository()
        viewModel = IncomeViewModel(
            taxCore: mockCore,
            profileRepository: mockProfileRepo
        )
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() async throws {
        viewModel = nil
        mockCore = nil
        mockProfileRepo = nil
        cancellables = nil
    }

    // MARK: - Initial State Tests
    func testInitialState() {
        XCTAssertEqual(viewModel.grossSalary, 0)
        XCTAssertEqual(viewModel.payFrequency, .biWeekly)
        XCTAssertEqual(viewModel.filingStatus, .single)
        XCTAssertEqual(viewModel.selectedState, .california)
        XCTAssertNil(viewModel.calculationResult)
        XCTAssertFalse(viewModel.hasValidInput)
    }

    // MARK: - Input Validation Tests
    func testHasValidInput_WithZeroSalary_ReturnsFalse() {
        viewModel.grossSalary = 0
        XCTAssertFalse(viewModel.hasValidInput)
    }

    func testHasValidInput_WithPositiveSalary_ReturnsTrue() {
        viewModel.grossSalary = 100000
        XCTAssertTrue(viewModel.hasValidInput)
    }

    // MARK: - Calculation Tests
    func testRecalculate_WithValidInput_CallsTaxCore() async {
        viewModel.grossSalary = 100000
        viewModel.selectedState = .california
        viewModel.filingStatus = .single

        await viewModel.recalculate()

        XCTAssertEqual(mockCore.calculateTaxesCallCount, 1)
        XCTAssertEqual(mockCore.lastTaxInput?.grossIncome, 100000)
        XCTAssertEqual(mockCore.lastTaxInput?.state, .california)
        XCTAssertEqual(mockCore.lastTaxInput?.filingStatus, .single)
    }

    func testRecalculate_WithValidInput_UpdatesResult() async {
        viewModel.grossSalary = 100000
        viewModel.selectedState = .california

        await viewModel.recalculate()

        XCTAssertNotNil(viewModel.calculationResult)
        XCTAssertNotNil(viewModel.timeframes)
    }

    func testRecalculate_WithZeroSalary_DoesNotCallCore() async {
        viewModel.grossSalary = 0

        await viewModel.recalculate()

        XCTAssertEqual(mockCore.calculateTaxesCallCount, 0)
        XCTAssertNil(viewModel.calculationResult)
    }

    func testRecalculate_WithError_SetsError() async {
        mockCore.shouldThrowError = .calculationError("Test error")
        viewModel.grossSalary = 100000

        await viewModel.recalculate()

        XCTAssertTrue(viewModel.showError)
        XCTAssertNotNil(viewModel.error)
    }

    // MARK: - Profile Loading Tests
    func testLoadProfile_WithExistingProfile_LoadsValues() async {
        let profile = FinancialProfile(
            income: IncomeProfile(grossSalary: 150000, payFrequency: .monthly),
            location: LocationProfile(state: .texas, filingStatus: .marriedFilingJointly),
            deductions: DeductionProfile(traditional401k: 19500)
        )
        mockProfileRepo.setProfile(profile)

        await viewModel.loadProfile()

        XCTAssertEqual(viewModel.grossSalary, 150000)
        XCTAssertEqual(viewModel.payFrequency, .monthly)
        XCTAssertEqual(viewModel.selectedState, .texas)
        XCTAssertEqual(viewModel.filingStatus, .marriedFilingJointly)
        XCTAssertEqual(viewModel.traditional401k, 19500)
    }

    func testLoadProfile_WithNoProfile_KeepsDefaults() async {
        await viewModel.loadProfile()

        XCTAssertEqual(viewModel.grossSalary, 0)
        XCTAssertEqual(viewModel.selectedState, .california)
    }

    // MARK: - Save Profile Tests
    func testSaveProfile_SavesCorrectData() async {
        viewModel.grossSalary = 120000
        viewModel.payFrequency = .biWeekly
        viewModel.selectedState = .newYork
        viewModel.filingStatus = .single
        viewModel.traditional401k = 22500

        await viewModel.saveProfile()

        XCTAssertEqual(mockProfileRepo.saveCallCount, 1)
    }

    // MARK: - Build Input Tests
    func testBuildInput_CreatesCorrectInput() {
        viewModel.grossSalary = 100000
        viewModel.filingStatus = .marriedFilingJointly
        viewModel.selectedState = .california
        viewModel.traditional401k = 19500
        viewModel.roth401k = 3000
        viewModel.preTaxDeductions = 500
        viewModel.postTaxDeductions = 200

        let input = viewModel.buildInput()

        XCTAssertEqual(input.grossIncome, 100000)
        XCTAssertEqual(input.filingStatus, .marriedFilingJointly)
        XCTAssertEqual(input.state, .california)
        XCTAssertEqual(input.traditional401k, 19500)
        XCTAssertEqual(input.roth401k, 3000)
        XCTAssertEqual(input.preTaxDeductions, 500)
        XCTAssertEqual(input.postTaxDeductions, 200)
    }

    // MARK: - Available Options Tests
    func testAvailableStates_ReturnsAllStates() {
        XCTAssertEqual(viewModel.availableStates.count, USState.allCases.count)
    }

    func testAvailableFilingStatuses_ReturnsAllStatuses() {
        XCTAssertEqual(viewModel.availableFilingStatuses.count, FilingStatus.allCases.count)
    }
}
