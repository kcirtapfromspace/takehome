import SwiftUI

struct IncomeView: View {
    @EnvironmentObject private var container: DependencyContainer
    @StateObject private var viewModel: IncomeViewModel
    @State private var showRetirementCalculator = false

    init() {
        _viewModel = StateObject(wrappedValue: IncomeViewModel(
            taxCore: TakeHomeCoreWrapper(),
            profileRepository: InMemoryFinancialProfileRepository()
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                // Income Section
                Section("Gross Income") {
                    CurrencyTextField(
                        title: "Annual Salary",
                        value: $viewModel.grossSalary
                    )

                    Picker("Pay Frequency", selection: $viewModel.payFrequency) {
                        ForEach(PayFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }
                }

                // Location Section
                Section("Location & Filing") {
                    Picker("State", selection: $viewModel.selectedState) {
                        ForEach(viewModel.availableStates) { state in
                            Text(state.displayName).tag(state)
                        }
                    }

                    Picker("Filing Status", selection: $viewModel.filingStatus) {
                        ForEach(viewModel.availableFilingStatuses) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                }

                // Retirement Contributions Section
                Section {
                    CurrencyTextField(
                        title: "Traditional 401(k)",
                        value: $viewModel.traditional401k
                    )

                    CurrencyTextField(
                        title: "Roth 401(k)",
                        value: $viewModel.roth401k
                    )

                    Button {
                        showRetirementCalculator = true
                    } label: {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(.blue)
                            Text("Retirement Calculator")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Retirement Contributions")
                } footer: {
                    let total = viewModel.traditional401k + viewModel.roth401k
                    if total > 0 {
                        Text("Total: \(formatDeductionCurrency(total))/year")
                    }
                }

                // Pre-Tax Deductions Section
                Section {
                    CurrencyTextField(
                        title: "Health Insurance",
                        value: $viewModel.preTaxDeductions
                    )
                } header: {
                    Text("Pre-Tax Deductions")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if viewModel.preTaxDeductions > 0 {
                            Text("Total: \(formatDeductionCurrency(viewModel.preTaxDeductions))/year")
                        }
                        Text("Health, dental, vision premiums • HSA/FSA contributions • Commuter benefits")
                            .font(.caption2)
                    }
                }

                // Post-Tax Deductions Section
                Section {
                    CurrencyTextField(
                        title: "Other Deductions",
                        value: $viewModel.postTaxDeductions
                    )
                } header: {
                    Text("Post-Tax Deductions")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if viewModel.postTaxDeductions > 0 {
                            Text("Total: \(formatDeductionCurrency(viewModel.postTaxDeductions))/year")
                        }
                        Text("Union dues • Garnishments • Charitable donations • Life insurance premiums")
                            .font(.caption2)
                    }
                }

                // Results Section
                if let result = viewModel.calculationResult {
                    Section("Take-Home Pay") {
                        TimeframeCardsView(result: result)
                    }

                    Section("Tax Breakdown") {
                        TaxBreakdownView(result: result)
                    }
                }
            }
            .navigationTitle("Income")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveProfile()
                        }
                    }
                    .disabled(!viewModel.hasValidInput)
                }
            }
            .task {
                await viewModel.loadProfile()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "An error occurred")
            }
            .sheet(isPresented: $showRetirementCalculator) {
                RetirementCalculatorView()
            }
        }
    }

    private func formatDeductionCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

// MARK: - Timeframe Cards View
struct TimeframeCardsView: View {
    let result: TaxCalculationResult

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                TimeframeCard(title: "Annual", amount: result.netAnnual)
                TimeframeCard(title: "Monthly", amount: result.netMonthly)
            }

            HStack(spacing: 12) {
                TimeframeCard(title: "Bi-Weekly", amount: result.netBiWeekly)
                TimeframeCard(title: "Weekly", amount: result.netWeekly)
            }

            HStack(spacing: 12) {
                TimeframeCard(title: "Daily", amount: result.netDaily)
                TimeframeCard(title: "Hourly", amount: result.netHourly)
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

struct TimeframeCard: View {
    let title: String
    let amount: Decimal

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(formatCurrency(amount))
                .font(.headline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = value >= 100 ? 0 : 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

// MARK: - Tax Breakdown View
struct TaxBreakdownView: View {
    let result: TaxCalculationResult

    var body: some View {
        VStack(spacing: 12) {
            TaxRow(label: "Federal Tax", amount: result.federalTax, rate: result.federalEffectiveRate)
            TaxRow(label: "State Tax (\(result.stateCode))", amount: result.stateTotalTax, rate: nil)
            TaxRow(label: "Social Security", amount: result.socialSecurity, rate: nil)
            TaxRow(label: "Medicare", amount: result.medicare, rate: nil)

            Divider()

            HStack {
                Text("Total Taxes")
                    .fontWeight(.semibold)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(formatCurrency(result.totalTaxes))
                        .fontWeight(.semibold)
                    Text("Effective: \(formatPercentage(result.totalEffectiveRate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }

    private func formatPercentage(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: (value / 100) as NSDecimalNumber) ?? "0%"
    }
}

struct TaxRow: View {
    let label: String
    let amount: Decimal
    let rate: Decimal?

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            VStack(alignment: .trailing) {
                Text(formatCurrency(amount))
                if let rate = rate {
                    Text("\(formatPercentage(rate)) effective")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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

    private func formatPercentage(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: (value / 100) as NSDecimalNumber) ?? "0%"
    }
}

// MARK: - Currency TextField
struct CurrencyTextField: View {
    let title: String
    @Binding var value: Decimal

    @State private var textValue: String = ""

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("$0", text: $textValue)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .onChange(of: textValue) { _, newValue in
                    let cleaned = newValue.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
                    if let decimal = Decimal(string: cleaned) {
                        value = decimal
                    }
                }
                .onAppear {
                    if value > 0 {
                        textValue = value.description
                    }
                }
        }
    }
}

#Preview {
    IncomeView()
        .environmentObject(DependencyContainer())
}
