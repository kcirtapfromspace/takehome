import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var container: DependencyContainer

    var body: some View {
        DashboardContentView(viewModel: container.dashboardViewModel)
    }
}

private struct DashboardContentView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @EnvironmentObject private var container: DependencyContainer

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if viewModel.hasProfile {
                        // Income Summary Card
                        incomeSummaryCard

                        // Cashflow Meter
                        cashflowMeterCard

                        // Timeframe Selector
                        timeframeSelector

                        // Expense Overview
                        expenseOverviewCard

                        // Financial Health Ratios
                        financialHealthCard

                        // Top Categories
                        if !viewModel.topExpenseCategories.isEmpty {
                            topCategoriesCard
                        }
                    } else {
                        emptyStateView
                    }
                }
                .padding()
            }
            .navigationTitle(viewModel.isHouseholdMode ? "Household" : "Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.canEnableHouseholdMode {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.toggleHouseholdMode()
                            }
                        } label: {
                            Image(systemName: viewModel.isHouseholdMode ? "person.2.fill" : "person.fill")
                                .font(.title3)
                                .foregroundColor(viewModel.isHouseholdMode ? .accentColor : .secondary)
                                .symbolEffect(.bounce, value: viewModel.isHouseholdMode)
                        }
                        .accessibilityLabel(viewModel.isHouseholdMode ? "Switch to single view" : "Switch to household view")
                    }
                }
            }
            .task {
                await viewModel.loadData()
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Income Summary Card
    private var incomeSummaryCard: some View {
        VStack(spacing: 16) {
            // Header with mode indicator
            if viewModel.isHouseholdMode {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                    Text("Household Net Income")
                        .font(.subheadline)
                }
                .foregroundColor(.secondary)
            } else {
                Text("Net Income")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text(formatCurrency(viewModel.netIncome))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text("per \(viewModel.selectedTimeframe.shortName.lowercased())")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Household income breakdown
            if viewModel.isHouseholdMode && viewModel.hasPartner {
                householdIncomeBreakdown
            } else if let result = viewModel.taxResult {
                singleIncomeDetails(result: result)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Household Income Breakdown
    private var householdIncomeBreakdown: some View {
        VStack(spacing: 12) {
            // Visual split bar
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * CGFloat(viewModel.primarySharePercentage / 100))
                    Rectangle()
                        .fill(Color.green)
                }
            }
            .frame(height: 6)
            .cornerRadius(3)

            HStack {
                // Your income
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                        Text("You")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(formatCurrency(viewModel.primaryNetIncome))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("\(Int(viewModel.primarySharePercentage))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Partner income
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(viewModel.partnerName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                    Text(formatCurrency(viewModel.partnerNetIncome))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("\(Int(viewModel.partnerSharePercentage))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Single Income Details
    private func singleIncomeDetails(result: TaxCalculationResult) -> some View {
        HStack(spacing: 24) {
            VStack {
                Text("Gross")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatCurrency(result.grossAnnual / 12))
                    .font(.headline)
            }

            Divider()
                .frame(height: 30)

            VStack {
                Text("Taxes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatCurrency(result.totalTaxes / 12))
                    .font(.headline)
                    .foregroundColor(.red)
            }

            Divider()
                .frame(height: 30)

            VStack {
                Text("Rate")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatPercentage(result.totalEffectiveRate))
                    .font(.headline)
            }
        }
    }

    // MARK: - Timeframe Selector
    private var timeframeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Timeframe.allCases) { timeframe in
                    Button {
                        withAnimation {
                            viewModel.selectedTimeframe = timeframe
                        }
                    } label: {
                        Text(timeframe.displayName)
                            .font(.subheadline)
                            .fontWeight(viewModel.selectedTimeframe == timeframe ? .semibold : .regular)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.selectedTimeframe == timeframe
                                    ? Color.accentColor
                                    : Color(.systemGray5)
                            )
                            .foregroundColor(
                                viewModel.selectedTimeframe == timeframe
                                    ? .white
                                    : .primary
                            )
                            .cornerRadius(20)
                    }
                }
            }
        }
    }

    // MARK: - Expense Overview Card
    private var expenseOverviewCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Expenses vs Income")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 24) {
                VStack(alignment: .leading) {
                    Text("Expenses")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(viewModel.totalExpenses))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    Text("\(Int(viewModel.expensesPercentage))% of income")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(viewModel.remainingAfterExpenses))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(viewModel.remainingAfterExpenses >= 0 ? .green : .red)
                    Text("\(Int(viewModel.remainingPercentage))% of income")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: min(geometry.size.width * CGFloat(viewModel.expensesPercentage / 100), geometry.size.width), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Top Categories Card
    private var topCategoriesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Expense Categories")
                .font(.headline)

            ForEach(viewModel.topExpenseCategories, id: \.0) { category, amount in
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(.accentColor)
                        .frame(width: 24)

                    Text(category.displayName)
                        .font(.subheadline)

                    Spacer()

                    Text(formatCurrency(amount))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Cashflow Meter Card
    private var cashflowMeterCard: some View {
        VStack(spacing: 16) {
            // Header with period selector
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "gauge.with.needle.fill")
                        .foregroundColor(viewModel.cashflowStatus.color)
                    Text("Cashflow")
                        .font(.headline)
                }

                Spacer()

                // Period picker
                Menu {
                    ForEach(CashflowPeriod.allCases) { period in
                        Button {
                            withAnimation {
                                viewModel.selectedCashflowPeriod = period
                            }
                        } label: {
                            HStack {
                                Text(period.displayName)
                                if viewModel.selectedCashflowPeriod == period {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.selectedCashflowPeriod.shortName)
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }

            // Main Gauge
            CashflowGauge(
                progress: viewModel.cashflowProgress,
                status: viewModel.cashflowStatus,
                netCashflow: viewModel.activeCashflow.netCashflow,
                isProjected: !viewModel.hasTransactions
            )

            // Income vs Expenses
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Income")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(formatCurrency(viewModel.activeCashflow.totalIncome))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }

                Spacer()

                VStack(alignment: .center, spacing: 4) {
                    Text("Net")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(viewModel.activeCashflow.netCashflow))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(viewModel.activeCashflow.isPositive ? .green : .red)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Expenses")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    Text(formatCurrency(viewModel.activeCashflow.totalExpenses))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
            }

            // Status message
            HStack(spacing: 8) {
                Image(systemName: viewModel.cashflowStatus.icon)
                    .foregroundColor(viewModel.cashflowStatus.color)
                Text(viewModel.cashflowStatus.message)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if viewModel.daysRemainingInPeriod > 0 {
                    Text("\(viewModel.daysRemainingInPeriod) days left")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
            }

            // Connect transactions CTA if no transactions
            if !viewModel.hasTransactions {
                Divider()

                Button {
                    // TODO: Navigate to transaction connection
                } label: {
                    HStack {
                        Image(systemName: "link.badge.plus")
                        Text("Connect Bank Account")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.accentColor)
                }

                Text("Currently showing projected cashflow based on your income and budgeted expenses")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Financial Health Card
    private var financialHealthCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Financial Health")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: 12) {
                // Housing Ratio
                FinancialRatioRow(
                    title: "Housing",
                    subtitle: "Recommended: <30%",
                    value: viewModel.housingRatio,
                    status: viewModel.housingRatioStatus
                )

                Divider()

                // Savings Rate
                FinancialRatioRow(
                    title: "Savings Rate",
                    subtitle: "Recommended: >20%",
                    value: viewModel.savingsRate,
                    status: viewModel.savingsRateStatus
                )

                Divider()

                // Discretionary
                FinancialRatioRow(
                    title: "Discretionary",
                    subtitle: "Recommended: <20%",
                    value: viewModel.discretionaryRatio,
                    status: viewModel.discretionaryRatioStatus
                )
            }

            // Recommendation
            if viewModel.housingRatioStatus == .danger {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("Consider reducing housing costs or increasing income")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Profile Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create a financial profile to see your take-home pay, track expenses, and plan your finances")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                container.startNewProfile()
            } label: {
                Label("Create Profile", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)

            #if DEBUG
            // Debug options for loading mock data
            VStack(spacing: 12) {
                Divider()
                    .padding(.vertical, 8)

                Text("Debug Options")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button {
                    Task {
                        await container.loadMockData()
                    }
                } label: {
                    Label("Load Single Profile", systemImage: "person.fill")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                }

                Button {
                    Task {
                        await container.loadMockHouseholdData()
                    }
                } label: {
                    Label("Load Household Profile", systemImage: "person.2.fill")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 40)
            #endif

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Helpers
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

// MARK: - Financial Ratio Row
struct FinancialRatioRow: View {
    let title: String
    let subtitle: String
    let value: Double
    let status: RatioStatus

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Text("\(Int(value))%")
                    .font(.headline)
                    .foregroundColor(status.color)

                Image(systemName: status.icon)
                    .foregroundColor(status.color)
            }
        }
    }
}

// MARK: - Cashflow Gauge
struct CashflowGauge: View {
    let progress: Double  // 0-150 (100 = 20% savings goal met)
    let status: CashflowStatus
    let netCashflow: Decimal
    let isProjected: Bool

    private var normalizedProgress: Double {
        min(max(progress / 100, 0), 1.5)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Circular gauge
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(135))

                // Progress arc
                Circle()
                    .trim(from: 0, to: min(0.75 * normalizedProgress, 0.75))
                    .stroke(
                        status.meterColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(135))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)

                // Center content
                VStack(spacing: 2) {
                    if isProjected {
                        Text("Projected")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Text(formatCompactCurrency(netCashflow))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(netCashflow >= 0 ? status.meterColor : .red)

                    Text("net")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 140, height: 140)

            // Scale indicators
            HStack {
                Text("-")
                    .font(.caption2)
                    .foregroundColor(.red)

                Spacer()

                VStack(spacing: 2) {
                    Image(systemName: "target")
                        .font(.caption2)
                    Text("20%")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)

                Spacer()

                Text("+")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 20)
        }
    }

    private func formatCompactCurrency(_ value: Decimal) -> String {
        let absValue = abs(NSDecimalNumber(decimal: value).doubleValue)
        let sign = value < 0 ? "-" : "+"

        if absValue >= 1000 {
            return "\(sign)$\(String(format: "%.1fK", absValue / 1000))"
        } else {
            return "\(sign)$\(Int(absValue))"
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(DependencyContainer())
}
