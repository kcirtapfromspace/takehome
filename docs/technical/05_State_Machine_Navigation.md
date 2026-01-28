# TakeHome Technical Architecture: State Machine & Navigation

## Overview

This document defines the app state management, navigation flow architecture, onboarding experience, and feature flag system for monetization tiers.

---

## 1. App State Machine

### State Diagram

```
                    ┌─────────────────┐
                    │     Launch      │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  Check Auth &   │
                    │  Data Status    │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  First Launch   │ │ Returning User  │ │  Data Migration │
│  (Onboarding)   │ │    (Main)       │ │    Required     │
└────────┬────────┘ └────────┬────────┘ └────────┬────────┘
         │                   │                   │
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│   Onboarding    │ │   Dashboard     │ │   Migration     │
│     Flow        │ │    (Active)     │ │     Flow        │
└────────┬────────┘ └────────┬────────┘ └────────┬────────┘
         │                   │                   │
         └───────────────────┴───────────────────┘
                             │
                    ┌────────▼────────┐
                    │  Main App Flow  │
                    └─────────────────┘
```

### App State Definition

```swift
import Foundation
import Combine

/// Top-level app state
enum AppState: Equatable {
    case launching
    case onboarding(OnboardingState)
    case migration(MigrationState)
    case main(MainState)
    case error(AppError)
}

/// Onboarding sub-states
enum OnboardingState: Equatable {
    case welcome
    case incomeEntry
    case locationEntry
    case deductionsEntry
    case reveal
    case expensesOptional
    case complete
}

/// Migration sub-states
enum MigrationState: Equatable {
    case checking
    case inProgress(progress: Double)
    case complete
    case failed(String)
}

/// Main app sub-states
enum MainState: Equatable {
    case dashboard
    case income
    case expenses
    case scenarios
    case household
    case settings
}

/// App errors
enum AppError: Error, Equatable {
    case dataCorruption
    case migrationFailed(String)
    case networkError(String)
    case unknown(String)
}
```

### State Manager

