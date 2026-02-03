import SwiftUI

struct ScenariosView: View {
    @EnvironmentObject private var container: DependencyContainer

    var body: some View {
        ScenariosContentView(viewModel: container.scenarioViewModel)
    }
}

private struct ScenariosContentView: View {
    @ObservedObject var viewModel: ScenarioViewModel
    @EnvironmentObject private var container: DependencyContainer
    @State private var showingCreateScenario = false
    @State private var selectedScenarioType: ScenarioType?
    @State private var selectedMode: ScenarioMode = .lifeEvents

    var body: some View {
        NavigationStack {
            Group {
                if !viewModel.hasBaseProfile {
                    noProfileView
                } else {
                    VStack(spacing: 0) {
                        // Mode Selector
                        modeSelector
                            .padding()

                        // Content based on selected mode
                        switch selectedMode {
                        case .lifeEvents:
                            LifeEventsView(viewModel: viewModel)
                        case .quickCompare:
                            QuickCompareView(viewModel: viewModel)
                        case .stateCompare:
                            StateCompareView(viewModel: viewModel)
                        case .homeAffordability:
                            HomeAffordabilityView(viewModel: viewModel)
                        case .inflation:
                            InflationTrackerView(viewModel: viewModel)
                        case .timeValue:
                            TimeValueView(viewModel: viewModel)
                        case .savedScenarios:
                            savedScenariosContent
                        }
                    }
                }
            }
            .navigationTitle("Scenarios")
            .toolbar {
                if viewModel.hasBaseProfile && selectedMode == .savedScenarios {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            ForEach(ScenarioType.allCases) { type in
                                Button {
                                    selectedScenarioType = type
                                    viewModel.createScenario(type: type)
                                    showingCreateScenario = true
                                } label: {
                                    Label(type.displayName, systemImage: type.icon)
                                }
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .task {
                await viewModel.loadData()
            }
            .sheet(isPresented: $showingCreateScenario) {
                ScenarioEditorView(viewModel: viewModel)
            }
            .sheet(item: $viewModel.selectedScenario) { scenario in
                if let comparison = viewModel.activeComparison {
                    ScenarioComparisonView(scenario: scenario, comparison: comparison)
                }
            }
        }
    }

    // MARK: - Mode Selector
    private var modeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ScenarioMode.allCases) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedMode = mode
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(.subheadline)
                            Text(mode.displayName)
                                .font(.subheadline)
                                .fontWeight(selectedMode == mode ? .semibold : .regular)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selectedMode == mode
                                ? Color.accentColor
                                : Color(.systemGray5)
                        )
                        .foregroundColor(
                            selectedMode == mode ? .white : .primary
                        )
                        .cornerRadius(20)
                    }
                }
            }
        }
    }

    // MARK: - Saved Scenarios Content
    private var savedScenariosContent: some View {
        Group {
            if viewModel.scenarios.isEmpty {
                emptyStateView
            } else {
                scenarioListView
            }
        }
    }

    // MARK: - No Profile View
    private var noProfileView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Profile Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Complete your income profile first to create what-if scenarios")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Scenarios Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create what-if scenarios to see how changes affect your take-home pay")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                ForEach(ScenarioType.allCases.prefix(3)) { type in
                    Button {
                        selectedScenarioType = type
                        viewModel.createScenario(type: type)
                        showingCreateScenario = true
                    } label: {
                        HStack {
                            Image(systemName: type.icon)
                                .frame(width: 30)
                            VStack(alignment: .leading) {
                                Text(type.displayName)
                                    .font(.headline)
                                Text(type.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Scenario List
    private var scenarioListView: some View {
        List {
            ForEach(viewModel.scenarios) { scenario in
                ScenarioRow(scenario: scenario)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task {
                            await viewModel.compareScenario(scenario)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteScenario(scenario.id)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            viewModel.editScenario(scenario)
                            showingCreateScenario = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
            }
        }
    }
}

// MARK: - Scenario Row
struct ScenarioRow: View {
    let scenario: Scenario

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(scenario.name)
                .font(.headline)

            HStack(spacing: 16) {
                Label(formatCurrency(scenario.input.grossIncome), systemImage: "dollarsign.circle")
                Label(scenario.input.state.rawValue, systemImage: "location")
                Label(scenario.input.filingStatus.displayName, systemImage: "person")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

// MARK: - Scenario Editor View
struct ScenarioEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ScenarioViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Scenario Name") {
                    TextField("Name", text: $viewModel.scenarioName)
                }

                Section("Income") {
                    CurrencyTextField(
                        title: "Gross Salary",
                        value: $viewModel.scenarioGrossSalary
                    )
                }

                Section("Location & Filing") {
                    Picker("State", selection: $viewModel.scenarioState) {
                        ForEach(viewModel.availableStates) { state in
                            Text(state.displayName).tag(state)
                        }
                    }

                    Picker("Filing Status", selection: $viewModel.scenarioFilingStatus) {
                        ForEach(viewModel.availableFilingStatuses) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                }

                Section("Deductions") {
                    CurrencyTextField(
                        title: "Traditional 401(k)",
                        value: $viewModel.scenarioTraditional401k
                    )

                    CurrencyTextField(
                        title: "Roth 401(k)",
                        value: $viewModel.scenarioRoth401k
                    )
                }
            }
            .navigationTitle(viewModel.editingScenario == nil ? "New Scenario" : "Edit Scenario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.clearEditor()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveScenario()
                            dismiss()
                        }
                    }
                    .disabled(viewModel.scenarioName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Scenario Comparison View
struct ScenarioComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    let scenario: Scenario
    let comparison: ScenarioComparison

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Headline Difference
                    VStack(spacing: 8) {
                        Text(comparison.formattedMonthlyDifference)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(comparison.isPositive ? .green : .red)

                        Text("per month")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(comparison.formattedNetDifference + " annually")
                            .font(.headline)
                            .foregroundColor(comparison.isPositive ? .green : .red)
                    }
                    .padding()

                    // Comparison Cards
                    HStack(spacing: 16) {
                        ComparisonCard(title: "Current", result: comparison.base)
                        ComparisonCard(title: scenario.name, result: comparison.scenario, isScenario: true)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ComparisonCard: View {
    let title: String
    let result: TaxCalculationResult
    var isScenario: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(isScenario ? .accentColor : .primary)

            VStack(spacing: 8) {
                ComparisonRow(label: "Gross", value: result.grossAnnual)
                ComparisonRow(label: "Net Annual", value: result.netAnnual)
                ComparisonRow(label: "Net Monthly", value: result.netMonthly)
                ComparisonRow(label: "Total Taxes", value: result.totalTaxes, isNegative: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct ComparisonRow: View {
    let label: String
    let value: Decimal
    var isNegative: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(formatCurrency(value))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isNegative ? .red : .primary)
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

// MARK: - Scenario Mode Enum
enum ScenarioMode: String, CaseIterable, Identifiable {
    case lifeEvents
    case quickCompare
    case stateCompare
    case homeAffordability
    case inflation
    case timeValue
    case savedScenarios

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lifeEvents: return "Life Events"
        case .quickCompare: return "Compare"
        case .stateCompare: return "States"
        case .homeAffordability: return "Home"
        case .inflation: return "Inflation"
        case .timeValue: return "Time"
        case .savedScenarios: return "Saved"
        }
    }

    var icon: String {
        switch self {
        case .lifeEvents: return "sparkles"
        case .quickCompare: return "slider.horizontal.3"
        case .stateCompare: return "map"
        case .homeAffordability: return "house.fill"
        case .inflation: return "chart.line.downtrend.xyaxis"
        case .timeValue: return "clock"
        case .savedScenarios: return "bookmark"
        }
    }
}

// MARK: - Life Events View
struct LifeEventsView: View {
    @ObservedObject var viewModel: ScenarioViewModel
    @State private var selectedTemplate: LifeEventScenario?
    @State private var customScenario: LifeEventScenario?
    @State private var showingCustomBuilder = false
    @State private var naturalLanguageInput: String = ""
    @State private var isProcessingInput = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Natural Language Input (LLM-ready)
                naturalLanguageCard

                // Pre-built Templates
                templatesSection

                // Custom Builder
                customBuilderButton
            }
            .padding()
        }
        .sheet(item: $selectedTemplate) { scenario in
            LifeEventDetailView(
                scenario: scenario,
                viewModel: viewModel
            )
        }
        .sheet(isPresented: $showingCustomBuilder) {
            CustomScenarioBuilderView(viewModel: viewModel)
        }
    }

    // MARK: - Natural Language Card
    private var naturalLanguageCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .foregroundColor(.purple)
                Text("Describe Your Scenario")
                    .font(.headline)
                Spacer()
                Text("AI-Ready")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.2))
                    .foregroundColor(.purple)
                    .cornerRadius(4)
            }

            Text("Tell us what you're planning in plain English")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $naturalLanguageInput)
                .frame(height: 80)
                .padding(8)
                .background(Color(.systemGray5))
                .cornerRadius(8)
                .overlay(
                    Group {
                        if naturalLanguageInput.isEmpty {
                            Text("Example: \"I'm thinking about having a baby next year\" or \"What if I lose my job?\"")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(12)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )

            Button {
                processNaturalLanguage()
            } label: {
                HStack {
                    if isProcessingInput {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isProcessingInput ? "Analyzing..." : "Analyze Scenario")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(naturalLanguageInput.isEmpty ? Color.gray : Color.purple)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(naturalLanguageInput.isEmpty || isProcessingInput)

            // Hint about LLM integration
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                Text("This feature is designed for LLM agent integration")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Templates Section
    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Life Event Templates")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(LifeEventScenario.allTemplates) { template in
                    TemplateCard(scenario: template) {
                        selectedTemplate = template
                    }
                }
            }
        }
    }

    // MARK: - Custom Builder Button
    private var customBuilderButton: some View {
        Button {
            showingCustomBuilder = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text("Build Custom Scenario")
                        .font(.headline)
                    Text("Create your own life event")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Process Natural Language
    private func processNaturalLanguage() {
        isProcessingInput = true

        // Simulate processing (in production, this would call an LLM API)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Simple keyword matching for demo (LLM would do this properly)
            let input = naturalLanguageInput.lowercased()

            if input.contains("baby") || input.contains("child") || input.contains("pregnant") {
                selectedTemplate = .firstChild()
            } else if input.contains("retire") || input.contains("retirement") || input.contains("social security") {
                selectedTemplate = .retirement()
            } else if input.contains("job") && (input.contains("lose") || input.contains("lost") || input.contains("fired") || input.contains("laid off")) {
                selectedTemplate = .jobLoss()
            } else if input.contains("married") || input.contains("wedding") || input.contains("engaged") {
                selectedTemplate = .gettingMarried()
            } else if input.contains("car") || input.contains("vehicle") {
                selectedTemplate = .buyingCar()
            } else if input.contains("school") || input.contains("degree") || input.contains("education") || input.contains("college") {
                selectedTemplate = .backToSchool()
            } else if input.contains("disabled") || input.contains("disability") || input.contains("injury") {
                selectedTemplate = .disability()
            } else {
                // Default to custom builder
                showingCustomBuilder = true
            }

            isProcessingInput = false
            // selectedTemplate is already set, sheet will appear via .sheet(item:)
        }
    }
}

// MARK: - Template Card
struct TemplateCard: View {
    let scenario: LifeEventScenario
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: scenario.icon)
                    .font(.title)
                    .foregroundColor(.accentColor)
                    .frame(width: 50, height: 50)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(12)

                Text(scenario.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(scenario.category.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Life Event Detail View
struct LifeEventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let scenario: LifeEventScenario
    @ObservedObject var viewModel: ScenarioViewModel
    @State private var editableScenario: LifeEventScenario
    @State private var impact: LifeEventImpact?

    init(scenario: LifeEventScenario, viewModel: ScenarioViewModel) {
        self.scenario = scenario
        self.viewModel = viewModel
        self._editableScenario = State(initialValue: scenario)
    }

    var baseSalary: Decimal {
        viewModel.baseProfile?.income.grossSalary ?? 100000
    }

    var currentNetMonthly: Decimal {
        viewModel.baseTaxResult?.netMonthly ?? 5000
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Impact Summary
                    if let impact = impact {
                        impactSummaryCard(impact: impact)
                    }

                    // Income Changes
                    if !editableScenario.incomeChanges.isEmpty {
                        changesSection(
                            title: "Income Changes",
                            icon: "arrow.up.arrow.down",
                            color: .green
                        ) {
                            ForEach(editableScenario.incomeChanges) { change in
                                IncomeChangeRow(change: change)
                            }
                        }
                    }

                    // Expense Changes
                    if !editableScenario.expenseChanges.isEmpty {
                        changesSection(
                            title: "Expense Changes",
                            icon: "creditcard",
                            color: .orange
                        ) {
                            ForEach(editableScenario.expenseChanges) { change in
                                ExpenseChangeRow(change: change)
                            }
                        }
                    }

                    // Tax Changes
                    if !editableScenario.taxChanges.isEmpty {
                        changesSection(
                            title: "Tax Benefits",
                            icon: "doc.text",
                            color: .blue
                        ) {
                            ForEach(editableScenario.taxChanges) { change in
                                TaxChangeRow(change: change)
                            }
                        }
                    }

                    // Timeline
                    if let duration = editableScenario.duration {
                        timelineCard(duration: duration)
                    }
                }
                .padding()
            }
            .navigationTitle(scenario.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                calculateImpact()
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: scenario.icon)
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text(scenario.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func impactSummaryCard(impact: LifeEventImpact) -> some View {
        VStack(spacing: 16) {
            Text("Monthly Impact")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(formatCurrency(impact.netMonthlyImpact))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(impact.isPositive ? .green : .red)

            Text(impact.isPositive ? "additional per month" : "less per month")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            HStack(spacing: 24) {
                VStack {
                    Text("Income")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(impact.monthlyIncomeChange))
                        .font(.headline)
                        .foregroundColor(impact.monthlyIncomeChange >= 0 ? .green : .red)
                }

                VStack {
                    Text("Expenses")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(-impact.monthlyExpenseChange))
                        .font(.headline)
                        .foregroundColor(.orange)
                }

                VStack {
                    Text("Tax Benefit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(-impact.annualTaxChange / 12))
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }

            if impact.oneTimeExpenses > 0 {
                Divider()
                HStack {
                    Text("One-time costs:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(impact.oneTimeExpenses))
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    private func changesSection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }

            VStack(spacing: 8) {
                content()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func timelineCard(duration: EventDuration) -> some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(.purple)
            Text("Duration:")
            Spacer()
            Text(duration.displayName)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func calculateImpact() {
        impact = editableScenario.calculateImpact(
            baseSalary: baseSalary,
            currentNetMonthly: currentNetMonthly
        )
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

// MARK: - Change Row Views
struct IncomeChangeRow: View {
    let change: IncomeChange

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(change.reason.isEmpty ? change.type.rawValue.capitalized : change.reason)
                    .font(.subheadline)
                if let duration = change.duration {
                    Text(duration.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(change.isPercentage ? "\(NSDecimalNumber(decimal: change.amount).intValue)%" : formatCurrency(change.amount))
                .font(.subheadline)
                .foregroundColor(change.amount >= 0 ? .green : .red)
        }
        .padding(.vertical, 4)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

struct ExpenseChangeRow: View {
    let change: ExpenseChange

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(change.name)
                    .font(.subheadline)
                HStack(spacing: 4) {
                    Text(change.frequency.displayName)
                    if change.isOneTime {
                        Text("• One-time")
                    }
                    if let duration = change.duration {
                        Text("• \(duration.displayName)")
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            Spacer()
            Text(formatCurrency(change.amount))
                .font(.subheadline)
                .foregroundColor(change.amount < 0 ? .green : .orange)
        }
        .padding(.vertical, 4)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

struct TaxChangeRow: View {
    let change: TaxChange

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(change.name)
                    .font(.subheadline)
                Text(change.type.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(formatCurrency(change.amount))
                .font(.subheadline)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

// MARK: - Custom Scenario Builder View
struct CustomScenarioBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ScenarioViewModel

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var category: LifeEventCategory = .other

    @State private var incomeChanges: [IncomeChange] = []
    @State private var expenseChanges: [ExpenseChange] = []

    @State private var showingAddIncome = false
    @State private var showingAddExpense = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Scenario Info") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                    Picker("Category", selection: $category) {
                        ForEach(LifeEventCategory.allCases) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                }

                Section {
                    ForEach(incomeChanges) { change in
                        HStack {
                            Text(change.reason.isEmpty ? change.type.rawValue : change.reason)
                            Spacer()
                            Text("\(NSDecimalNumber(decimal: change.amount).intValue)")
                                .foregroundColor(change.amount >= 0 ? .green : .red)
                        }
                    }
                    .onDelete { indexSet in
                        incomeChanges.remove(atOffsets: indexSet)
                    }

                    Button {
                        showingAddIncome = true
                    } label: {
                        Label("Add Income Change", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Income Changes")
                }

                Section {
                    ForEach(expenseChanges) { change in
                        HStack {
                            Text(change.name)
                            Spacer()
                            Text("$\(NSDecimalNumber(decimal: change.amount).intValue)/mo")
                                .foregroundColor(.orange)
                        }
                    }
                    .onDelete { indexSet in
                        expenseChanges.remove(atOffsets: indexSet)
                    }

                    Button {
                        showingAddExpense = true
                    } label: {
                        Label("Add Expense", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Expense Changes")
                }

                Section {
                    // JSON Export (for LLM integration)
                    Button {
                        exportAsJSON()
                    } label: {
                        Label("Export as JSON", systemImage: "doc.text")
                    }
                } header: {
                    Text("Developer Tools")
                } footer: {
                    Text("Export scenario structure for LLM agent integration")
                }
            }
            .navigationTitle("Custom Scenario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveScenario()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddIncome) {
                AddIncomeChangeView { change in
                    incomeChanges.append(change)
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseChangeView { change in
                    expenseChanges.append(change)
                }
            }
        }
    }

    private func saveScenario() {
        let scenario = LifeEventScenario(
            name: name,
            description: description,
            icon: category.icon,
            category: category,
            incomeChanges: incomeChanges,
            expenseChanges: expenseChanges
        )
        // Save to repository (would implement persistence)
        print("Saved scenario: \(scenario)")
    }

    private func exportAsJSON() {
        let scenario = LifeEventScenario(
            name: name,
            description: description,
            icon: category.icon,
            category: category,
            incomeChanges: incomeChanges,
            expenseChanges: expenseChanges
        )

        if let jsonData = try? JSONEncoder().encode(scenario),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            UIPasteboard.general.string = jsonString
            print("JSON copied to clipboard:\n\(jsonString)")
        }
    }
}

// MARK: - Add Income Change View
struct AddIncomeChangeView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (IncomeChange) -> Void

    @State private var type: IncomeChangeType = .raise
    @State private var amount: String = ""
    @State private var isPercentage: Bool = false
    @State private var reason: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $type) {
                    ForEach(IncomeChangeType.allCases, id: \.self) { t in
                        Text(t.rawValue.capitalized).tag(t)
                    }
                }

                HStack {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    Toggle(isPercentage ? "%" : "$", isOn: $isPercentage)
                        .labelsHidden()
                        .frame(width: 50)
                }

                TextField("Reason (optional)", text: $reason)
            }
            .navigationTitle("Add Income Change")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let amountValue = Decimal(string: amount) {
                            let change = IncomeChange(
                                type: type,
                                amount: amountValue,
                                isPercentage: isPercentage,
                                reason: reason
                            )
                            onSave(change)
                            dismiss()
                        }
                    }
                    .disabled(amount.isEmpty)
                }
            }
        }
    }
}

// MARK: - Add Expense Change View
struct AddExpenseChangeView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (ExpenseChange) -> Void

    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var frequency: ChangeFrequency = .monthly
    @State private var isOneTime: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Expense Name", text: $name)

                HStack {
                    Text("$")
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                }

                Picker("Frequency", selection: $frequency) {
                    ForEach(ChangeFrequency.allCases, id: \.self) { f in
                        Text(f.displayName).tag(f)
                    }
                }

                Toggle("One-time expense", isOn: $isOneTime)
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let amountValue = Decimal(string: amount) {
                            let change = ExpenseChange(
                                name: name,
                                amount: amountValue,
                                frequency: frequency,
                                isOneTime: isOneTime
                            )
                            onSave(change)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || amount.isEmpty)
                }
            }
        }
    }
}

// MARK: - Quick Compare View
struct QuickCompareView: View {
    @ObservedObject var viewModel: ScenarioViewModel

    @State private var salaryAdjustment: Double = 0 // percentage change
    @State private var retirement401k: Double = 0
    @State private var selectedState: USState?
    @State private var quickResult: TaxCalculationResult?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Result Card
                quickResultCard

                // Salary Slider
                salarySlider

                // 401k Slider
                retirementSlider

                // State Picker
                statePicker
            }
            .padding()
        }
        .onAppear {
            initializeValues()
        }
        .onChange(of: salaryAdjustment) { _, _ in recalculate() }
        .onChange(of: retirement401k) { _, _ in recalculate() }
        .onChange(of: selectedState) { _, _ in recalculate() }
    }

    private func initializeValues() {
        guard let profile = viewModel.baseProfile else { return }
        retirement401k = NSDecimalNumber(decimal: profile.deductions.traditional401k).doubleValue
        selectedState = profile.location.state
        recalculate()
    }

    private func recalculate() {
        guard let profile = viewModel.baseProfile else { return }

        let adjustedSalary = profile.income.grossSalary * Decimal(1 + salaryAdjustment / 100)
        let state = selectedState ?? profile.location.state

        Task {
            let input = TaxCalculationInput(
                grossIncome: adjustedSalary,
                filingStatus: profile.location.filingStatus,
                state: state,
                traditional401k: Decimal(retirement401k)
            )
            if let result = try? viewModel.taxCore.computeTaxes(input: input) {
                await MainActor.run {
                    quickResult = result
                }
            }
        }
    }

    private var quickResultCard: some View {
        VStack(spacing: 12) {
            if let result = quickResult, let base = viewModel.baseTaxResult {
                let difference = result.netMonthly - base.netMonthly

                Text(formatCurrency(result.netMonthly))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("per month")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if abs(difference) > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: difference > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        Text("\(formatCurrency(abs(difference))) \(difference > 0 ? "more" : "less")")
                    }
                    .font(.headline)
                    .foregroundColor(difference > 0 ? .green : .red)
                }
            } else {
                Text("--")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    private var salarySlider: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.green)
                Text("Salary Change")
                    .font(.headline)
                Spacer()
                Text(salaryAdjustment >= 0 ? "+\(Int(salaryAdjustment))%" : "\(Int(salaryAdjustment))%")
                    .font(.headline)
                    .foregroundColor(salaryAdjustment >= 0 ? .green : .red)
            }

            if let profile = viewModel.baseProfile {
                let adjustedSalary = profile.income.grossSalary * Decimal(1 + salaryAdjustment / 100)
                Text("Gross: \(formatCurrency(adjustedSalary))/year")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Slider(value: $salaryAdjustment, in: -30...50, step: 1)
                .tint(.green)

            HStack {
                Text("-30%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Reset") {
                    salaryAdjustment = 0
                }
                .font(.caption)
                Spacer()
                Text("+50%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var retirementSlider: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "building.columns.fill")
                    .foregroundColor(.blue)
                Text("401(k) Contribution")
                    .font(.headline)
                Spacer()
                Text(formatCurrency(Decimal(retirement401k)))
                    .font(.headline)
            }

            Text("Annual pre-tax contribution")
                .font(.caption)
                .foregroundColor(.secondary)

            Slider(value: $retirement401k, in: 0...23000, step: 500)
                .tint(.blue)

            HStack {
                Text("$0")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Max") {
                    retirement401k = 23000
                }
                .font(.caption)
                Spacer()
                Text("$23,000")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var statePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map.fill")
                    .foregroundColor(.orange)
                Text("State")
                    .font(.headline)
                Spacer()
            }

            Picker("State", selection: $selectedState) {
                ForEach(viewModel.availableStates) { state in
                    Text(state.displayName).tag(Optional(state))
                }
            }
            .pickerStyle(.menu)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

// MARK: - State Compare View
struct StateCompareView: View {
    @ObservedObject var viewModel: ScenarioViewModel
    @State private var stateResults: [(USState, TaxCalculationResult)] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Calculating all states...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if let current = viewModel.baseProfile?.location.state,
                       let currentResult = stateResults.first(where: { $0.0 == current }) {
                        Section {
                            StateResultRow(
                                state: current,
                                result: currentResult.1,
                                baseResult: currentResult.1,
                                isCurrent: true,
                                rank: stateResults.firstIndex(where: { $0.0 == current }).map { $0 + 1 } ?? 0
                            )
                        } header: {
                            Text("Current State")
                        }
                    }

                    Section {
                        ForEach(Array(stateResults.enumerated()), id: \.1.0) { index, item in
                            let (state, result) = item
                            if let baseResult = stateResults.first(where: { $0.0 == viewModel.baseProfile?.location.state })?.1 {
                                StateResultRow(
                                    state: state,
                                    result: result,
                                    baseResult: baseResult,
                                    isCurrent: state == viewModel.baseProfile?.location.state,
                                    rank: index + 1
                                )
                            }
                        }
                    } header: {
                        Text("All States Ranked by Take-Home")
                    }
                }
            }
        }
        .task {
            await calculateAllStates()
        }
    }

    private func calculateAllStates() async {
        guard let profile = viewModel.baseProfile else { return }

        var results: [(USState, TaxCalculationResult)] = []

        for state in viewModel.availableStates {
            let input = TaxCalculationInput(
                grossIncome: profile.income.grossSalary,
                filingStatus: profile.location.filingStatus,
                state: state,
                traditional401k: profile.deductions.traditional401k
            )

            if let result = try? viewModel.taxCore.computeTaxes(input: input) {
                results.append((state, result))
            }
        }

        // Sort by net annual (highest first)
        results.sort { $0.1.netAnnual > $1.1.netAnnual }

        await MainActor.run {
            stateResults = results
            isLoading = false
        }
    }
}

