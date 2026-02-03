import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var container: DependencyContainer

    var body: some View {
        OnboardingContentView(viewModel: container.onboardingViewModel, container: container)
    }
}

// Separate view that directly observes the ViewModel
private struct OnboardingContentView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let container: DependencyContainer
    @State private var showExitConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress Bar
                ProgressView(value: viewModel.progress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal)

                // Content - Display current step directly
                stepView(for: viewModel.currentStep)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                    .id(viewModel.currentStep) // Force view recreation on step change
                    .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)

                // Navigation Buttons
                navigationButtons
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Show exit button on all steps except welcome and complete
                    if viewModel.currentStep != .welcome && viewModel.currentStep != .complete {
                        Button {
                            showExitConfirmation = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .confirmationDialog(
                "Exit Setup?",
                isPresented: $showExitConfirmation,
                titleVisibility: .visible
            ) {
                Button("Exit Without Saving", role: .destructive) {
                    // Reset onboarding state and skip to dashboard
                    viewModel.reset()
                    // Mark as "completed" so user goes to dashboard
                    // They can create a profile from there
                    container.skipOnboarding()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You can create a profile anytime from the dashboard.")
            }
        }
    }

    // MARK: - Step Views
    @ViewBuilder
    private func stepView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeStepView()

        case .householdType:
            HouseholdTypeStepView(
                householdType: Binding(
                    get: { viewModel.householdType },
                    set: { viewModel.householdType = $0 }
                )
            )

        case .income:
            IncomeStepView(
                grossSalary: Binding(
                    get: { viewModel.grossSalary },
                    set: { viewModel.grossSalary = $0 }
                ),
                payFrequency: Binding(
                    get: { viewModel.payFrequency },
                    set: { viewModel.payFrequency = $0 }
                ),
                salaryInputFrequency: Binding(
                    get: { viewModel.salaryInputFrequency },
                    set: { viewModel.salaryInputFrequency = $0 }
                )
            )

        case .partnerIncome:
            PartnerIncomeStepView(
                partnerName: Binding(
                    get: { viewModel.partnerName },
                    set: { viewModel.partnerName = $0 }
                ),
                grossSalary: Binding(
                    get: { viewModel.partnerGrossSalary },
                    set: { viewModel.partnerGrossSalary = $0 }
                ),
                payFrequency: Binding(
                    get: { viewModel.partnerPayFrequency },
                    set: { viewModel.partnerPayFrequency = $0 }
                ),
                salaryInputFrequency: Binding(
                    get: { viewModel.partnerSalaryInputFrequency },
                    set: { viewModel.partnerSalaryInputFrequency = $0 }
                ),
                selectedState: Binding(
                    get: { viewModel.partnerState },
                    set: { viewModel.partnerState = $0 }
                ),
                filingStatus: Binding(
                    get: { viewModel.partnerFilingStatus },
                    set: { viewModel.partnerFilingStatus = $0 }
                ),
                availableStates: viewModel.availableStates,
                availableFilingStatuses: viewModel.availableFilingStatuses
            )

        case .householdSummary:
            HouseholdSummaryStepView(
                yourName: "You",
                yourSalary: viewModel.grossSalaryDecimal,
                yourSharePercentage: viewModel.yourSharePercentage,
                partnerName: viewModel.partnerName,
                partnerSalary: viewModel.partnerGrossSalaryDecimal,
                partnerSharePercentage: viewModel.partnerSharePercentage,
                combinedSalary: viewModel.combinedGrossSalary
            )

        case .location:
            LocationStepView(
                selectedState: Binding(
                    get: { viewModel.selectedState },
                    set: { viewModel.selectedState = $0 }
                ),
                filingStatus: Binding(
                    get: { viewModel.filingStatus },
                    set: { viewModel.filingStatus = $0 }
                ),
                availableStates: viewModel.availableStates,
                availableFilingStatuses: viewModel.availableFilingStatuses
            )

        case .deductionSetup:
            DeductionSetupStepView(
                deductionSetupMode: Binding(
                    get: { viewModel.deductionSetupMode },
                    set: { viewModel.deductionSetupMode = $0 }
                ),
                traditional401k: Binding(
                    get: { viewModel.traditional401k },
                    set: { viewModel.traditional401k = $0 }
                ),
                traditional401kInputType: Binding(
                    get: { viewModel.traditional401kInputType },
                    set: { viewModel.traditional401kInputType = $0 }
                ),
                healthInsurance: Binding(
                    get: { viewModel.healthInsurance },
                    set: { viewModel.healthInsurance = $0 }
                ),
                healthInsuranceInputType: Binding(
                    get: { viewModel.healthInsuranceInputType },
                    set: { viewModel.healthInsuranceInputType = $0 }
                ),
                grossSalary: viewModel.grossSalaryDecimal
            )

        case .deductionsPreTax:
            DetailedDeductionsStepView(
                isPreTax: true,
                deductionEntries: Binding(
                    get: { viewModel.deductionEntries },
                    set: { viewModel.deductionEntries = $0 }
                ),
                grossSalary: viewModel.grossSalaryDecimal,
                payFrequency: viewModel.payFrequency,
                onUpdateEntry: { viewModel.updateDeductionEntry($0) },
                onToggleEntry: { viewModel.toggleDeductionEntry(id: $0) }
            )

        case .deductionsPostTax:
            DetailedDeductionsStepView(
                isPreTax: false,
                deductionEntries: Binding(
                    get: { viewModel.deductionEntries },
                    set: { viewModel.deductionEntries = $0 }
                ),
                grossSalary: viewModel.grossSalaryDecimal,
                payFrequency: viewModel.payFrequency,
                onUpdateEntry: { viewModel.updateDeductionEntry($0) },
                onToggleEntry: { viewModel.toggleDeductionEntry(id: $0) }
            )

        case .reveal:
            RevealStepView(
                result: viewModel.calculatedResult,
                isAnimating: viewModel.isAnimatingReveal
            )

        case .expenses:
            ExpensesStepView(
                expenses: Binding(
                    get: { viewModel.expenses },
                    set: { viewModel.expenses = $0 }
                ),
                onAddExpense: { viewModel.addExpense($0) },
                onUpdateExpense: { viewModel.updateExpense($0) },
                onRemoveExpense: { viewModel.removeExpense(id: $0) }
            )

        case .complete:
            CompleteStepView {
                await container.completeOnboarding()
            }
        }
    }

    // MARK: - Navigation Buttons
    @ViewBuilder
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if viewModel.currentStep != .welcome && viewModel.currentStep != .complete {
                Button("Back") {
                    viewModel.back()
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if viewModel.currentStep == .expenses {
                Button("Skip") {
                    Task {
                        await viewModel.skip()
                    }
                }
                .buttonStyle(.bordered)
            }

            if viewModel.currentStep != .complete {
                Button(nextButtonTitle(for: viewModel.currentStep)) {
                    Task {
                        await viewModel.next()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canProceed)
            }
        }
        .padding()
    }

    private func nextButtonTitle(for step: OnboardingStep) -> String {
        switch step {
        case .reveal:
            return "Continue"
        case .deductionSetup where viewModel.deductionSetupMode == .quick:
            return "Calculate"
        case .deductionsPostTax:
            return "Calculate"
        default:
            return "Next"
        }
    }
}