```swift
import Foundation
import Combine

final class AppStateManager: ObservableObject {

    @Published private(set) var state: AppState = .launching
    @Published private(set) var previousState: AppState?

    private let profileRepository: FinancialProfileRepositoryProtocol
    private let migrationManager: DataMigrationManager
    private let featureFlags: FeatureFlagServiceProtocol

    private var cancellables = Set<AnyCancellable>()

    init(
        profileRepository: FinancialProfileRepositoryProtocol,
        migrationManager: DataMigrationManager,
        featureFlags: FeatureFlagServiceProtocol
    ) {
        self.profileRepository = profileRepository
        self.migrationManager = migrationManager
        self.featureFlags = featureFlags
    }

    func initialize() {
        determineInitialState()
    }

    private func determineInitialState() {
        // Check if migration needed
        if migrationManager.needsMigration {
            transition(to: .migration(.checking))
            performMigration()
            return
        }

        // Check if user has completed onboarding
        profileRepository.getCurrentProfile()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        self?.transition(to: .error(.dataCorruption))
                    }
                },
                receiveValue: { [weak self] profile in
                    if profile != nil {
                        self?.transition(to: .main(.dashboard))
                    } else {
                        self?.transition(to: .onboarding(.welcome))
                    }
                }
            )
            .store(in: &cancellables)
    }

    func transition(to newState: AppState) {
        guard state != newState else { return }

        previousState = state
        state = newState

        // Log state transition
        Analytics.track(.stateTransition(from: previousState, to: newState))

        // Handle side effects
        handleStateTransition(from: previousState, to: newState)
    }

    private func handleStateTransition(from: AppState?, to: AppState) {
        switch to {
        case .main(.dashboard):
            // Refresh data when entering dashboard
            refreshDashboardData()

        case .onboarding(.complete):
            // Transition to main after onboarding complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.transition(to: .main(.dashboard))
            }

        case .migration(.complete):
            // Check for profile after migration
            determineInitialState()

        default:
            break
        }
    }

    private func performMigration() {
        migrationManager.migrate()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.transition(to: .migration(.failed(error.localizedDescription)))
                    }
                },
                receiveValue: { [weak self] progress in
                    if progress >= 1.0 {
                        self?.transition(to: .migration(.complete))
                    } else {
                        self?.transition(to: .migration(.inProgress(progress: progress)))
                    }
                }
            )
            .store(in: &cancellables)
    }

    private func refreshDashboardData() {
        // Trigger data refresh
    }

    // MARK: - Onboarding Actions

    func advanceOnboarding() {
        guard case .onboarding(let current) = state else { return }

        let next: OnboardingState
        switch current {
        case .welcome:
            next = .incomeEntry
        case .incomeEntry:
            next = .locationEntry
        case .locationEntry:
            next = .deductionsEntry
        case .deductionsEntry:
            next = .reveal
        case .reveal:
            next = .expensesOptional
        case .expensesOptional:
            next = .complete
        case .complete:
            return
        }

        transition(to: .onboarding(next))
    }

    func skipOnboardingStep() {
        guard case .onboarding(let current) = state else { return }

        // Only certain steps can be skipped
        switch current {
        case .deductionsEntry, .expensesOptional:
            advanceOnboarding()
        default:
            break
        }
    }

    func completeOnboarding(with profile: FinancialProfile) {
        profileRepository.save(profile)
            .flatMap { [weak self] _ -> AnyPublisher<Void, RepositoryError> in
                self?.profileRepository.setCurrentProfile(profile) ?? Empty().eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.transition(to: .error(.unknown(error.localizedDescription)))
                    }
                },
                receiveValue: { [weak self] in
                    self?.transition(to: .onboarding(.complete))
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Main Navigation

    func navigateTo(_ section: MainState) {
        guard case .main = state else { return }
        transition(to: .main(section))
    }
}
```

---

## 2. Navigation Architecture

### Navigation Stack with Coordinator

```swift
import SwiftUI

/// Navigation path items
enum NavigationDestination: Hashable {
    // Income
    case incomeDetails
    case taxBreakdown
    case timeframeDetail(Timeframe)

    // Expenses
    case expenseList
    case expenseDetail(UUID)
    case expenseCategory(ExpenseCategory)
    case addExpense

    // Scenarios
    case scenarioList
    case scenarioDetail(UUID)
    case createScenario(ScenarioType)
    case scenarioComparison(UUID)

    // Household
    case householdSetup
    case partnerProfile
    case expenseSplitting

    // Settings
    case settings
    case profileSettings
    case notificationSettings
    case dataExport
    case subscription
    case about
}

/// Main navigation coordinator
final class NavigationCoordinator: ObservableObject {

    @Published var path = NavigationPath()
    @Published var presentedSheet: SheetDestination?
    @Published var presentedFullScreen: FullScreenDestination?
    @Published var alertItem: AlertItem?

    func push(_ destination: NavigationDestination) {
        path.append(destination)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }

    func present(_ sheet: SheetDestination) {
        presentedSheet = sheet
    }

    func presentFullScreen(_ destination: FullScreenDestination) {
        presentedFullScreen = destination
    }

    func dismiss() {
        presentedSheet = nil
        presentedFullScreen = nil
    }

    func showAlert(_ alert: AlertItem) {
        alertItem = alert
    }
}

/// Sheet presentations
enum SheetDestination: Identifiable {
    case addExpense
    case editExpense(UUID)
    case createScenario
    case selectState
    case calculator

    var id: String {
        switch self {
        case .addExpense: return "addExpense"
        case .editExpense(let id): return "editExpense-\(id)"
        case .createScenario: return "createScenario"
        case .selectState: return "selectState"
        case .calculator: return "calculator"
        }
    }
}

/// Full screen presentations
enum FullScreenDestination: Identifiable {
    case onboarding
    case subscription
    case scenarioResult(UUID)

    var id: String {
        switch self {
        case .onboarding: return "onboarding"
        case .subscription: return "subscription"
        case .scenarioResult(let id): return "scenarioResult-\(id)"
        }
    }
}

/// Alert configuration
struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let primaryButton: AlertButton
    let secondaryButton: AlertButton?

    struct AlertButton {
        let title: String
        let style: ButtonStyle
        let action: () -> Void

        enum ButtonStyle {
            case `default`
            case cancel
            case destructive
        }
    }
}
```