struct StateResultRow: View {
    let state: USState
    let result: TaxCalculationResult
    let baseResult: TaxCalculationResult
    let isCurrent: Bool
    let rank: Int

    var difference: Decimal {
        result.netAnnual - baseResult.netAnnual
    }

    var body: some View {
        HStack {
            // Rank
            Text("#\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(state.displayName)
                        .font(.headline)
                    if isCurrent {
                        Text("Current")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }

                Text("\(formatCurrency(result.netMonthly))/mo")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(result.netAnnual))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if !isCurrent && abs(difference) > 1 {
                    Text("\(difference > 0 ? "+" : "")\(formatCurrency(difference))")
                        .font(.caption)
                        .foregroundColor(difference > 0 ? .green : .red)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

// MARK: - Home Affordability View
struct HomeAffordabilityView: View {
    @ObservedObject var viewModel: ScenarioViewModel

    // User inputs
    @State private var downPaymentPercent: Double = 20
    @State private var interestRate: Double = 6.5
    @State private var loanTermYears: Int = 30
    @State private var propertyTaxRate: Double = 1.2
    @State private var homeInsuranceAnnual: Double = 1800
    @State private var hoaMonthly: Double = 0
    @State private var currentSavings: String = ""
    @State private var monthlyRent: String = ""

    // Computed from profile
    var grossAnnualIncome: Decimal {
        viewModel.baseProfile?.income.grossSalary ?? 0
    }

    var netMonthlyIncome: Decimal {
        viewModel.baseTaxResult?.netMonthly ?? 0
    }

    var currentMonthlyExpenses: Decimal {
        // Get from expense repository if available, otherwise estimate
        let expenses = viewModel.baseProfile != nil ? Decimal(2500) : 0 // Placeholder
        return expenses
    }

    // DTI Calculations (using gross income)
    var maxFrontEndDTI: Double { 0.28 } // Housing costs
    var maxBackEndDTI: Double { 0.36 } // Total debt

    var grossMonthlyIncome: Decimal {
        grossAnnualIncome / 12
    }

    // Max monthly housing payment (28% of gross)
    var maxHousingPayment: Decimal {
        grossMonthlyIncome * Decimal(maxFrontEndDTI)
    }

    // Calculate max home price based on DTI
    var maxHomePrice: Decimal {
        let monthlyPaymentBudget = maxHousingPayment - Decimal(hoaMonthly)
        guard monthlyPaymentBudget > 0 else { return 0 }

        // Back out the home price from monthly payment
        // Monthly payment = taxes + insurance + P&I
        let monthlyTaxInsurance = estimatedMonthlyTaxInsurance(forPrice: 100000) // per 100k
        let availableForPI = monthlyPaymentBudget

        // Use iterative approach to find max price
        var low: Decimal = 0
        var high: Decimal = 2000000
        var result: Decimal = 0

        for _ in 0..<20 {
            let mid = (low + high) / 2
            let payment = calculateTotalMonthlyPayment(homePrice: mid)
            if payment <= maxHousingPayment {
                result = mid
                low = mid
            } else {
                high = mid
            }
        }

        return result
    }

    // Calculate monthly payment for a given home price
    func calculateTotalMonthlyPayment(homePrice: Decimal) -> Decimal {
        let downPayment = homePrice * Decimal(downPaymentPercent / 100)
        let loanAmount = homePrice - downPayment

        // Principal & Interest
        let monthlyRate = interestRate / 100 / 12
        let numPayments = Double(loanTermYears * 12)

        let piPayment: Decimal
        if monthlyRate > 0 {
            let factor = pow(1 + monthlyRate, numPayments)
            piPayment = loanAmount * Decimal(monthlyRate * factor / (factor - 1))
        } else {
            piPayment = loanAmount / Decimal(numPayments)
        }

        // Property Tax (monthly)
        let monthlyPropertyTax = homePrice * Decimal(propertyTaxRate / 100 / 12)

        // Insurance (monthly)
        let monthlyInsurance = Decimal(homeInsuranceAnnual / 12)

        // PMI (if down payment < 20%)
        let pmi: Decimal
        if downPaymentPercent < 20 {
            pmi = loanAmount * Decimal(0.005 / 12) // ~0.5% annual PMI
        } else {
            pmi = 0
        }

        // HOA
        let hoa = Decimal(hoaMonthly)

        return piPayment + monthlyPropertyTax + monthlyInsurance + pmi + hoa
    }

    func estimatedMonthlyTaxInsurance(forPrice price: Decimal) -> Decimal {
        let monthlyPropertyTax = price * Decimal(propertyTaxRate / 100 / 12)
        let monthlyInsurance = Decimal(homeInsuranceAnnual / 12)
        return monthlyPropertyTax + monthlyInsurance
    }

    // Down payment needed for max home
    var downPaymentNeeded: Decimal {
        maxHomePrice * Decimal(downPaymentPercent / 100)
    }

    // Closing costs estimate (3% of home price)
    var closingCosts: Decimal {
        maxHomePrice * Decimal(0.03)
    }

    // Total cash needed
    var totalCashNeeded: Decimal {
        downPaymentNeeded + closingCosts
    }

    // Current savings
    var currentSavingsDecimal: Decimal {
        Decimal(string: currentSavings) ?? 0
    }

    // Gap to save
    var savingsGap: Decimal {
        max(0, totalCashNeeded - currentSavingsDecimal)
    }

    // Monthly payment at max price
    var monthlyPaymentAtMax: Decimal {
        calculateTotalMonthlyPayment(homePrice: maxHomePrice)
    }

    // Remaining after housing
    var remainingAfterHousing: Decimal {
        netMonthlyIncome - monthlyPaymentAtMax
    }

    // Current rent for comparison
    var currentRentDecimal: Decimal {
        Decimal(string: monthlyRent) ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Affordability Result Card
                affordabilityCard

                // Loan Parameters
                loanParametersCard

                // Monthly Payment Breakdown
                paymentBreakdownCard

                // Down Payment Scenarios
                downPaymentScenariosCard

                // Savings Progress
                savingsProgressCard

                // Reality Check
                realityCheckCard
            }
            .padding()
        }
    }

    // MARK: - Affordability Card
    private var affordabilityCard: some View {
        VStack(spacing: 16) {
            Text("You Can Afford")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(formatCurrency(maxHomePrice))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.accentColor)

            Text("based on 28% DTI rule")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            HStack(spacing: 24) {
                VStack {
                    Text("Down Payment")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(downPaymentNeeded))
                        .font(.headline)
                }

                VStack {
                    Text("Monthly Payment")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(monthlyPaymentAtMax))
                        .font(.headline)
                        .foregroundColor(.orange)
                }

                VStack {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(remainingAfterHousing))
                        .font(.headline)
                        .foregroundColor(remainingAfterHousing > 500 ? .green : .red)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Loan Parameters Card
    private var loanParametersCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.blue)
                Text("Loan Parameters")
                    .font(.headline)
            }

