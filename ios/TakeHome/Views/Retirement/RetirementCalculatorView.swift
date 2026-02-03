import SwiftUI

struct RetirementCalculatorView: View {
    @EnvironmentObject private var container: DependencyContainer
    @StateObject private var viewModel: RetirementCalculatorViewModel
    @Environment(\.dismiss) private var dismiss

    init() {
        _viewModel = StateObject(wrappedValue: RetirementCalculatorViewModel(
            taxCore: TakeHomeCoreWrapper(),
            profileRepository: InMemoryFinancialProfileRepository()
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Contribution Summary Card
                    contributionSummaryCard

                    // Traditional 401(k) Section
                    contributionSection(
                        title: "Traditional 401(k)",
                        subtitle: "Pre-tax contributions reduce your taxable income",
                        dollarValue: $viewModel.traditional401k,
                        percentSlider: Binding(
                            get: { viewModel.traditional401kPercentSlider },
                            set: { viewModel.traditional401kPercentSlider = $0 }
                        ),
                        dollarSlider: Binding(
                            get: { viewModel.traditional401kSliderValue },
                            set: { viewModel.traditional401kSliderValue = $0 }
                        ),
                        currentPercent: viewModel.traditional401kPercent,
                        onMax: viewModel.setMaxTraditional,
                        color: .blue
                    )

                    // Roth 401(k) Section
                    contributionSection(
                        title: "Roth 401(k)",
                        subtitle: "Post-tax contributions grow tax-free",
                        dollarValue: $viewModel.roth401k,
                        percentSlider: Binding(
                            get: { viewModel.roth401kPercentSlider },
                            set: { viewModel.roth401kPercentSlider = $0 }
                        ),
                        dollarSlider: Binding(
                            get: { viewModel.roth401kSliderValue },
                            set: { viewModel.roth401kSliderValue = $0 }
                        ),
                        currentPercent: viewModel.roth401kPercent,
                        onMax: viewModel.setMaxRoth,
                        color: .purple
                    )

                    // Limit Warning
                    if let warning = viewModel.limitWarningMessage {
                        limitWarningBanner(message: warning)
                    }

                    // Employer Match Section
                    employerMatchSection

                    // Tax Impact Card
                    if viewModel.resultWithContributions != nil {
                        taxImpactCard
                    }

                    // Traditional vs Roth Comparison
                    if viewModel.totalEmployeeContribution > 0 {
                        comparisonCard
                    }

                    // Age Selector
                    ageSection
                }
                .padding()
            }
            .navigationTitle("Retirement Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveContributions()
                            dismiss()
                        }
                    }
                }
            }
            .task {
                await viewModel.loadData()
            }
        }
    }

    // MARK: - Contribution Summary Card

    private var contributionSummaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Annual Contributions")
                    .font(.headline)
                Spacer()
                // Mode toggle indicator
                Text(viewModel.usePercentageMode ? "% Mode" : "$ Mode")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
            }

            // Summary with both $ and %
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Employee")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(viewModel.totalEmployeeContribution))
                        .font(.title2)
                        .fontWeight(.bold)
                    if viewModel.grossSalary > 0 {
                        Text("\(String(format: "%.1f", viewModel.totalContributionPercent))% of salary")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                if viewModel.hasEmployerMatch && viewModel.employerContribution > 0 {
                    Text("+")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    VStack(spacing: 4) {
                        Text("Employer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(viewModel.vestedEmployerContribution))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }

                    Text("=")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    VStack(spacing: 4) {
                        Text("Total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(viewModel.totalRetirementContribution))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
            }

            // Breakdown by type
            if viewModel.totalEmployeeContribution > 0 {
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                        Text("Traditional:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(formatCurrency(viewModel.traditional401k)) (\(String(format: "%.1f", viewModel.traditional401kPercent))%)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 8, height: 8)
                        Text("Roth:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(formatCurrency(viewModel.roth401k)) (\(String(format: "%.1f", viewModel.roth401kPercent))%)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }

            // Contribution limit progress
            VStack(spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                            .cornerRadius(4)

                        let progress = min(1.0, Double(truncating: (viewModel.totalEmployeeContribution / viewModel.contributionLimit) as NSDecimalNumber))
                        Rectangle()
                            .fill(viewModel.isOverLimit ? Color.red : Color.blue)
                            .frame(width: geometry.size.width * progress, height: 8)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(formatCurrency(viewModel.totalEmployeeContribution)) of \(formatCurrency(viewModel.contributionLimit))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(formatCurrency(viewModel.remainingContributionRoom)) remaining")
                        .font(.caption)
                        .foregroundColor(viewModel.isOverLimit ? .red : .secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Contribution Section

    private func contributionSection(
        title: String,
        subtitle: String,
        dollarValue: Binding<Decimal>,
        percentSlider: Binding<Double>,
        dollarSlider: Binding<Double>,
        currentPercent: Double,
        onMax: @escaping () -> Void,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Max") {
                    onMax()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }

            // Value display with $ ↔ % toggle
            HStack(spacing: 16) {
                // Dollar display (tap to switch to dollar mode)
                Button {
                    viewModel.usePercentageMode = false
                } label: {
                    HStack(spacing: 2) {
                        Text("$")
                            .font(.caption)
                            .fontWeight(viewModel.usePercentageMode ? .regular : .bold)
                        Text(formatNumber(dollarValue.wrappedValue))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(viewModel.usePercentageMode ? .secondary : color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(viewModel.usePercentageMode ? Color.clear : color.opacity(0.15))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Text("/")
                    .foregroundColor(.secondary)

                // Percentage display (tap to switch to percentage mode)
                Button {
                    viewModel.usePercentageMode = true
                } label: {
                    HStack(spacing: 2) {
                        Text(String(format: "%.1f", currentPercent))
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("%")
                            .font(.caption)
                            .fontWeight(viewModel.usePercentageMode ? .bold : .regular)
                    }
                    .foregroundColor(viewModel.usePercentageMode ? color : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(viewModel.usePercentageMode ? color.opacity(0.15) : Color.clear)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Spacer()
            }

            // Slider - changes based on mode
            if viewModel.usePercentageMode {
                Slider(
                    value: percentSlider,
                    in: 0...viewModel.maxSliderValuePercent,
                    step: 0.5
                )
                .tint(color)
            } else {
                Slider(
                    value: dollarSlider,
                    in: 0...viewModel.maxSliderValueDollar,
                    step: 500
                )
                .tint(color)
            }

            // Per paycheck breakdown
            if viewModel.grossSalary > 0 {
                let perPaycheck = dollarValue.wrappedValue / 26 // Bi-weekly
                HStack {
                    Text("\(formatCurrency(perPaycheck))/paycheck")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Tap $ or % to switch modes")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    private func formatNumber(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "0"
    }

    // MARK: - Limit Warning Banner

    private func limitWarningBanner(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Employer Match Section

    private var employerMatchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Employer Match", isOn: $viewModel.hasEmployerMatch)
                .font(.headline)

            if viewModel.hasEmployerMatch {
                VStack(spacing: 16) {
                    HStack {
                        Text("Match Percentage")
                            .font(.subheadline)
                        Spacer()
                        TextField("50", value: $viewModel.employerMatchPercentage, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("%")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Match up to")
                            .font(.subheadline)
                        Spacer()
                        TextField("6", value: $viewModel.employerMatchCap, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("% of salary")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Vesting")
                            .font(.subheadline)
                        Spacer()
                        Picker("Vesting", selection: $viewModel.vestingPercentage) {
                            Text("0%").tag(Decimal(0))
                            Text("25%").tag(Decimal(25))
                            Text("50%").tag(Decimal(50))
                            Text("75%").tag(Decimal(75))
                            Text("100%").tag(Decimal(100))
                        }
                        .pickerStyle(.menu)
                    }

                    if viewModel.employerContribution > 0 {
                        Divider()
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Employer Contribution")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                if viewModel.vestingPercentage < 100 {
                                    Text("(\(formatPercent(viewModel.vestingPercentage)) vested)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(formatCurrency(viewModel.vestedEmployerContribution))
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Tax Impact Card

    private var taxImpactCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tax Impact")
                .font(.headline)

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Annual Tax Savings")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("From traditional 401(k) contributions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(formatCurrency(viewModel.annualTaxSavings))
                        .font(.headline)
                        .foregroundColor(.green)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading) {
                        Text("Take-Home Reduction")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Net change in monthly income")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("-\(formatCurrency(viewModel.monthlyTakeHomeReduction))/mo")
                        .font(.headline)
                        .foregroundColor(.orange)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading) {
                        Text("Effective Cost")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Contribution minus tax savings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(formatCurrency(viewModel.effectiveCostOfContribution))
                        .font(.headline)
                }
            }

            // Result comparison
            if let withContrib = viewModel.resultWithContributions,
               let withoutContrib = viewModel.resultWithoutContributions {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Without 401(k)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(withoutContrib.netMonthly))
                            .font(.subheadline)
                    }

                    Spacer()

                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("With 401(k)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(withContrib.netMonthly))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Comparison Card

    private var comparisonCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Traditional vs Roth")
                .font(.headline)

            Text("If you put \(formatCurrency(viewModel.totalEmployeeContribution)) entirely into one type:")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                // Traditional Option
                VStack(spacing: 8) {
                    Text("All Traditional")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(formatCurrency(viewModel.traditionalNetMonthly))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("monthly take-home")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)

                // Roth Option
                VStack(spacing: 8) {
                    Text("All Roth")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(formatCurrency(viewModel.rothNetMonthly))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    Text("monthly take-home")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
            }

            // Difference explanation
            let diff = viewModel.traditionalVsRothDifference
            if diff != 0 {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text(diff > 0
                        ? "Traditional gives \(formatCurrency(diff)) more monthly take-home, but Roth grows tax-free."
                        : "Both options have similar take-home impact.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Age Section

    private var ageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("I'm 50 or older", isOn: $viewModel.isOver50)
                .font(.subheadline)

            if viewModel.isOver50 {
                Text("Catch-up contribution limit: +\(formatCurrency(RetirementCalculatorViewModel.catchUpLimit))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Formatters

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }

    private func formatPercent(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        formatter.multiplier = 0.01
        return formatter.string(from: value as NSDecimalNumber) ?? "0%"
    }
}

#Preview {
    RetirementCalculatorView()
        .environmentObject(DependencyContainer())
}