### Tab-Based Navigation

```swift
import SwiftUI

struct MainTabView: View {
    @StateObject private var coordinator = NavigationCoordinator()
    @EnvironmentObject private var stateManager: AppStateManager
    @EnvironmentObject private var featureFlags: FeatureFlagService

    @State private var selectedTab: Tab = .dashboard

    enum Tab: String, CaseIterable {
        case dashboard
        case income
        case expenses
        case scenarios
        case settings

        var title: String {
            rawValue.capitalized
        }

        var icon: String {
            switch self {
            case .dashboard: return "chart.pie.fill"
            case .income: return "dollarsign.circle.fill"
            case .expenses: return "creditcard.fill"
            case .scenarios: return "sparkles"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(visibleTabs, id: \.self) { tab in
                NavigationStack(path: $coordinator.path) {
                    tabContent(for: tab)
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.icon)
                }
                .tag(tab)
            }
        }
        .environmentObject(coordinator)
        .sheet(item: $coordinator.presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
        .fullScreenCover(item: $coordinator.presentedFullScreen) { destination in
            fullScreenContent(for: destination)
        }
        .alert(item: $coordinator.alertItem) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                primaryButton: alertButton(alert.primaryButton),
                secondaryButton: alert.secondaryButton.map { alertButton($0) } ?? .cancel()
            )
        }
    }

    private var visibleTabs: [Tab] {
        var tabs: [Tab] = [.dashboard, .income, .expenses]

        if featureFlags.isEnabled(.scenarios) {
            tabs.append(.scenarios)
        }

        tabs.append(.settings)
        return tabs
    }

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .dashboard:
            DashboardView()
        case .income:
            IncomeView()
        case .expenses:
            ExpenseListView()
        case .scenarios:
            ScenarioListView()
        case .settings:
            SettingsView()
        }
    }

    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .incomeDetails:
            IncomeDetailsView()
        case .taxBreakdown:
            TaxBreakdownView()
        case .timeframeDetail(let timeframe):
            TimeframeDetailView(timeframe: timeframe)
        case .expenseList:
            ExpenseListView()
        case .expenseDetail(let id):
            ExpenseDetailView(expenseId: id)
        case .expenseCategory(let category):
            ExpenseCategoryView(category: category)
        case .addExpense:
            AddExpenseView()
        case .scenarioList:
            ScenarioListView()
        case .scenarioDetail(let id):
            ScenarioDetailView(scenarioId: id)
        case .createScenario(let type):
            CreateScenarioView(type: type)
        case .scenarioComparison(let id):
            ScenarioComparisonView(scenarioId: id)
        case .householdSetup:
            HouseholdSetupView()
        case .partnerProfile:
            PartnerProfileView()
        case .expenseSplitting:
            ExpenseSplittingView()
        case .settings:
            SettingsView()
        case .profileSettings:
            ProfileSettingsView()
        case .notificationSettings:
            NotificationSettingsView()
        case .dataExport:
            DataExportView()
        case .subscription:
            SubscriptionView()
        case .about:
            AboutView()
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: SheetDestination) -> some View {
        switch sheet {
        case .addExpense:
            AddExpenseView(isPresented: true)
        case .editExpense(let id):
            EditExpenseView(expenseId: id)
        case .createScenario:
            CreateScenarioSheet()
        case .selectState:
            StatePickerSheet()
        case .calculator:
            QuickCalculatorSheet()
        }
    }

    @ViewBuilder
    private func fullScreenContent(for destination: FullScreenDestination) -> some View {
        switch destination {
        case .onboarding:
            OnboardingFlow()
        case .subscription:
            SubscriptionFlow()
        case .scenarioResult(let id):
            ScenarioResultFullScreen(scenarioId: id)
        }
    }

    private func alertButton(_ button: AlertItem.AlertButton) -> Alert.Button {
        switch button.style {
        case .default:
            return .default(Text(button.title), action: button.action)
        case .cancel:
            return .cancel(Text(button.title), action: button.action)
        case .destructive:
            return .destructive(Text(button.title), action: button.action)
        }
    }
}
```