            // Down Payment
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Down Payment")
                    Spacer()
                    Text("\(Int(downPaymentPercent))%")
                        .fontWeight(.semibold)
                }
                Slider(value: $downPaymentPercent, in: 3...30, step: 1)
                    .tint(.blue)
                HStack {
                    ForEach([3, 5, 10, 20], id: \.self) { pct in
                        Button("\(pct)%") {
                            downPaymentPercent = Double(pct)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(downPaymentPercent == Double(pct) ? Color.blue : Color(.systemGray5))
                        .foregroundColor(downPaymentPercent == Double(pct) ? .white : .primary)
                        .cornerRadius(4)
                    }
                    Spacer()
                }
            }

            Divider()

            // Interest Rate
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Interest Rate")
                    Spacer()
                    Text("\(String(format: "%.2f", interestRate))%")
                        .fontWeight(.semibold)
                }
                Slider(value: $interestRate, in: 3...10, step: 0.125)
                    .tint(.green)
            }

            Divider()

            // Loan Term
            HStack {
                Text("Loan Term")
                Spacer()
                Picker("Term", selection: $loanTermYears) {
                    Text("15 years").tag(15)
                    Text("30 years").tag(30)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            Divider()

            // Property Tax Rate
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Property Tax Rate")
                    Spacer()
                    Text("\(String(format: "%.2f", propertyTaxRate))%")
                        .fontWeight(.semibold)
                }
                Slider(value: $propertyTaxRate, in: 0.5...3, step: 0.1)
                    .tint(.orange)
            }

            Divider()

            // HOA
            HStack {
                Text("HOA (monthly)")
                Spacer()
                TextField("$0", value: $hoaMonthly, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Payment Breakdown Card
    private var paymentBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.purple)
                Text("Monthly Payment Breakdown")
                    .font(.headline)
            }

            let homePrice = maxHomePrice
            let downPayment = homePrice * Decimal(downPaymentPercent / 100)
            let loanAmount = homePrice - downPayment
            let monthlyRate = interestRate / 100 / 12
            let numPayments = Double(loanTermYears * 12)

            let piPayment: Decimal = {
                if monthlyRate > 0 {
                    let factor = pow(1 + monthlyRate, numPayments)
                    return loanAmount * Decimal(monthlyRate * factor / (factor - 1))
                } else {
                    return loanAmount / Decimal(numPayments)
                }
            }()

            let monthlyPropertyTax = homePrice * Decimal(propertyTaxRate / 100 / 12)
            let monthlyInsurance = Decimal(homeInsuranceAnnual / 12)
            let pmi: Decimal = downPaymentPercent < 20 ? loanAmount * Decimal(0.005 / 12) : 0
            let hoa = Decimal(hoaMonthly)

            VStack(spacing: 8) {
                PaymentRow(label: "Principal & Interest", amount: piPayment, color: .blue)
                PaymentRow(label: "Property Tax", amount: monthlyPropertyTax, color: .orange)
                PaymentRow(label: "Home Insurance", amount: monthlyInsurance, color: .green)
                if pmi > 0 {
                    PaymentRow(label: "PMI", amount: pmi, color: .red, note: "Until 20% equity")
                }
                if hoa > 0 {
                    PaymentRow(label: "HOA", amount: hoa, color: .purple)
                }

                Divider()

                HStack {
                    Text("Total")
                        .fontWeight(.bold)
                    Spacer()
                    Text(formatCurrency(monthlyPaymentAtMax))
                        .fontWeight(.bold)
                }
            }

            // Compare to rent
            if currentRentDecimal > 0 {
                Divider()
                let difference = monthlyPaymentAtMax - currentRentDecimal
                HStack {
                    Image(systemName: difference > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundColor(difference > 0 ? .red : .green)
                    Text("\(formatCurrency(abs(difference))) \(difference > 0 ? "more" : "less") than rent")
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Down Payment Scenarios
    private var downPaymentScenariosCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.green)
                Text("Down Payment Scenarios")
                    .font(.headline)
            }

            VStack(spacing: 12) {
                ForEach([3, 5, 10, 20], id: \.self) { pct in
                    let dp = maxHomePrice * Decimal(pct) / 100
                    let hasPMI = pct < 20

                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(pct)% Down")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if hasPMI {
                                Text("+ PMI")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                        .frame(width: 80, alignment: .leading)

                        Text(formatCurrency(dp))
                            .font(.subheadline)
                            .frame(width: 90)

                        Spacer()

                        // Monthly payment at this down payment
                        let tempDownPayment = downPaymentPercent
                        let payment = calculatePaymentForDownPayment(pct: Double(pct))
                        Text("\(formatCurrency(payment))/mo")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func calculatePaymentForDownPayment(pct: Double) -> Decimal {
        let homePrice = maxHomePrice
        let downPayment = homePrice * Decimal(pct / 100)
        let loanAmount = homePrice - downPayment

        let monthlyRate = interestRate / 100 / 12
        let numPayments = Double(loanTermYears * 12)

        let piPayment: Decimal
        if monthlyRate > 0 {
            let factor = pow(1 + monthlyRate, numPayments)
            piPayment = loanAmount * Decimal(monthlyRate * factor / (factor - 1))
        } else {
            piPayment = loanAmount / Decimal(numPayments)
        }

        let monthlyPropertyTax = homePrice * Decimal(propertyTaxRate / 100 / 12)
        let monthlyInsurance = Decimal(homeInsuranceAnnual / 12)
        let pmi: Decimal = pct < 20 ? loanAmount * Decimal(0.005 / 12) : 0
        let hoa = Decimal(hoaMonthly)

        return piPayment + monthlyPropertyTax + monthlyInsurance + pmi + hoa
    }

    // MARK: - Savings Progress Card
    private var savingsProgressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "banknote.fill")
                    .foregroundColor(.green)
                Text("Savings Progress")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Current Savings")
                    Spacer()
                    TextField("$0", text: $currentSavings)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }

                HStack {
                    Text("Current Rent")
                    Spacer()
                    TextField("$0", text: $monthlyRent)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }

                Divider()

                HStack {
                    Text("Total Cash Needed")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(totalCashNeeded))
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Down payment")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(downPaymentNeeded))
                        .font(.caption)
                }

                HStack {
                    Text("Closing costs (~3%)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(closingCosts))
                        .font(.caption)
                }

                if currentSavingsDecimal > 0 {
                    Divider()

                    // Progress bar
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { geometry in
                            let progress = min(NSDecimalNumber(decimal: currentSavingsDecimal / totalCashNeeded).doubleValue, 1.0)
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color(.systemGray4))
                                    .frame(height: 8)
                                    .cornerRadius(4)

                                Rectangle()
                                    .fill(progress >= 1.0 ? Color.green : Color.blue)
                                    .frame(width: geometry.size.width * CGFloat(progress), height: 8)
                                    .cornerRadius(4)
                            }
                        }
                        .frame(height: 8)

                        HStack {
                            Text("\(Int(min(NSDecimalNumber(decimal: currentSavingsDecimal / totalCashNeeded * 100).doubleValue, 100)))% saved")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            if savingsGap > 0 {
                                Text("\(formatCurrency(savingsGap)) to go")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else {
                                Text("Ready!")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Reality Check Card
    private var realityCheckCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.blue)
                Text("Reality Check")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 12) {
                RealityCheckRow(
                    icon: "dollarsign.circle",
                    title: "Emergency Fund",
                    subtitle: "3-6 months expenses after purchase",
                    amount: netMonthlyIncome * 3,
                    status: currentSavingsDecimal > totalCashNeeded + (netMonthlyIncome * 3) ? .good : .warning
                )

                RealityCheckRow(
                    icon: "wrench.and.screwdriver",
                    title: "Maintenance Reserve",
                    subtitle: "1-2% of home value annually",
                    amount: maxHomePrice * Decimal(0.01),
                    status: remainingAfterHousing > (maxHomePrice * Decimal(0.01) / 12) ? .good : .warning
                )

                RealityCheckRow(
                    icon: "shippingbox",
                    title: "Moving Costs",
                    subtitle: "One-time expense",
                    amount: 5000,
                    status: .info
                )

                RealityCheckRow(
                    icon: "sofa",
                    title: "Furniture & Setup",
                    subtitle: "Initial home setup",
                    amount: 10000,
                    status: .info
                )
            }

            Divider()

            // Final verdict
            let isAffordable = remainingAfterHousing > 500 && currentSavingsDecimal >= totalCashNeeded * Decimal(0.8)

            HStack(spacing: 12) {
                Image(systemName: isAffordable ? "hand.thumbsup.fill" : "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(isAffordable ? .green : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isAffordable ? "You're in good shape!" : "Consider saving more first")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(isAffordable
                         ? "Based on your income and savings, this is realistic"
                         : "Build up emergency fund and down payment before buying")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

// MARK: - Payment Row
struct PaymentRow: View {
    let label: String
    let amount: Decimal
    let color: Color
    var note: String? = nil

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.subheadline)
            if let note = note {
                Text("(\(note))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(formatCurrency(amount))
                .font(.subheadline)
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

// MARK: - Reality Check Row
struct RealityCheckRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let amount: Decimal
    let status: CheckStatus

    enum CheckStatus {
        case good, warning, info

        var color: Color {
            switch self {
            case .good: return .green
            case .warning: return .orange
            case .info: return .blue
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(status.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(formatCurrency(amount))
                .font(.caption)
                .foregroundColor(.secondary)
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

// MARK: - Inflation Tracker View
struct InflationTrackerView: View {
    @ObservedObject var viewModel: ScenarioViewModel

    @State private var inflationRate: Double = 3.5
    @State private var yourRaise: Double = 0
    @State private var yearsToProject: Int = 5
    @State private var lastYearSalary: String = ""

    var currentSalary: Decimal {
        viewModel.baseProfile?.income.grossSalary ?? 0
    }

    var currentNetMonthly: Decimal {
        viewModel.baseTaxResult?.netMonthly ?? 0
    }

    // Required raise just to break even with inflation
    var requiredRaise: Double {
        inflationRate
    }

    // Real raise (your raise minus inflation)
    var realRaise: Double {
        yourRaise - inflationRate
    }

    // Are you keeping up?
    var isKeepingUp: Bool {
        yourRaise >= inflationRate
    }

    // Money you're "losing" annually if not keeping up
    var annualLoss: Decimal {
        guard !isKeepingUp else { return 0 }
        let lossPercent = Decimal(inflationRate - yourRaise) / 100
        return currentSalary * lossPercent
    }

    // Purchasing power over time
    func purchasingPower(afterYears years: Int) -> Decimal {
        let inflationMultiplier = pow(1 + inflationRate / 100, Double(years))
        let raiseMultiplier = pow(1 + yourRaise / 100, Double(years))
        let realMultiplier = raiseMultiplier / inflationMultiplier
        return currentNetMonthly * Decimal(realMultiplier)
    }

    // What salary you need to match last year's purchasing power
    var salaryNeededToMatchLastYear: Decimal {
        guard let lastSalary = Decimal(string: lastYearSalary), lastSalary > 0 else {
            return currentSalary * Decimal(1 + inflationRate / 100)
        }
        return lastSalary * Decimal(1 + inflationRate / 100)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Status Card
                statusCard

                // Inflation Rate Slider
                inflationSlider

                // Your Raise Slider
                raiseSlider

                // Year-over-Year Comparison
                yearOverYearCard

                // Projection Over Time
                projectionCard

                // Info Card
                infoCard
            }
            .padding()
        }
    }

    // MARK: - Status Card
    private var statusCard: some View {
        VStack(spacing: 16) {
            // Status Icon
            Image(systemName: isKeepingUp ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(isKeepingUp ? .green : .orange)

            // Status Text
            if yourRaise == 0 {
                Text("Enter your raise to see the impact")
                    .font(.headline)
                    .foregroundColor(.secondary)
            } else if isKeepingUp {
                VStack(spacing: 4) {
                    Text("You're ahead of inflation!")
                        .font(.headline)
                        .foregroundColor(.green)
                    Text("Real raise: +\(String(format: "%.1f", realRaise))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 4) {
                    Text("You're losing purchasing power")
                        .font(.headline)
                        .foregroundColor(.orange)
                    Text("Real loss: \(String(format: "%.1f", realRaise))%")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }

            // Required raise callout
            if yourRaise < inflationRate {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("You need at least \(String(format: "%.1f", requiredRaise))% raise to break even")
                        .font(.subheadline)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Inflation Slider
    private var inflationSlider: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.red)
                Text("Inflation Rate")
                    .font(.headline)
                Spacer()
                Text("\(String(format: "%.1f", inflationRate))%")
                    .font(.headline)
                    .foregroundColor(.red)
            }

            Text("Current CPI inflation (adjust as needed)")
                .font(.caption)
                .foregroundColor(.secondary)

            Slider(value: $inflationRate, in: 0...15, step: 0.1)
                .tint(.red)

            HStack {
                Text("0%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 8) {
                    Button("2%") { inflationRate = 2.0 }
                    Button("3.5%") { inflationRate = 3.5 }
                    Button("5%") { inflationRate = 5.0 }
                }
                .font(.caption)
                Spacer()
                Text("15%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Raise Slider
    private var raiseSlider: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.green)
                Text("Your Raise")
                    .font(.headline)
                Spacer()
                Text("\(String(format: "%.1f", yourRaise))%")
                    .font(.headline)
                    .foregroundColor(yourRaise >= inflationRate ? .green : .orange)
            }

            if currentSalary > 0 {
                let newSalary = currentSalary * Decimal(1 + yourRaise / 100)
                Text("New salary: \(formatCurrency(newSalary))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Slider(value: $yourRaise, in: 0...20, step: 0.5)
                .tint(yourRaise >= inflationRate ? .green : .orange)

            HStack {
                Text("0%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Match inflation") {
                    yourRaise = inflationRate
                }
                .font(.caption)
                Spacer()
                Text("20%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Year Over Year Card
    private var yearOverYearCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.purple)
                Text("Year-Over-Year")
                    .font(.headline)
            }

            VStack(spacing: 12) {
                HStack {
                    Text("To match last year's purchasing power:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                HStack {
                    VStack(alignment: .leading) {
                        Text("Current")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(currentSalary))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }

                    Spacer()

                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("Need")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(salaryNeededToMatchLastYear))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                }

                let gap = salaryNeededToMatchLastYear - currentSalary
                if gap > 0 && yourRaise == 0 {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("You need \(formatCurrency(gap)) more just to break even")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Projection Card
    private var projectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("Purchasing Power Over Time")
                    .font(.headline)
            }

            Text("Your \(formatCurrency(currentNetMonthly))/month in today's dollars:")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                ForEach([1, 2, 3, 5, 10], id: \.self) { years in
                    let futureValue = purchasingPower(afterYears: years)
                    let percentChange = currentNetMonthly > 0
                        ? ((futureValue - currentNetMonthly) / currentNetMonthly) * 100
                        : 0

                    HStack {
                        Text("\(years) yr")
                            .font(.subheadline)
                            .frame(width: 40, alignment: .leading)

                        GeometryReader { geometry in
                            let maxWidth = geometry.size.width
                            let ratio = currentNetMonthly > 0
                                ? min(max(NSDecimalNumber(decimal: futureValue / currentNetMonthly).doubleValue, 0.3), 1.5)
                                : 1.0
                            let barWidth = maxWidth * CGFloat(ratio / 1.5)

                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color(.systemGray4))
                                    .frame(height: 20)
                                    .cornerRadius(4)

                                Rectangle()
                                    .fill(futureValue >= currentNetMonthly ? Color.green : Color.orange)
                                    .frame(width: barWidth, height: 20)
                                    .cornerRadius(4)
                            }
                        }
                        .frame(height: 20)

                        VStack(alignment: .trailing, spacing: 0) {
                            Text(formatCurrency(futureValue))
                                .font(.caption)
                                .fontWeight(.medium)
                            let percentDouble = NSDecimalNumber(decimal: percentChange).doubleValue
                            Text("\(percentDouble >= 0 ? "+" : "")\(String(format: "%.1f", percentDouble))%")
                                .font(.caption2)
                                .foregroundColor(percentDouble >= 0 ? .green : .red)
                        }
                        .frame(width: 80, alignment: .trailing)
                    }
                }
            }

            // Show cumulative impact
            if yourRaise < inflationRate && currentNetMonthly > 0 {
                let loss5yr = currentNetMonthly - purchasingPower(afterYears: 5)
                let loss10yr = currentNetMonthly - purchasingPower(afterYears: 10)

                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    Text("Cumulative Impact on \(formatCurrency(currentNetMonthly))/month")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    HStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            Text("5-Year Loss")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("-\(formatCurrency(loss5yr))/mo")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            Text("-\(formatCurrency(loss5yr * 12))/yr")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("10-Year Loss")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("-\(formatCurrency(loss10yr))/mo")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                            Text("-\(formatCurrency(loss10yr * 12))/yr")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Show that loss accelerates (compound effect)
                    let firstYearLoss = currentNetMonthly - purchasingPower(afterYears: 1)
                    let year5Loss = purchasingPower(afterYears: 4) - purchasingPower(afterYears: 5)
                    if year5Loss > firstYearLoss {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                            Text("Loss accelerates: Year 1 loses \(formatCurrency(firstYearLoss)), Year 5 loses \(formatCurrency(year5Loss))")
                                .font(.caption2)
                        }
                        .foregroundColor(.red)
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Info Card
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("What This Means")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                InfoRow(
                    icon: "arrow.up.right",
                    color: .green,
                    text: "A raise above inflation = real income growth"
                )
                InfoRow(
                    icon: "equal",
                    color: .blue,
                    text: "A raise matching inflation = staying even"
                )
                InfoRow(
                    icon: "arrow.down.right",
                    color: .red,
                    text: "A raise below inflation = pay cut in disguise"
                )
                InfoRow(
                    icon: "xmark",
                    color: .red,
                    text: "No raise = guaranteed purchasing power loss"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

struct InfoRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Time Value View
struct TimeValueView: View {
    @ObservedObject var viewModel: ScenarioViewModel
    @State private var expenseAmount: String = ""
    @State private var expenseName: String = ""

    var hourlyRate: Decimal {
        viewModel.baseTaxResult?.netHourly ?? 0
    }

    var hoursRequired: Double {
        guard hourlyRate > 0, let amount = Decimal(string: expenseAmount) else { return 0 }
        return NSDecimalNumber(decimal: amount / hourlyRate).doubleValue
    }

    var daysRequired: Double {
        hoursRequired / 8
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hourly Rate Card
                hourlyRateCard

                // Expense Input
                expenseInputCard

                // Result
                if !expenseAmount.isEmpty && hoursRequired > 0 {
                    resultCard
                }

                // Quick Examples
                quickExamples
            }
            .padding()
        }
    }

    private var hourlyRateCard: some View {
        VStack(spacing: 8) {
            Text("Your Time is Worth")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(formatCurrency(hourlyRate))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.accentColor)

            Text("per hour (after taxes)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    private var expenseInputCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How much work does it cost?")
                .font(.headline)

            HStack {
                Text("$")
                    .foregroundColor(.secondary)
                TextField("Amount", text: $expenseAmount)
                    .keyboardType(.decimalPad)
                    .font(.title2)
            }
            .padding()
            .background(Color(.systemGray5))
            .cornerRadius(8)

            TextField("What's it for? (optional)", text: $expenseName)
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var resultCard: some View {
        VStack(spacing: 16) {
            if !expenseName.isEmpty {
                Text("\"\(expenseName)\"")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 32) {
                VStack {
                    Text(String(format: "%.1f", hoursRequired))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    Text("hours")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("=")
                    .font(.title)
                    .foregroundColor(.secondary)

                VStack {
                    Text(String(format: "%.1f", daysRequired))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.purple)
                    Text("work days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text("of your life to pay for this")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    private var quickExamples: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Examples")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(quickExampleItems, id: \.name) { item in
                    Button {
                        expenseAmount = "\(item.amount)"
                        expenseName = item.name
                    } label: {
                        VStack(spacing: 4) {
                            Text(item.name)
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("$\(item.amount)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var quickExampleItems: [(name: String, amount: Int)] {
        [
            ("Coffee", 7),
            ("Lunch out", 20),
            ("Dinner date", 100),
            ("Weekend trip", 500),
            ("New iPhone", 1200),
            ("Vacation", 3000),
        ]
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

#Preview {
    ScenariosView()
        .environmentObject(DependencyContainer())
}