// MARK: - Welcome Step
struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "hand.wave.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)

            VStack(spacing: 16) {
                Text("Welcome to TakeHome")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Let's calculate your real take-home pay and help you track your finances.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            VStack(spacing: 12) {
                FeatureRow(icon: "dollarsign.circle.fill", title: "See your actual take-home")
                FeatureRow(icon: "chart.bar.fill", title: "Track expenses by category")
                FeatureRow(icon: "slider.horizontal.3", title: "Run what-if scenarios")
            }
            .padding()

            Spacer()
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            Text(title)
                .font(.headline)

            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - Income Step
struct IncomeStepView: View {
    @Binding var grossSalary: String
    @Binding var payFrequency: PayFrequency
    @Binding var salaryInputFrequency: DeductionFrequency

    // Computed annual salary for display
    private var annualSalary: Decimal {
        let raw = Decimal(string: grossSalary.replacingOccurrences(of: ",", with: "")) ?? 0
        return salaryInputFrequency.toAnnual(raw, payFrequency: payFrequency)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 20)

                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)

                VStack(spacing: 8) {
                    Text("What's your salary?")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Enter your gross (before taxes) salary")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 16) {
                    // Salary Input
                    HStack {
                        Text("$")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)

                        TextField("100,000", text: $grossSalary)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.leading)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Salary Frequency Toggle
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter amount as:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Picker("Salary Input Frequency", selection: $salaryInputFrequency) {
                            ForEach(DeductionFrequency.allCases) { freq in
                                Text(freq.displayName).tag(freq)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Annual Summary Card
                    if annualSalary > 0 && salaryInputFrequency != .annual {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Annual Salary")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatCurrency(annualSalary))
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Monthly")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatCurrency(annualSalary / 12))
                                    .font(.headline)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }

                    Divider()
                        .padding(.vertical, 8)

                    // Pay Frequency
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pay Frequency")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Picker("Pay Frequency", selection: $payFrequency) {
                            ForEach(PayFrequency.allCases, id: \.self) { frequency in
                                Text(frequency.displayName).tag(frequency)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(.horizontal)

                Spacer()
                    .frame(height: 60)
            }
        }
        .padding()
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

// MARK: - Location Step
struct LocationStepView: View {
    @Binding var selectedState: USState
    @Binding var filingStatus: FilingStatus
    let availableStates: [USState]
    let availableFilingStatuses: [FilingStatus]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "location.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            VStack(spacing: 8) {
                Text("Where do you live?")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("This affects your state income tax")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 16) {
                Picker("State", selection: $selectedState) {
                    ForEach(availableStates) { state in
                        Text(state.displayName).tag(state)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 150)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Filing Status")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("Filing Status", selection: $filingStatus) {
                        ForEach(availableFilingStatuses) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)

            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Household Summary Step
struct HouseholdSummaryStepView: View {
    let yourName: String
    let yourSalary: Decimal
    let yourSharePercentage: Double
    let partnerName: String
    let partnerSalary: Decimal
    let partnerSharePercentage: Double
    let combinedSalary: Decimal

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 20)

                Image(systemName: "house.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)

                VStack(spacing: 8) {
                    Text("Your Household")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Here's your combined income")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Income Cards
                VStack(spacing: 12) {
                    // Your Income Card
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 10, height: 10)
                                Text(yourName)
                                    .font(.headline)
                            }
                            Text(formatCurrency(yourSalary) + "/year")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        Text("\(Int(yourSharePercentage))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)

                    // Partner Income Card
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 10, height: 10)
                                Text(partnerName.isEmpty ? "Partner" : partnerName)
                                    .font(.headline)
                            }
                            Text(formatCurrency(partnerSalary) + "/year")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        Text("\(Int(partnerSharePercentage))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                // Split Bar
                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * CGFloat(yourSharePercentage / 100))

                            Rectangle()
                                .fill(Color.green)
                        }
                    }
                    .frame(height: 12)
                    .cornerRadius(6)

                    HStack {
                        Text("Your share")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Spacer()
                        Text("\(partnerName.isEmpty ? "Partner" : partnerName)'s share")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal)

                // Combined Total
                VStack(spacing: 8) {
                    Text("Combined Household Income")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(formatCurrency(combinedSalary))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("per year")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)

                // Info Text
                Text("Shared expenses will be split proportionally based on each person's income contribution")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
                    .frame(height: 60)
            }
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

