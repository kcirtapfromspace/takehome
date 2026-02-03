import SwiftUI

struct HouseholdView: View {
    @EnvironmentObject private var container: DependencyContainer

    var body: some View {
        HouseholdContentView(viewModel: container.householdViewModel)
    }
}

private struct HouseholdContentView: View {
    @ObservedObject var viewModel: HouseholdViewModel
    @EnvironmentObject private var container: DependencyContainer

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Enable Household Toggle
                    householdToggle

                    if viewModel.isHouseholdEnabled {
                        // Income Summary Cards
                        incomeSummarySection

                        // Partner Profile Section
                        partnerProfileSection

                        // Split Method Section
                        splitMethodSection

                        // Expense Split Breakdown
                        if viewModel.currentSplit != nil {
                            expenseSplitSection
                        }

                        // Shared Expenses List
                        sharedExpensesSection
                    } else {
                        householdDisabledView
                    }
                }
                .padding()
            }
            .navigationTitle("Household")
            .task {
                await viewModel.loadData()
            }
        }
    }

    // MARK: - Household Toggle
    private var householdToggle: some View {
        Toggle(isOn: $viewModel.isHouseholdEnabled) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading) {
                    Text("Household Mode")
                        .font(.headline)
                    Text("Track finances with a partner")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Disabled View
    private var householdDisabledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Enable Household Mode")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Track finances with a partner and split shared expenses fairly based on income.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                FeatureListItem(icon: "chart.pie.fill", text: "Proportional expense splitting")
                FeatureListItem(icon: "dollarsign.circle.fill", text: "Combined income view")
                FeatureListItem(icon: "list.bullet", text: "Track shared vs personal expenses")
            }
            .padding()
        }
        .padding(.vertical, 40)
    }

    // MARK: - Income Summary
    private var incomeSummarySection: some View {
        VStack(spacing: 12) {
            Text("Household Income")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                IncomeCard(
                    name: "You",
                    amount: viewModel.primaryNetMonthly,
                    percentage: viewModel.primarySharePercentage,
                    color: .blue
                )

                IncomeCard(
                    name: viewModel.partnerName,
                    amount: viewModel.partnerNetMonthly,
                    percentage: viewModel.partnerSharePercentage,
                    color: .green
                )
            }

            // Total
            HStack {
                Text("Total Monthly")
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatCurrency(viewModel.totalHouseholdNetMonthly))
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    // MARK: - Partner Profile
    private var partnerProfileSection: some View {
        VStack(spacing: 12) {
            Text("Partner Profile")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 16) {
                HStack {
                    Text("Name")
                    Spacer()
                    TextField("Partner", text: $viewModel.partnerName)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Annual Salary")
                    Spacer()
                    DecimalTextField(
                        placeholder: "$0",
                        value: $viewModel.partnerGrossSalary
                    )
                    .frame(width: 120)
                    .multilineTextAlignment(.trailing)
                }

                Picker("State", selection: $viewModel.partnerState) {
                    ForEach(viewModel.availableStates) { state in
                        Text(state.displayName).tag(state)
                    }
                }

                Picker("Filing Status", selection: $viewModel.partnerFilingStatus) {
                    ForEach(viewModel.availableFilingStatuses) { status in
                        Text(status.displayName).tag(status)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    // MARK: - Split Method
    private var splitMethodSection: some View {
        VStack(spacing: 12) {
            Text("Expense Split Method")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                SplitMethodButton(
                    title: "Proportional",
                    subtitle: "Based on income ratio",
                    isSelected: viewModel.splitMethod == .proportional
                ) {
                    viewModel.splitMethod = .proportional
                }

                SplitMethodButton(
                    title: "Equal (50/50)",
                    subtitle: "Split everything evenly",
                    isSelected: viewModel.splitMethod == .equal
                ) {
                    viewModel.splitMethod = .equal
                }
            }
        }
    }

    // MARK: - Expense Split
    private var expenseSplitSection: some View {
        VStack(spacing: 12) {
            Text("Shared Expense Split")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 16) {
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
                .frame(height: 8)
                .cornerRadius(4)

                HStack {
                    VStack(alignment: .leading) {
                        Text("You pay")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(viewModel.primaryShareOfExpenses))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        Text("\(Int(viewModel.primarySharePercentage))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("\(viewModel.partnerName) pays")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(viewModel.partnerShareOfExpenses))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        Text("\(Int(viewModel.partnerSharePercentage))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                HStack {
                    Text("Total Shared Expenses")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(viewModel.totalSharedExpensesMonthly))
                        .fontWeight(.semibold)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    // MARK: - Shared Expenses List
    private var sharedExpensesSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Shared Expenses")
                    .font(.headline)
                Spacer()
                NavigationLink(destination: ExpensesView()) {
                    Text("Manage")
                        .font(.subheadline)
                }
            }

            if viewModel.sharedExpenses.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("No shared expenses yet")
                        .foregroundColor(.secondary)
                    Text("Mark expenses as shared in the Expenses tab")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.sharedExpenses) { expense in
                        HStack {
                            Image(systemName: expense.category.icon)
                                .foregroundColor(.accentColor)
                                .frame(width: 24)

                            Text(expense.name)

                            Spacer()

                            Text(formatCurrency(expense.monthlyAmount))
                                .fontWeight(.medium)
                        }
                        .padding()

                        if expense.id != viewModel.sharedExpenses.last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Helpers
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

// MARK: - Supporting Views
struct IncomeCard: View {
    let name: String
    let amount: Decimal
    let percentage: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text(formatCurrency(amount))
                .font(.title3)
                .fontWeight(.bold)

            Text("\(Int(percentage))% of total")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
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

struct SplitMethodButton: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct FeatureListItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

struct DecimalTextField: View {
    let placeholder: String
    @Binding var value: Decimal
    @State private var textValue: String = ""

    var body: some View {
        TextField(placeholder, text: $textValue)
            .keyboardType(.decimalPad)
            .onChange(of: textValue) { _, newValue in
                let cleaned = newValue.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
                if let decimal = Decimal(string: cleaned) {
                    value = decimal
                }
            }
            .onAppear {
                if value > 0 {
                    textValue = "\(value)"
                }
            }
    }
}

#Preview {
    HouseholdView()
        .environmentObject(DependencyContainer())
}
