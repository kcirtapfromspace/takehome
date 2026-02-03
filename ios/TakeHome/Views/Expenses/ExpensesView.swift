import SwiftUI

struct ExpensesView: View {
    @EnvironmentObject private var container: DependencyContainer

    var body: some View {
        ExpensesContentView(viewModel: container.expenseViewModel)
    }
}

private struct ExpensesContentView: View {
    @ObservedObject var viewModel: ExpenseViewModel
    @State private var showingAddExpense = false
    @State private var editingExpense: Expense?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.expenses.isEmpty {
                    emptyStateView
                } else {
                    expenseListView
                }
            }
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddExpense = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("All Categories") {
                            viewModel.selectedCategory = nil
                        }
                        Divider()
                        ForEach(ExpenseCategory.allCases) { category in
                            Button {
                                viewModel.selectedCategory = category
                            } label: {
                                Label(category.displayName, systemImage: category.icon)
                            }
                        }
                    } label: {
                        Label(
                            viewModel.selectedCategory?.displayName ?? "Filter",
                            systemImage: "line.3.horizontal.decrease.circle"
                        )
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search expenses")
            .task {
                await viewModel.loadExpenses()
            }
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseView { expense in
                    Task {
                        await viewModel.addExpense(expense)
                    }
                }
            }
            .sheet(item: $editingExpense) { expense in
                EditExpenseView(expense: expense) { updated in
                    Task {
                        await viewModel.updateExpense(updated)
                    }
                }
            }
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "creditcard")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Expenses Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add your expenses to track your spending and see how much you have left after bills")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showingAddExpense = true
            } label: {
                Label("Add Expense", systemImage: "plus")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }

    // MARK: - Expense List
    private var expenseListView: some View {
        List {
            // Summary Section
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Monthly Total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(viewModel.totalMonthlyExpenses))
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("Annual Total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(viewModel.totalAnnualExpenses))
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                .padding(.vertical, 8)
            }

            // Expenses by Category
            ForEach(ExpenseCategory.allCases) { category in
                let categoryExpenses = viewModel.filteredExpenses.filter { $0.category == category }
                if !categoryExpenses.isEmpty {
                    Section {
                        ForEach(categoryExpenses) { expense in
                            ExpenseRow(expense: expense)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingExpense = expense
                                }
                        }
                        .onDelete { offsets in
                            let expensesToDelete = offsets.map { categoryExpenses[$0] }
                            for expense in expensesToDelete {
                                Task {
                                    await viewModel.deleteExpense(expense.id)
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Image(systemName: category.icon)
                            Text(category.displayName)
                            Spacer()
                            Text(formatCurrency(categoryExpenses.reduce(0) { $0 + $1.monthlyAmount }))
                                .foregroundColor(.secondary)
                        }
                    }
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
}

// MARK: - Expense Row
struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.name)
                    .font(.body)

                HStack(spacing: 8) {
                    Text(expense.frequency.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if expense.isShared {
                        Label("Shared", systemImage: "person.2")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(expense.amount))
                    .font(.body)
                    .fontWeight(.medium)

                if expense.frequency != .monthly {
                    Text("\(formatCurrency(expense.monthlyAmount))/mo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

// MARK: - Add Expense View
struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Expense) -> Void

    @State private var name = ""
    @State private var amount = ""
    @State private var frequency: ExpenseFrequency = .monthly
    @State private var category: ExpenseCategory = .other
    @State private var isShared = false
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }

                    Picker("Frequency", selection: $frequency) {
                        ForEach(ExpenseFrequency.allCases) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                }

                Section {
                    Toggle("Shared Expense", isOn: $isShared)
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("Add Expense")
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
                            let expense = Expense(
                                name: name,
                                amount: amountDecimal,
                                frequency: frequency,
                                category: category,
                                isShared: isShared,
                                notes: notes
                            )
                            onSave(expense)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || amount.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Expense View
struct EditExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    let expense: Expense
    let onSave: (Expense) -> Void

    @State private var name: String
    @State private var amount: String
    @State private var frequency: ExpenseFrequency
    @State private var category: ExpenseCategory
    @State private var isShared: Bool
    @State private var notes: String

    init(expense: Expense, onSave: @escaping (Expense) -> Void) {
        self.expense = expense
        self.onSave = onSave
        _name = State(initialValue: expense.name)
        _amount = State(initialValue: expense.amount.description)
        _frequency = State(initialValue: expense.frequency)
        _category = State(initialValue: expense.category)
        _isShared = State(initialValue: expense.isShared)
        _notes = State(initialValue: expense.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }

                    Picker("Frequency", selection: $frequency) {
                        ForEach(ExpenseFrequency.allCases) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                }

                Section {
                    Toggle("Shared Expense", isOn: $isShared)
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
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
                            updated.category = category
                            updated.isShared = isShared
                            updated.notes = notes
                            updated.updatedAt = Date()
                            onSave(updated)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || amount.isEmpty)
                }
            }
        }
    }
}

#Preview {
    ExpensesView()
        .environmentObject(DependencyContainer())
}