// MARK: - Reveal Step
struct RevealStepView: View {
    let result: TaxCalculationResult?
    let isAnimating: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            if isAnimating {
                ProgressView()
                    .scaleEffect(2)

                Text("Calculating...")
                    .font(.headline)
                    .foregroundColor(.secondary)
            } else if let result = result {
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)

                VStack(spacing: 8) {
                    Text("Your Take-Home Pay")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    Text(formatCurrency(result.netAnnual))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.green)

                    Text("per year")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 32) {
                    VStack {
                        Text(formatCurrency(result.netMonthly))
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Monthly")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack {
                        Text(formatCurrency(result.netBiWeekly))
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Bi-Weekly")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack {
                        Text(formatCurrency(result.netHourly))
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Hourly")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()

                VStack(spacing: 4) {
                    Text("Total Taxes: \(formatCurrency(result.totalTaxes))")
                        .font(.subheadline)
                    Text("Effective Rate: \(formatPercentage(result.totalEffectiveRate))")
                        .font(.subheadline)
                }
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = value >= 100 ? 0 : 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }

    private func formatPercentage(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: (value / 100) as NSDecimalNumber) ?? "0%"
    }
}

// MARK: - Expenses Step
struct ExpensesStepView: View {
    @Binding var expenses: [Expense]
    let onAddExpense: (Expense) -> Void
    let onUpdateExpense: (Expense) -> Void
    let onRemoveExpense: (UUID) -> Void

