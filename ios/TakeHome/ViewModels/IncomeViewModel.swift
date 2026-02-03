import Foundation
import Combine

// MARK: - Income ViewModel
@MainActor
final class IncomeViewModel: BaseViewModel {
    // MARK: - Dependencies
    private let taxCore: TakeHomeCoreProtocol
    private let profileRepository: FinancialProfileRepositoryProtocol

    // MARK: - Published State
    @Published var grossSalary: Decimal = 0
    @Published var payFrequency: PayFrequency = .biWeekly
    @Published var filingStatus: FilingStatus = .single
    @Published var selectedState: USState = .california
    @Published var traditional401k: Decimal = 0
    @Published var roth401k: Decimal = 0
    @Published var preTaxDeductions: Decimal = 0
    @Published var postTaxDeductions: Decimal = 0

    @Published private(set) var calculationResult: TaxCalculationResult?
    @Published private(set) var timeframes: TimeframeIncome?

    // MARK: - Computed Properties
    var availableStates: [USState] {
        taxCore.allStateCodes
    }

    var availableFilingStatuses: [FilingStatus] {
        taxCore.allFilingStatuses
    }

    var hasValidInput: Bool {
        grossSalary > 0
    }

    // MARK: - Initialization
    init(
        taxCore: TakeHomeCoreProtocol,
        profileRepository: FinancialProfileRepositoryProtocol
    ) {
        self.taxCore = taxCore
        self.profileRepository = profileRepository
        super.init()
        setupBindings()
    }

    // MARK: - Setup
    private func setupBindings() {
        // Auto-recalculate when inputs change
        Publishers.CombineLatest4(
            $grossSalary,
            $filingStatus,
            $selectedState,
            $traditional401k
        )
        .combineLatest(Publishers.CombineLatest3($roth401k, $preTaxDeductions, $postTaxDeductions))
        .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            Task { [weak self] in
                await self?.recalculate()
            }
        }
        .store(in: &cancellables)

        // Subscribe to profile updates
        profileRepository.profilePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                guard let profile = profile else { return }
                self?.loadFromProfile(profile)
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions
    func loadProfile() async {
        await performTaskWithoutResult { [weak self] in
            guard let self = self else { return }
            if let profile = try await self.profileRepository.load() {
                await MainActor.run {
                    self.loadFromProfile(profile)
                }
            }
        }
    }

    func recalculate() async {
        guard hasValidInput else {
            calculationResult = nil
            timeframes = nil
            return
        }

        await performTaskWithoutResult { [weak self] in
            guard let self = self else { return }
            let input = self.buildInput()
            let result = try self.taxCore.computeTaxes(input: input)

            await MainActor.run {
                self.calculationResult = result
                self.timeframes = result.timeframes
            }
        }
    }

    func saveProfile() async {
        await performTaskWithoutResult { [weak self] in
            guard let self = self else { return }
            let profile = self.buildProfile()
            try await self.profileRepository.save(profile)
        }
    }

    // MARK: - Input/Output Helpers
    func buildInput() -> TaxCalculationInput {
        TaxCalculationInput(
            grossIncome: grossSalary,
            filingStatus: filingStatus,
            state: selectedState,
            preTaxDeductions: preTaxDeductions,
            postTaxDeductions: postTaxDeductions,
            traditional401k: traditional401k,
            roth401k: roth401k
        )
    }

    private func buildProfile() -> FinancialProfile {
        FinancialProfile(
            name: "My Profile",
            income: IncomeProfile(
                grossSalary: grossSalary,
                payFrequency: payFrequency,
                bonusAnnual: 0
            ),
            location: LocationProfile(
                state: selectedState,
                filingStatus: filingStatus
            ),
            deductions: DeductionProfile(
                traditional401k: traditional401k,
                roth401k: roth401k,
                otherPreTax: preTaxDeductions,
                otherPostTax: postTaxDeductions
            )
        )
    }

    private func loadFromProfile(_ profile: FinancialProfile) {
        grossSalary = profile.income.grossSalary
        payFrequency = profile.income.payFrequency
        filingStatus = profile.location.filingStatus
        selectedState = profile.location.state
        traditional401k = profile.deductions.traditional401k
        roth401k = profile.deductions.roth401k
        preTaxDeductions = profile.deductions.preTaxTotal
        postTaxDeductions = profile.deductions.postTaxTotal
    }
}