---

## 3. Onboarding Flow

### Onboarding State Machine

```swift
import SwiftUI
import Combine

final class OnboardingViewModel: ObservableObject {

    @Published var currentStep: OnboardingStep = .welcome
    @Published var profileData = OnboardingProfileData()
    @Published var calculatedResult: TaxCalculationResult?
    @Published var isCalculating = false
    @Published var canProceed = false

    private let calculationEngine: TaxCalculationEngineProtocol
    private let profileRepository: FinancialProfileRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    enum OnboardingStep: Int, CaseIterable {
        case welcome
        case income
        case location
        case deductions
        case reveal
        case expenses
        case complete

        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .income: return "Your Income"
            case .location: return "Where You Live"
            case .deductions: return "Deductions"
            case .reveal: return "Your Take-Home"
            case .expenses: return "Expenses"
            case .complete: return "All Set!"
            }
        }

        var subtitle: String {
            switch self {
            case .welcome: return "Let's calculate your real take-home pay"
            case .income: return "Enter your gross annual salary"
            case .location: return "Select your state for accurate taxes"
            case .deductions: return "Add your pre-tax deductions"
            case .reveal: return "Here's what you actually take home"
            case .expenses: return "Optional: Track your expenses"
            case .complete: return "You're ready to go!"
            }
        }

        var progress: Double {
            Double(rawValue) / Double(OnboardingStep.allCases.count - 1)
        }

        var isSkippable: Bool {
            switch self {
            case .deductions, .expenses:
                return true
            default:
                return false
            }
        }
    }

    init(
        calculationEngine: TaxCalculationEngineProtocol,
        profileRepository: FinancialProfileRepositoryProtocol
    ) {
        self.calculationEngine = calculationEngine
        self.profileRepository = profileRepository

        setupValidation()
    }

    private func setupValidation() {
        $profileData
            .map { [weak self] data -> Bool in
                self?.validateCurrentStep(with: data) ?? false
            }
            .assign(to: &$canProceed)
    }

    private func validateCurrentStep(with data: OnboardingProfileData) -> Bool {
        switch currentStep {
        case .welcome:
            return true
        case .income:
            return data.grossSalary > 0
        case .location:
            return data.state != nil
        case .deductions:
            return true // Optional
        case .reveal:
            return calculatedResult != nil
        case .expenses:
            return true // Optional
        case .complete:
            return true
        }
    }

    func next() {
        guard canProceed else { return }

        // Handle step-specific actions before advancing
        switch currentStep {
        case .deductions:
            // Calculate before showing reveal
            calculateTakeHome()
        case .complete:
            // Save and finish
            completeOnboarding()
            return
        default:
            break
        }

        // Advance to next step
        if let nextIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
           nextIndex + 1 < OnboardingStep.allCases.count {
            currentStep = OnboardingStep.allCases[nextIndex + 1]
        }
    }

    func skip() {
        guard currentStep.isSkippable else { return }
        next()
    }

    func back() {
        if let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
           currentIndex > 0 {
            currentStep = OnboardingStep.allCases[currentIndex - 1]
        }
    }

    private func calculateTakeHome() {
        isCalculating = true

        let input = TaxCalculationInput(
            grossIncome: profileData.grossSalary,
            filingStatus: profileData.filingStatus,
            state: profileData.state ?? .california,
            payFrequency: profileData.payFrequency,
            preTaxDeductions: profileData.deductions,
            postTaxDeductions: [],
            retirementContributions: profileData.retirement
        )

        // Simulate async calculation for smooth UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.calculatedResult = self?.calculationEngine.calculate(input: input)
            self?.isCalculating = false
            self?.currentStep = .reveal
        }
    }

    private func completeOnboarding() {
        let profile = FinancialProfile(
            income: Income(grossAnnualSalary: profileData.grossSalary),
            payFrequency: profileData.payFrequency,
            state: profileData.state ?? .california,
            filingStatus: profileData.filingStatus
        )

        profileRepository.save(profile)
            .flatMap { [weak self] saved in
                self?.profileRepository.setCurrentProfile(saved) ?? Empty().eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] in
                    self?.currentStep = .complete
                    // Notify app to transition
                    NotificationCenter.default.post(name: .onboardingComplete, object: nil)
                }
            )
            .store(in: &cancellables)
    }
}

/// Data collected during onboarding
struct OnboardingProfileData {
    var grossSalary: Decimal = 0
    var payFrequency: PayFrequency = .biWeekly
    var state: USState?
    var filingStatus: FilingStatus = .single
    var deductions: [Deduction] = []
    var retirement: RetirementContributions?
}

extension Notification.Name {
    static let onboardingComplete = Notification.Name("onboardingComplete")
}
```

