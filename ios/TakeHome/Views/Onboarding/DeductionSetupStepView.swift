import SwiftUI

struct DeductionSetupStepView: View {
    @Binding var deductionSetupMode: DeductionSetupMode
    @Binding var traditional401k: String
    @Binding var traditional401kInputType: DeductionInputType
    @Binding var healthInsurance: String
    @Binding var healthInsuranceInputType: DeductionInputType
    let grossSalary: Decimal

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                    .padding(.top, 32)

                VStack(spacing: 8) {
                    Text("How would you like to enter deductions?")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)

                    Text("Pre-tax deductions reduce your taxable income")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 16) {
                    ForEach(DeductionSetupMode.allCases) { mode in
                        DeductionSetupModeCard(
                            mode: mode,
                            isSelected: deductionSetupMode == mode,
                            onSelect: { deductionSetupMode = mode }
                        )
                    }
                }
                .padding(.horizontal)

                // Quick Setup Fields (shown when quick mode is selected)
                if deductionSetupMode == .quick {
                    VStack(spacing: 16) {
                        Divider()
                            .padding(.vertical, 8)

                        // 401(k) Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "building.columns.fill")
                                    .foregroundColor(.accentColor)
                                Text("401(k) Contribution")
                                    .font(.headline)
                                Spacer()
                            }

                            Text("Traditional 401(k) contributions reduce your taxable income")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            // Input type toggle
                            Picker("Input Type", selection: $traditional401kInputType) {
                                Text("$").tag(DeductionInputType.dollarAmount)
                                Text("%").tag(DeductionInputType.percentageOfSalary)
                            }
                            .pickerStyle(.segmented)

                            HStack {
                                if traditional401kInputType == .dollarAmount {
                                    Text("$")
                                        .foregroundColor(.secondary)
                                }
                                TextField("0", text: $traditional401k)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(traditional401kInputType == .percentageOfSalary ? .trailing : .leading)
                                if traditional401kInputType == .percentageOfSalary {
                                    Text("%")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)

                            // Show calculated annual amount for percentages
                            if traditional401kInputType == .percentageOfSalary,
                               let percent = Decimal(string: traditional401k),
                               percent > 0 {
                                let annual = min(grossSalary * (percent / 100), 23000)
                                HStack {
                                    Text("Annual contribution:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatCurrency(annual))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    if grossSalary * (percent / 100) > 23000 {
                                        Text("(capped at IRS limit)")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5)

                        // Health Insurance Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.accentColor)
                                Text("Health Insurance")
                                    .font(.headline)
                                Spacer()
                            }

                            Text("Your portion of employer-sponsored health insurance premiums")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            // Input type toggle
                            Picker("Input Type", selection: $healthInsuranceInputType) {
                                Text("$").tag(DeductionInputType.dollarAmount)
                                Text("%").tag(DeductionInputType.percentageOfSalary)
                            }
                            .pickerStyle(.segmented)

                            HStack {
                                if healthInsuranceInputType == .dollarAmount {
                                    Text("$")
                                        .foregroundColor(.secondary)
                                }
                                TextField("0", text: $healthInsurance)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(healthInsuranceInputType == .percentageOfSalary ? .trailing : .leading)
                                if healthInsuranceInputType == .percentageOfSalary {
                                    Text("%")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)

                            // Show calculated annual amount for percentages
                            if healthInsuranceInputType == .percentageOfSalary,
                               let percent = Decimal(string: healthInsurance),
                               percent > 0 {
                                let annual = grossSalary * (percent / 100)
                                HStack {
                                    Text("Annual cost:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatCurrency(annual))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5)
                    }
                    .padding(.horizontal)
                }

                // Info text for detailed mode
                if deductionSetupMode == .detailed {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Detailed Mode")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        Text("You'll be able to enter all 18 deduction types with flexible input options (dollar amounts or percentages, different frequencies).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                Text("You can always change this later in Settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
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

struct DeductionSetupModeCard: View {
    let mode: DeductionSetupMode
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: mode.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .accentColor)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.accentColor : Color.accentColor.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(mode.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: isSelected ? .accentColor.opacity(0.3) : .black.opacity(0.05), radius: isSelected ? 8 : 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DeductionSetupStepView(
        deductionSetupMode: .constant(.quick),
        traditional401k: .constant("6"),
        traditional401kInputType: .constant(.percentageOfSalary),
        healthInsurance: .constant("200"),
        healthInsuranceInputType: .constant(.dollarAmount),
        grossSalary: 100000
    )
}
