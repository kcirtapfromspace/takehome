import Foundation
import Combine
import SuperwallKit

/// Central dependency container for the app
/// Provides access to shared services and manages app-wide state
@MainActor
final class DependencyContainer: ObservableObject {
    // MARK: - Published State
    @Published private(set) var hasCompletedOnboarding: Bool

    /// Whether the user has an active Superwall subscription
    var isSubscribed: Bool {
        if case .active = Superwall.shared.subscriptionStatus {
            return true
        }
        return false
    }

    // MARK: - Core Services
    let taxCore: TakeHomeCoreProtocol

    // MARK: - Repositories
    let profileRepository: FinancialProfileRepositoryProtocol
    let expenseRepository: ExpenseRepositoryProtocol
    let scenarioRepository: ScenarioRepositoryProtocol

    // MARK: - ViewModels (lazy initialization)
    private var _incomeViewModel: IncomeViewModel?
    private var _expenseViewModel: ExpenseViewModel?
    private var _scenarioViewModel: ScenarioViewModel?
    private var _dashboardViewModel: DashboardViewModel?
    private var _onboardingViewModel: OnboardingViewModel?
    private var _householdViewModel: HouseholdViewModel?

    // MARK: - Initialization
    init(
        taxCore: TakeHomeCoreProtocol? = nil,
        profileRepository: FinancialProfileRepositoryProtocol? = nil,
        expenseRepository: ExpenseRepositoryProtocol? = nil,
        scenarioRepository: ScenarioRepositoryProtocol? = nil
    ) {
        self.taxCore = taxCore ?? TakeHomeCoreWrapper()
        self.profileRepository = profileRepository ?? InMemoryFinancialProfileRepository()
        self.expenseRepository = expenseRepository ?? InMemoryExpenseRepository()
        self.scenarioRepository = scenarioRepository ?? InMemoryScenarioRepository()
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    // MARK: - ViewModel Accessors
    var incomeViewModel: IncomeViewModel {
        if _incomeViewModel == nil {
            _incomeViewModel = IncomeViewModel(
                taxCore: taxCore,
                profileRepository: profileRepository
            )
        }
        return _incomeViewModel!
    }

    var expenseViewModel: ExpenseViewModel {
        if _expenseViewModel == nil {
            _expenseViewModel = ExpenseViewModel(
                expenseRepository: expenseRepository
            )
        }
        return _expenseViewModel!
    }

    var scenarioViewModel: ScenarioViewModel {
        if _scenarioViewModel == nil {
            _scenarioViewModel = ScenarioViewModel(
                taxCore: taxCore,
                scenarioRepository: scenarioRepository,
                profileRepository: profileRepository
            )
        }
        return _scenarioViewModel!
    }

    var dashboardViewModel: DashboardViewModel {
        if _dashboardViewModel == nil {
            _dashboardViewModel = DashboardViewModel(
                taxCore: taxCore,
                profileRepository: profileRepository,
                expenseRepository: expenseRepository
            )
        }
        return _dashboardViewModel!
    }

    var onboardingViewModel: OnboardingViewModel {
        if _onboardingViewModel == nil {
            _onboardingViewModel = OnboardingViewModel(
                taxCore: taxCore,
                profileRepository: profileRepository
            )
        }
        return _onboardingViewModel!
    }

    var householdViewModel: HouseholdViewModel {
        if _householdViewModel == nil {
            _householdViewModel = HouseholdViewModel(
                taxCore: taxCore,
                profileRepository: profileRepository,
                expenseRepository: expenseRepository
            )
        }
        return _householdViewModel!
    }

    // MARK: - Actions
    func completeOnboarding() async {
        // Save expenses from onboarding to the expense repository
        if let onboardingVM = _onboardingViewModel {
            for expense in onboardingVM.expenses {
                do {
                    try await expenseRepository.save(expense)
                } catch {
                    print("Failed to save expense: \(error)")
                }
            }
            // Ensure expense view model is initialized and reload
            await expenseViewModel.loadExpenses()
        }

        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    func resetOnboarding() {
        // Reset the flag
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")

        // Reset the onboarding view model state
        _onboardingViewModel?.reset()

        // Clear cached view models so they reload fresh data
        _incomeViewModel = nil
        _dashboardViewModel = nil
        _expenseViewModel = nil
        _householdViewModel = nil
    }

    /// Create a new profile and start onboarding
    func startNewProfile() {
        resetOnboarding()
    }

    /// Skip onboarding and go directly to dashboard (empty state)
    func skipOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // Reset view models
        _onboardingViewModel?.reset()
        _incomeViewModel = nil
        _dashboardViewModel = nil
        _expenseViewModel = nil
        _householdViewModel = nil
    }

    // MARK: - Debug / Development
    #if DEBUG
    /// Load mock profile data for development testing
    func loadMockData() async {
        // Create a realistic mock profile
        let mockProfile = FinancialProfile(
            name: "Demo Profile",
            income: IncomeProfile(
                grossSalary: 125000,
                payFrequency: .biWeekly,
                bonusAnnual: 10000
            ),
            location: LocationProfile(
                state: .california,
                filingStatus: .single
            ),
            deductions: DeductionProfile(
                traditional401k: 15000,
                healthInsurance: 3600,
                hsa: 2000
            ),
            householdType: .single
        )

        // Save the profile
        do {
            try await profileRepository.save(mockProfile)
        } catch {
            print("Failed to save mock profile: \(error)")
        }

        // Create mock expenses
        let mockExpenses: [Expense] = [
            Expense(name: "Rent", amount: 2200, frequency: .monthly, category: .home),
            Expense(name: "Groceries", amount: 600, frequency: .monthly, category: .necessities),
            Expense(name: "Car Payment", amount: 450, frequency: .monthly, category: .vehicle),
            Expense(name: "Car Insurance", amount: 150, frequency: .monthly, category: .vehicle),
            Expense(name: "Gas", amount: 200, frequency: .monthly, category: .vehicle),
            Expense(name: "Electric & Gas", amount: 120, frequency: .monthly, category: .home),
            Expense(name: "Internet", amount: 80, frequency: .monthly, category: .tech),
            Expense(name: "Phone", amount: 85, frequency: .monthly, category: .tech),
            Expense(name: "Netflix", amount: 15, frequency: .monthly, category: .entertainment),
            Expense(name: "Spotify", amount: 12, frequency: .monthly, category: .entertainment),
            Expense(name: "Gym", amount: 50, frequency: .monthly, category: .necessities),
            Expense(name: "Student Loans", amount: 400, frequency: .monthly, category: .debt),
        ]

        for expense in mockExpenses {
            do {
                try await expenseRepository.save(expense)
            } catch {
                print("Failed to save mock expense: \(error)")
            }
        }

        // Mark onboarding as complete
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // Reset all view models to pick up new data
        _incomeViewModel = nil
        _dashboardViewModel = nil
        _expenseViewModel = nil
        _scenarioViewModel = nil
        _householdViewModel = nil

        // Force reload all view models with new data
        await dashboardViewModel.loadData()
        await expenseViewModel.loadExpenses()
        await incomeViewModel.loadProfile()
    }

    /// Load mock household (two incomes) data for development testing
    func loadMockHouseholdData() async {
        // Create a mock household profile with partner
        let mockProfile = FinancialProfile(
            name: "Household Demo",
            income: IncomeProfile(
                grossSalary: 145000,
                payFrequency: .biWeekly,
                bonusAnnual: 15000
            ),
            location: LocationProfile(
                state: .texas,
                filingStatus: .marriedFilingJointly
            ),
            deductions: DeductionProfile(
                traditional401k: 20000,
                healthInsurance: 4800,
                hsa: 3200
            ),
            householdType: .twoIncomes,
            partnerProfile: PartnerProfile(
                name: "Alex",
                grossSalary: 95000,
                payFrequency: .biWeekly,
                state: .texas,
                filingStatus: .marriedFilingJointly
            )
        )

        // Save the profile
        do {
            try await profileRepository.save(mockProfile)
        } catch {
            print("Failed to save mock profile: \(error)")
        }

        // Create mock shared expenses
        let mockExpenses: [Expense] = [
            Expense(name: "Mortgage", amount: 2800, frequency: .monthly, category: .home, isShared: true),
            Expense(name: "HOA", amount: 350, frequency: .monthly, category: .home, isShared: true),
            Expense(name: "Groceries", amount: 900, frequency: .monthly, category: .necessities, isShared: true),
            Expense(name: "Utilities", amount: 250, frequency: .monthly, category: .home, isShared: true),
            Expense(name: "Internet", amount: 100, frequency: .monthly, category: .tech, isShared: true),
            Expense(name: "Car Payment (Primary)", amount: 550, frequency: .monthly, category: .vehicle),
            Expense(name: "Car Payment (Partner)", amount: 400, frequency: .monthly, category: .vehicle),
            Expense(name: "Car Insurance", amount: 280, frequency: .monthly, category: .vehicle, isShared: true),
            Expense(name: "Streaming Services", amount: 45, frequency: .monthly, category: .entertainment, isShared: true),
            Expense(name: "Date Night Fund", amount: 200, frequency: .monthly, category: .entertainment, isShared: true),
            Expense(name: "Pet Expenses", amount: 150, frequency: .monthly, category: .necessities, isShared: true),
            Expense(name: "Vacation Fund", amount: 500, frequency: .monthly, category: .finance, isShared: true),
        ]

        for expense in mockExpenses {
            do {
                try await expenseRepository.save(expense)
            } catch {
                print("Failed to save mock expense: \(error)")
            }
        }

        // Mark onboarding as complete
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // Reset all view models to pick up new data
        _incomeViewModel = nil
        _dashboardViewModel = nil
        _expenseViewModel = nil
        _scenarioViewModel = nil
        _householdViewModel = nil

        // Force reload all view models with new data
        await dashboardViewModel.loadData()
        await expenseViewModel.loadExpenses()
        await incomeViewModel.loadProfile()
    }
    #endif
}