### Onboarding Flow View

```swift
import SwiftUI

struct OnboardingFlow: View {
    @StateObject private var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: OnboardingViewModel = DependencyContainer.shared.makeOnboardingViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressView(value: viewModel.currentStep.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                .padding(.horizontal)

            // Step content
            TabView(selection: $viewModel.currentStep) {
                ForEach(OnboardingViewModel.OnboardingStep.allCases, id: \.self) { step in
                    stepContent(for: step)
                        .tag(step)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: viewModel.currentStep)

            // Navigation buttons
            HStack(spacing: 16) {
                if viewModel.currentStep != .welcome {
                    Button("Back") {
                        viewModel.back()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if viewModel.currentStep.isSkippable {
                    Button("Skip") {
                        viewModel.skip()
                    }
                    .foregroundColor(.secondary)
                }

                Button(viewModel.currentStep == .complete ? "Get Started" : "Continue") {
                    viewModel.next()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canProceed)
            }
            .padding()
        }
    }

    @ViewBuilder
    private func stepContent(for step: OnboardingViewModel.OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeStepView()
        case .income:
            IncomeStepView(
                salary: $viewModel.profileData.grossSalary,
                frequency: $viewModel.profileData.payFrequency
            )
        case .location:
            LocationStepView(
                state: $viewModel.profileData.state,
                filingStatus: $viewModel.profileData.filingStatus
            )
        case .deductions:
            DeductionsStepView(deductions: $viewModel.profileData.deductions)
        case .reveal:
            RevealStepView(
                result: viewModel.calculatedResult,
                isCalculating: viewModel.isCalculating
            )
        case .expenses:
            ExpensesStepView()
        case .complete:
            CompleteStepView()
        }
    }
}

// MARK: - Step Views

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)

            Text("Welcome to TakeHome")
                .font(.largeTitle.bold())

            Text("Let's calculate your real take-home pay after taxes and deductions.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }
}

struct RevealStepView: View {
    let result: TaxCalculationResult?
    let isCalculating: Bool

    var body: some View {
        VStack(spacing: 24) {
            if isCalculating {
                ProgressView()
                    .scaleEffect(2)
                Text("Calculating...")
                    .font(.headline)
            } else if let result = result {
                VStack(spacing: 8) {
                    Text("Your Gross Salary")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(result.income.gross.currencyFormatted)
                        .font(.title2)
                }

                Divider()
                    .padding(.vertical)

                VStack(spacing: 8) {
                    Text("YOU TAKE HOME")
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)

                    Text(result.income.net.currencyFormatted)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.green)

                    Text("\(result.income.timeframes.monthly.currencyFormatted)/month")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 4) {
                    Text("That's \(result.effectiveRates.totalPercent.formatted(.percent.precision(.fractionLength(1)))) in taxes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
            }
        }
        .padding()
    }
}
```

