import SwiftUI

struct PartnerIncomeStepView: View {
    @Binding var partnerName: String
    @Binding var grossSalary: String
    @Binding var payFrequency: PayFrequency
    @Binding var salaryInputFrequency: DeductionFrequency
    @Binding var selectedState: USState
    @Binding var filingStatus: FilingStatus
    let availableStates: [USState]
    let availableFilingStatuses: [FilingStatus]

    // Computed annual salary for display
    private var annualSalary: Decimal {
        let raw = Decimal(string: grossSalary.replacingOccurrences(of: ",", with: "")) ?? 0
        return salaryInputFrequency.toAnnual(raw, payFrequency: payFrequency)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "person.fill.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                    .padding(.top, 32)

                VStack(spacing: 8) {
                    Text("Partner's Income")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Enter your partner's income for proportional expense splitting")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 16) {
                    // Partner Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Partner's Name")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("Name", text: $partnerName)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    // Salary Input
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Gross Salary")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Before taxes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("$")
                                .font(.title2)
                                .foregroundColor(.secondary)

                            TextField("0", text: $grossSalary)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .keyboardType(.numberPad)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)

                        // Frequency Toggle
                        Picker("Input Frequency", selection: $salaryInputFrequency) {
                            ForEach(DeductionFrequency.allCases) { freq in
                                Text(freq.displayName).tag(freq)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Annual Summary Card
                    if annualSalary > 0 {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Annual Salary")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatCurrency(annualSalary))
                                    .font(.headline)
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

                    // State Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("State")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Picker("State", selection: $selectedState) {
                            ForEach(availableStates) { state in
                                Text(state.displayName).tag(state)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }

                    // Filing Status
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 5)
                .padding(.horizontal)

                Text("Partner's income is used to calculate fair expense splitting based on income ratios")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 32)
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

#Preview {
    PartnerIncomeStepView(
        partnerName: .constant("Jane"),
        grossSalary: .constant("75000"),
        payFrequency: .constant(.biWeekly),
        salaryInputFrequency: .constant(.annual),
        selectedState: .constant(.california),
        filingStatus: .constant(.marriedFilingJointly),
        availableStates: USState.allCases,
        availableFilingStatuses: FilingStatus.allCases
    )
}