    @State private var expandedCategory: ExpenseCategory?
    @State private var showingAddExpense = false
    @State private var selectedCategory: ExpenseCategory = .other
    @State private var editingExpense: Expense?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.accentColor)

                    Text("Track Your Expenses")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Tap a category to add expenses")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // Summary if expenses exist
                if !expenses.isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Monthly")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatCurrency(totalMonthly))
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Annual")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatCurrency(totalAnnual))
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                // Category List
                VStack(spacing: 12) {
                    ForEach(ExpenseCategory.allCases) { category in
                        CategoryExpenseCard(
                            category: category,
                            expenses: expenses.filter { $0.category == category },
                            isExpanded: expandedCategory == category,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedCategory == category {
                                        expandedCategory = nil
                                    } else {
                                        expandedCategory = category
                                    }
                                }
                            },
                            onAddExpense: {
                                selectedCategory = category
                                showingAddExpense = true
                            },
                            onQuickAddExpense: { expense in
                                onAddExpense(expense)
                            },
                            onEditExpense: { expense in
                                editingExpense = expense
                            },
                            onRemoveExpense: onRemoveExpense
                        )
                    }
                }
                .padding(.horizontal)

                Text("You can also add expenses later from the dashboard")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 80)
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            OnboardingAddExpenseView(
                category: selectedCategory,
                onSave: { expense in
                    onAddExpense(expense)
                }
            )
        }
        .sheet(item: $editingExpense) { expense in
            OnboardingEditExpenseView(
                expense: expense,
                onSave: { updatedExpense in
                    onUpdateExpense(updatedExpense)
                }
            )
        }
    }

    private var totalMonthly: Decimal {
        expenses.reduce(Decimal(0)) { $0 + $1.monthlyAmount }
    }

    private var totalAnnual: Decimal {
        expenses.reduce(Decimal(0)) { $0 + $1.annualAmount }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

// MARK: - Category Expense Card
private struct CategoryExpenseCard: View {
    let category: ExpenseCategory
    let expenses: [Expense]
    let isExpanded: Bool
    let onTap: () -> Void
    let onAddExpense: () -> Void
    let onQuickAddExpense: (Expense) -> Void
    let onEditExpense: (Expense) -> Void
    let onRemoveExpense: (UUID) -> Void

    private var categoryTotal: Decimal {
        expenses.reduce(Decimal(0)) { $0 + $1.monthlyAmount }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Row
            Button(action: onTap) {
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(.accentColor)
                        .frame(width: 28)

                    Text(category.displayName)
                        .font(.headline)

                    Spacer()

                    if !expenses.isEmpty {
                        Text(formatCurrency(categoryTotal) + "/mo")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .foregroundColor(.primary)
            }
            .buttonStyle(.plain)

            // Expanded Content
            if isExpanded {
                VStack(spacing: 0) {
                    // Existing expenses
                    ForEach(expenses) { expense in
                        Button {
                            onEditExpense(expense)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(expense.name)
                                        .font(.subheadline)
                                    HStack(spacing: 4) {
                                        Text(expense.frequency.displayName)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("•")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("Tap to edit")
                                            .font(.caption)
                                            .foregroundColor(.accentColor)
                                    }
                                }

                                Spacer()

                                Text(formatCurrency(expense.amount))
                                    .font(.subheadline)
                                    .foregroundColor(.primary)

                                Button {
                                    onRemoveExpense(expense.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray5))
                        }
                        .buttonStyle(.plain)
                    }

                    // Add button
                    Button(action: onAddExpense) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                            Text("Add \(category.displayName) Expense")
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray5))
                    }
                    .buttonStyle(.plain)

                    // Quick add suggestions
                    if let suggestions = ExpenseCategory.defaultExpenses[category], !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Common expenses:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.top, 8)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(suggestions.filter { name in
                                        !expenses.contains { $0.name == name }
                                    }, id: \.self) { suggestion in
                                        QuickAddChip(
                                            name: suggestion,
                                            category: category,
                                            onAdd: { expense in
                                                onQuickAddExpense(expense)
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 12)
                            }
                        }
                        .background(Color(.systemGray5))
                    }
                }
            }
        }
        .cornerRadius(12)
        .clipped()
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