---

## 4. Feature Flags for Monetization

### Feature Flag System

```swift
import Foundation
import Combine

/// Available features that can be gated
enum Feature: String, CaseIterable {
    // Free tier
    case basicCalculator = "basic_calculator"
    case singleProfile = "single_profile"
    case annualMonthlyView = "annual_monthly_view"
    case limitedScenarios = "limited_scenarios"

    // Pro tier
    case unlimitedProfiles = "unlimited_profiles"
    case allTimeframes = "all_timeframes"
    case unlimitedScenarios = "unlimited_scenarios"
    case householdMode = "household_mode"
    case retirementProjections = "retirement_projections"
    case salaryGrowthModeling = "salary_growth_modeling"
    case creditCardPayoff = "credit_card_payoff"
    case dataExport = "data_export"

    // Business tier
    case multipleIncomes = "multiple_incomes"
    case contractorSupport = "contractor_1099"
    case quarterlyEstimates = "quarterly_estimates"
    case advancedOptimization = "advanced_optimization"
    case advisorSharing = "advisor_sharing"
    case apiAccess = "api_access"

    var tier: SubscriptionTier {
        switch self {
        case .basicCalculator, .singleProfile, .annualMonthlyView, .limitedScenarios:
            return .free
        case .unlimitedProfiles, .allTimeframes, .unlimitedScenarios,
             .householdMode, .retirementProjections, .salaryGrowthModeling,
             .creditCardPayoff, .dataExport:
            return .pro
        case .multipleIncomes, .contractorSupport, .quarterlyEstimates,
             .advancedOptimization, .advisorSharing, .apiAccess:
            return .business
        }
    }

    var displayName: String {
        switch self {
        case .basicCalculator: return "Tax Calculator"
        case .singleProfile: return "Single Profile"
        case .annualMonthlyView: return "Annual & Monthly Views"
        case .limitedScenarios: return "3 Scenarios"
        case .unlimitedProfiles: return "Unlimited Profiles"
        case .allTimeframes: return "All 6 Timeframe Views"
        case .unlimitedScenarios: return "Unlimited Scenarios"
        case .householdMode: return "Household Mode"
        case .retirementProjections: return "Retirement Projections"
        case .salaryGrowthModeling: return "Salary Growth Modeling"
        case .creditCardPayoff: return "Credit Card Payoff Planner"
        case .dataExport: return "Export Data"
        case .multipleIncomes: return "Multiple Income Sources"
        case .contractorSupport: return "1099 Contractor Support"
        case .quarterlyEstimates: return "Quarterly Tax Estimates"
        case .advancedOptimization: return "Advanced Tax Optimization"
        case .advisorSharing: return "Financial Advisor Sharing"
        case .apiAccess: return "API Access"
        }
    }
}

/// Subscription tiers
enum SubscriptionTier: String, Comparable {
    case free
    case pro
    case business

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .business: return "Business"
        }
    }

    var price: String {
        switch self {
        case .free: return "$0"
        case .pro: return "$6.99/month"
        case .business: return "$14.99/month"
        }
    }

    var features: [Feature] {
        Feature.allCases.filter { $0.tier <= self }
    }

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        let order: [SubscriptionTier] = [.free, .pro, .business]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}
```

### Feature Flag Service

