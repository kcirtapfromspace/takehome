import SwiftUI

struct DetailedDeductionsStepView: View {
    let isPreTax: Bool
    @Binding var deductionEntries: [DeductionEntry]
    let grossSalary: Decimal
    let payFrequency: PayFrequency
    let onUpdateEntry: (DeductionEntry) -> Void
    let onToggleEntry: (UUID) -> Void

    private var filteredEntries: [DeductionEntry] {
        deductionEntries.filter { $0.type.isPreTax == isPreTax }
    }

    private var totalAnnual: Decimal {
        filteredEntries.reduce(Decimal(0)) { sum, entry in
            sum + entry.annualAmount(grossSalary: grossSalary, payFrequency: payFrequency)
        }
    }

    private var totalPercent: Double {
        guard grossSalary > 0 else { return 0 }
        return NSDecimalNumber(decimal: totalAnnual / grossSalary * 100).doubleValue
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: isPreTax ? "minus.circle.fill" : "minus.circle")
                            .font(.system(size: 50))
                            .foregroundColor(.accentColor)

                        Text(isPreTax ? "Pre-Tax Deductions" : "Post-Tax Deductions")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(isPreTax
                             ? "These reduce your taxable income"
                             : "These are taken from your after-tax pay")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 16)

                    // Deduction Entries
                    VStack(spacing: 12) {
                        ForEach(filteredEntries) { entry in
                            DeductionEntryRow(
                                entry: entry,
                                grossSalary: grossSalary,
                                payFrequency: payFrequency,
                                onUpdate: onUpdateEntry,
                                onToggle: { onToggleEntry(entry.id) }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100) // Space for the bottom summary
                }
            }

            // Running Totals Footer
            VStack(spacing: 8) {
                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isPreTax ? "Pre-Tax Deductions" : "Post-Tax Deductions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 16) {
                            Text(formatCurrency(totalAnnual))
                                .font(.title3)
                                .fontWeight(.semibold)

                            Text("/year")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("% of Pay")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(String(format: "%.1f%%", totalPercent))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .background(Color(.systemBackground).shadow(color: .black.opacity(0.1), radius: 8, y: -2))
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

struct DeductionEntryRow: View {
    let entry: DeductionEntry
    let grossSalary: Decimal
    let payFrequency: PayFrequency
    let onUpdate: (DeductionEntry) -> Void
    let onToggle: () -> Void

    @State private var amountText: String = ""
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Row
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    // Toggle
                    Button(action: onToggle) {
                        Image(systemName: entry.isEnabled ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(entry.isEnabled ? .accentColor : .secondary)
                            .font(.title2)
                    }

                    // Icon
                    Image(systemName: entry.type.icon)
                        .foregroundColor(.accentColor)
                        .frame(width: 24)

                    // Title and Description
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.type.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if !isExpanded {
                            Text(entry.type.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Current Value
                    if entry.isEnabled && entry.amount > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatEntryAmount())
                                .font(.subheadline)
                                .fontWeight(.medium)
                            // Only show frequency for dollar amounts (percentages are always annual)
                            if entry.inputType == .dollarAmount {
                                Text(entry.frequency.shortName)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .padding()

            // Expanded Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    // Description
                    Text(entry.type.description)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Amount Input
                    HStack(spacing: 12) {
                        // Input Type Toggle
                        Picker("Type", selection: Binding(
                            get: { entry.inputType },
                            set: { newType in
                                var updated = entry
                                updated.inputType = newType
                                // Reset frequency to annual when switching to percentage
                                // (frequency doesn't apply to percentage-based deductions)
                                if newType == .percentageOfSalary {
                                    updated.frequency = .annual
                                }
                                onUpdate(updated)
                            }
                        )) {
                            ForEach(DeductionInputType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 80)

                        // Amount Field
                        HStack {
                            if entry.inputType == .dollarAmount {
                                Text("$")
                                    .foregroundColor(.secondary)
                            }
                            TextField("0", text: $amountText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(entry.inputType == .percentageOfSalary ? .trailing : .leading)
                                .onChange(of: amountText) { _, newValue in
                                    if let decimal = Decimal(string: newValue.replacingOccurrences(of: ",", with: "")) {
                                        var updated = entry
                                        updated.amount = decimal
                                        onUpdate(updated)
                                    }
                                }
                            if entry.inputType == .percentageOfSalary {
                                Text("%")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)

                        // Frequency Picker (only shown for dollar amounts)
                        if entry.inputType == .dollarAmount {
                            Picker("Frequency", selection: Binding(
                                get: { entry.frequency },
                                set: { newFreq in
                                    var updated = entry
                                    updated.frequency = newFreq
                                    onUpdate(updated)
                                }
                            )) {
                                ForEach(DeductionFrequency.allCases) { freq in
                                    Text(freq.displayName).tag(freq)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    // IRS Limit Warning
                    if let limit = entry.type.annualLimit {
                        let annual = entry.annualAmount(grossSalary: grossSalary, payFrequency: payFrequency)
                        HStack {
                            Image(systemName: annual > limit ? "exclamationmark.triangle.fill" : "info.circle")
                                .foregroundColor(annual > limit ? .orange : .blue)
                            Text("IRS Limit: \(formatCurrency(limit))")
                                .font(.caption)
                                .foregroundColor(annual > limit ? .orange : .secondary)
                            if let catchUp = entry.type.catchUpLimit {
                                Text("(+\(formatCurrency(catchUp)) if 50+)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if annual > limit {
                            Text("Your annual contribution exceeds the IRS limit")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }

                    // Annual Equivalent
                    if entry.isEnabled && entry.amount > 0 {
                        let annual = entry.annualAmount(grossSalary: grossSalary, payFrequency: payFrequency)
                        HStack {
                            Text("Annual equivalent:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatCurrency(annual))
                                .font(.caption)
                                .fontWeight(.medium)
                            if grossSalary > 0 {
                                Text("(\(String(format: "%.1f", NSDecimalNumber(decimal: annual / grossSalary * 100).doubleValue))% of salary)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
        .onAppear {
            amountText = entry.amount > 0 ? "\(entry.amount)" : ""
        }
    }

    private func formatEntryAmount() -> String {
        if entry.inputType == .percentageOfSalary {
            return "\(entry.amount)%"
        } else {
            return formatCurrency(entry.amount)
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

#Preview {
    DetailedDeductionsStepView(
        isPreTax: true,
        deductionEntries: .constant(DeductionEntry.createDefaults()),
        grossSalary: 100000,
        payFrequency: .biWeekly,
        onUpdateEntry: { _ in },
        onToggleEntry: { _ in }
    )
}