// MARK: - Quick Add Chip
private struct QuickAddChip: View {
    let name: String
    let category: ExpenseCategory
    let onAdd: (Expense) -> Void

    @State private var showingAmountInput = false
    @State private var amount = ""

    var body: some View {
        if showingAmountInput {
            HStack(spacing: 4) {
                Text("$")
                    .font(.caption)
                TextField("0", text: $amount)
                    .font(.caption)
                    .keyboardType(.numberPad)
                    .frame(width: 50)

                Button {
                    if let amountDecimal = Decimal(string: amount), amountDecimal > 0 {
                        let expense = Expense(
                            name: name,
                            amount: amountDecimal,
                            frequency: .monthly,
                            category: category
                        )
                        onAdd(expense)
                        showingAmountInput = false
                        amount = ""
                    }
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }

                Button {
                    showingAmountInput = false
                    amount = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.accentColor, lineWidth: 1)
            )
        } else {
            Button {
                showingAmountInput = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.caption2)
                    Text(name)
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.systemBackground))
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Onboarding Add Expense View
struct OnboardingAddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    let category: ExpenseCategory
    let onSave: (Expense) -> Void

    @State private var name = ""
    @State private var amount = ""
    @State private var frequency: ExpenseFrequency = .monthly
    @State private var isShared = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Expense Details") {
                    TextField("Name (e.g., Rent, Netflix)", text: $name)

                    HStack {
                        Text("$")
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                    }

                    Picker("Frequency", selection: $frequency) {
                        ForEach(ExpenseFrequency.allCases) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                }

                Section {
                    Toggle("Shared Expense", isOn: $isShared)
                } footer: {
                    Text("Shared expenses are split proportionally with your partner based on income")
                }
            }
            .navigationTitle("Add \(category.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let amountDecimal = Decimal(string: amount), !name.isEmpty {
                            let expense = Expense(
                                name: name,
                                amount: amountDecimal,
                                frequency: frequency,
                                category: category,
                                isShared: isShared
                            )
                            onSave(expense)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || amount.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Onboarding Edit Expense View
struct OnboardingEditExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    let expense: Expense
    let onSave: (Expense) -> Void

    @State private var name: String
    @State private var amount: String
    @State private var frequency: ExpenseFrequency
    @State private var isShared: Bool

    init(expense: Expense, onSave: @escaping (Expense) -> Void) {
        self.expense = expense
        self.onSave = onSave
        _name = State(initialValue: expense.name)
        _amount = State(initialValue: "\(expense.amount)")
        _frequency = State(initialValue: expense.frequency)
        _isShared = State(initialValue: expense.isShared)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Expense Details") {
                    TextField("Name", text: $name)

                    HStack {
                        Text("$")
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                    }

                    Picker("Frequency", selection: $frequency) {
                        ForEach(ExpenseFrequency.allCases) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                }

                Section {
                    Toggle("Shared Expense", isOn: $isShared)
                } footer: {
                    Text("Shared expenses are split proportionally with your partner based on income")
                }
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let amountDecimal = Decimal(string: amount), !name.isEmpty {
                            var updated = expense
                            updated.name = name
                            updated.amount = amountDecimal
                            updated.frequency = frequency
                            updated.isShared = isShared
                            updated.updatedAt = Date()
                            onSave(updated)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || amount.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Complete Step
struct CompleteStepView: View {
    let onComplete: () async -> Void
    @State private var isCompleting = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            VStack(spacing: 16) {
                Text("You're All Set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("You can now see your full financial picture")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                isCompleting = true
                Task {
                    await onComplete()
                    isCompleting = false
                }
            } label: {
                if isCompleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                } else {
                    Text("Go to Dashboard")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .disabled(isCompleting)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    OnboardingView()
        .environmentObject(DependencyContainer())
}