```swift
import Foundation
import Combine
import StoreKit

protocol FeatureFlagServiceProtocol: ObservableObject {
    var currentTier: SubscriptionTier { get }
    func isEnabled(_ feature: Feature) -> Bool
    func checkAccess(_ feature: Feature) -> FeatureAccessResult
    func requestUpgrade(for feature: Feature)
}

enum FeatureAccessResult {
    case allowed
    case requiresUpgrade(to: SubscriptionTier)
    case limitReached(current: Int, max: Int)
}

final class FeatureFlagService: FeatureFlagServiceProtocol, ObservableObject {

    @Published private(set) var currentTier: SubscriptionTier = .free

    private let subscriptionManager: SubscriptionManagerProtocol
    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    // Usage tracking for limited features
    private var scenarioCount: Int {
        userDefaults.integer(forKey: "scenarioCount")
    }

    private let maxFreeScenarios = 3

    init(
        subscriptionManager: SubscriptionManagerProtocol,
        userDefaults: UserDefaults = .standard
    ) {
        self.subscriptionManager = subscriptionManager
        self.userDefaults = userDefaults

        // Subscribe to subscription changes
        subscriptionManager.currentSubscription
            .map { $0?.tier ?? .free }
            .assign(to: &$currentTier)
    }

    func isEnabled(_ feature: Feature) -> Bool {
        switch checkAccess(feature) {
        case .allowed:
            return true
        case .requiresUpgrade, .limitReached:
            return false
        }
    }

    func checkAccess(_ feature: Feature) -> FeatureAccessResult {
        // Check tier requirement
        if feature.tier > currentTier {
            return .requiresUpgrade(to: feature.tier)
        }

        // Check usage limits for free tier
        if currentTier == .free {
            switch feature {
            case .limitedScenarios:
                if scenarioCount >= maxFreeScenarios {
                    return .limitReached(current: scenarioCount, max: maxFreeScenarios)
                }
            default:
                break
            }
        }

        return .allowed
    }

    func requestUpgrade(for feature: Feature) {
        // Present upgrade flow
        NotificationCenter.default.post(
            name: .showUpgradePrompt,
            object: feature.tier
        )
    }

    // MARK: - Usage Tracking

    func incrementScenarioCount() {
        let count = scenarioCount + 1
        userDefaults.set(count, forKey: "scenarioCount")
    }

    func resetMonthlyUsage() {
        // Called at start of new billing period
        userDefaults.set(0, forKey: "scenarioCount")
    }
}

extension Notification.Name {
    static let showUpgradePrompt = Notification.Name("showUpgradePrompt")
}
```

### Feature Gate View Modifier

```swift
import SwiftUI

/// View modifier to gate features
struct FeatureGateModifier: ViewModifier {
    @EnvironmentObject private var featureFlags: FeatureFlagService

    let feature: Feature
    let showUpgradePrompt: Bool

    @State private var showingUpgrade = false

    func body(content: Content) -> some View {
        Group {
            switch featureFlags.checkAccess(feature) {
            case .allowed:
                content

            case .requiresUpgrade(let tier):
                if showUpgradePrompt {
                    upgradePromptView(tier: tier)
                } else {
                    content
                        .disabled(true)
                        .overlay(lockedOverlay(tier: tier))
                }

            case .limitReached(let current, let max):
                content
                    .disabled(true)
                    .overlay(limitOverlay(current: current, max: max))
            }
        }
        .sheet(isPresented: $showingUpgrade) {
            SubscriptionView(highlightedTier: feature.tier)
        }
    }

    private func upgradePromptView(tier: SubscriptionTier) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text(feature.displayName)
                .font(.headline)

            Text("Upgrade to \(tier.displayName) to unlock")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Upgrade") {
                showingUpgrade = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func lockedOverlay(tier: SubscriptionTier) -> some View {
        ZStack {
            Color.black.opacity(0.3)

            VStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.white)
                Text("\(tier.displayName) Feature")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
    }

    private func limitOverlay(current: Int, max: Int) -> some View {
        ZStack {
            Color.black.opacity(0.3)

            VStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.yellow)
                Text("Limit reached (\(current)/\(max))")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
    }
}

extension View {
    func featureGated(_ feature: Feature, showUpgradePrompt: Bool = false) -> some View {
        modifier(FeatureGateModifier(feature: feature, showUpgradePrompt: showUpgradePrompt))
    }
}

// MARK: - Usage Example

struct TimeframePickerView: View {
    @Binding var selectedTimeframe: Timeframe
    @EnvironmentObject private var featureFlags: FeatureFlagService

    var body: some View {
        Picker("Timeframe", selection: $selectedTimeframe) {
            // Always available
            Text("Annual").tag(Timeframe.annual)
            Text("Monthly").tag(Timeframe.monthly)

            // Pro feature
            if featureFlags.isEnabled(.allTimeframes) {
                Text("Bi-Weekly").tag(Timeframe.biWeekly)
                Text("Weekly").tag(Timeframe.weekly)
                Text("Daily").tag(Timeframe.daily)
                Text("Hourly").tag(Timeframe.hourly)
            } else {
                Text("Bi-Weekly 🔒").tag(Timeframe.biWeekly)
                    .disabled(true)
            }
        }
    }
}
```

---

## 5. Deep Linking

```swift
import Foundation

/// Deep link handling
enum DeepLink {
    case dashboard
    case income
    case scenario(id: UUID)
    case expense(id: UUID)
    case settings
    case subscription

    init?(url: URL) {
        guard url.scheme == "takehome",
              let host = url.host else {
            return nil
        }

        switch host {
        case "dashboard":
            self = .dashboard
        case "income":
            self = .income
        case "scenario":
            if let idString = url.pathComponents.dropFirst().first,
               let id = UUID(uuidString: idString) {
                self = .scenario(id: id)
            } else {
                return nil
            }
        case "expense":
            if let idString = url.pathComponents.dropFirst().first,
               let id = UUID(uuidString: idString) {
                self = .expense(id: id)
            } else {
                return nil
            }
        case "settings":
            self = .settings
        case "subscribe":
            self = .subscription
        default:
            return nil
        }
    }
}

final class DeepLinkHandler {

    private let coordinator: NavigationCoordinator
    private let stateManager: AppStateManager

    init(coordinator: NavigationCoordinator, stateManager: AppStateManager) {
        self.coordinator = coordinator
        self.stateManager = stateManager
    }

    func handle(_ link: DeepLink) {
        // Ensure we're in main state
        guard case .main = stateManager.state else {
            // Queue for later
            return
        }

        switch link {
        case .dashboard:
            coordinator.popToRoot()

        case .income:
            coordinator.popToRoot()
            coordinator.push(.incomeDetails)

        case .scenario(let id):
            coordinator.popToRoot()
            coordinator.push(.scenarioDetail(id))

        case .expense(let id):
            coordinator.popToRoot()
            coordinator.push(.expenseDetail(id))

        case .settings:
            coordinator.popToRoot()
            coordinator.push(.settings)

        case .subscription:
            coordinator.presentFullScreen(.subscription)
        }
    }
}
```

---

## Summary

| Component | Purpose | Implementation |
|-----------|---------|----------------|
| **App State Machine** | Top-level app state | Enum-based states with transitions |
| **Navigation** | Screen navigation | NavigationPath + Coordinator |
| **Onboarding** | First-time user flow | Step-based flow with validation |
| **Feature Flags** | Monetization gating | Tier-based access control |
| **Deep Linking** | External navigation | URL scheme handling |

The architecture provides:
- ✅ Clear state management with predictable transitions
- ✅ Type-safe navigation with SwiftUI's NavigationStack
- ✅ Smooth onboarding experience
- ✅ Flexible feature gating for monetization
- ✅ Deep link support for external integrations
