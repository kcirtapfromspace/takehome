import Foundation

// MARK: - Transaction
/// A single financial transaction (income or expense)
struct Transaction: Identifiable, Codable, Equatable {
    let id: UUID
    var amount: Decimal
    var type: TransactionType
    var category: TransactionCategory
    var description: String
    var date: Date
    var isRecurring: Bool
    var recurringFrequency: ExpenseFrequency?
    var merchantName: String?
    var notes: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        amount: Decimal,
        type: TransactionType,
        category: TransactionCategory,
        description: String,
        date: Date = Date(),
        isRecurring: Bool = false,
        recurringFrequency: ExpenseFrequency? = nil,
        merchantName: String? = nil,
        notes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.amount = abs(amount) // Always store positive, type determines direction
        self.type = type
        self.category = category
        self.description = description
        self.date = date
        self.isRecurring = isRecurring
        self.recurringFrequency = recurringFrequency
        self.merchantName = merchantName
        self.notes = notes
        self.createdAt = createdAt
    }

    /// Signed amount (positive for income, negative for expense)
    var signedAmount: Decimal {
        type == .income ? amount : -amount
    }
}

// MARK: - Transaction Type
enum TransactionType: String, Codable, CaseIterable {
    case income
    case expense

    var displayName: String {
        switch self {
        case .income: return "Income"
        case .expense: return "Expense"
        }
    }

    var icon: String {
        switch self {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        }
    }
}

// MARK: - Transaction Category
enum TransactionCategory: String, Codable, CaseIterable, Identifiable {
    // Income categories
    case salary
    case bonus
    case investment
    case refund
    case gift
    case sideHustle

    // Expense categories (mirror ExpenseCategory)
    case housing
    case utilities
    case groceries
    case dining
    case transportation
    case entertainment
    case shopping
    case healthcare
    case insurance
    case debt
    case savings
    case subscriptions
    case education
    case travel
    case personal
    case other

    var id: String { rawValue }

    var isIncome: Bool {
        switch self {
        case .salary, .bonus, .investment, .refund, .gift, .sideHustle:
            return true
        default:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .salary: return "Salary"
        case .bonus: return "Bonus"
        case .investment: return "Investment"
        case .refund: return "Refund"
        case .gift: return "Gift"
        case .sideHustle: return "Side Hustle"
        case .housing: return "Housing"
        case .utilities: return "Utilities"
        case .groceries: return "Groceries"
        case .dining: return "Dining"
        case .transportation: return "Transportation"
        case .entertainment: return "Entertainment"
        case .shopping: return "Shopping"
        case .healthcare: return "Healthcare"
        case .insurance: return "Insurance"
        case .debt: return "Debt"
        case .savings: return "Savings"
        case .subscriptions: return "Subscriptions"
        case .education: return "Education"
        case .travel: return "Travel"
        case .personal: return "Personal"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .salary: return "dollarsign.circle.fill"
        case .bonus: return "gift.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .refund: return "arrow.uturn.backward.circle.fill"
        case .gift: return "heart.fill"
        case .sideHustle: return "briefcase.fill"
        case .housing: return "house.fill"
        case .utilities: return "bolt.fill"
        case .groceries: return "cart.fill"
        case .dining: return "fork.knife"
        case .transportation: return "car.fill"
        case .entertainment: return "tv.fill"
        case .shopping: return "bag.fill"
        case .healthcare: return "cross.case.fill"
        case .insurance: return "shield.fill"
        case .debt: return "creditcard.fill"
        case .savings: return "banknote.fill"
        case .subscriptions: return "repeat.circle.fill"
        case .education: return "book.fill"
        case .travel: return "airplane"
        case .personal: return "person.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .salary, .bonus, .investment, .refund, .gift, .sideHustle:
            return "green"
        case .housing, .utilities:
            return "blue"
        case .groceries, .dining:
            return "orange"
        case .transportation:
            return "purple"
        case .entertainment, .subscriptions:
            return "pink"
        case .shopping:
            return "indigo"
        case .healthcare, .insurance:
            return "red"
        case .debt:
            return "red"
        case .savings:
            return "green"
        case .education:
            return "cyan"
        case .travel:
            return "teal"
        case .personal, .other:
            return "gray"
        }
    }

    static var incomeCategories: [TransactionCategory] {
        allCases.filter { $0.isIncome }
    }

    static var expenseCategories: [TransactionCategory] {
        allCases.filter { !$0.isIncome }
    }
}

// MARK: - Cashflow Summary
struct CashflowSummary {
    let period: CashflowPeriod
    let startDate: Date
    let endDate: Date
    let totalIncome: Decimal
    let totalExpenses: Decimal
    let transactions: [Transaction]

    var netCashflow: Decimal {
        totalIncome - totalExpenses
    }

    var isPositive: Bool {
        netCashflow >= 0
    }

    var savingsRate: Double {
        guard totalIncome > 0 else { return 0 }
        return NSDecimalNumber(decimal: netCashflow / totalIncome * 100).doubleValue
    }

    var burnRate: Decimal {
        // Daily burn rate
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1
        guard days > 0 else { return 0 }
        return totalExpenses / Decimal(days)
    }

    var expensesByCategory: [(TransactionCategory, Decimal)] {
        let expenses = transactions.filter { $0.type == .expense }
        let grouped = Dictionary(grouping: expenses, by: { $0.category })
        return grouped
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.1 > $1.1 }
    }

    var incomeByCategory: [(TransactionCategory, Decimal)] {
        let income = transactions.filter { $0.type == .income }
        let grouped = Dictionary(grouping: income, by: { $0.category })
        return grouped
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.1 > $1.1 }
    }
}

enum CashflowPeriod: String, CaseIterable, Identifiable {
    case week
    case month
    case quarter
    case year

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .week: return "This Week"
        case .month: return "This Month"
        case .quarter: return "This Quarter"
        case .year: return "This Year"
        }
    }

    var shortName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .quarter: return "Quarter"
        case .year: return "Year"
        }
    }

    func dateRange(from date: Date = Date()) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        switch self {
        case .week:
            let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? date
            return (start, end)
        case .month:
            let start = calendar.dateInterval(of: .month, for: date)?.start ?? date
            let end = calendar.date(byAdding: .month, value: 1, to: start)?.addingTimeInterval(-1) ?? date
            return (start, end)
        case .quarter:
            let quarter = (calendar.component(.month, from: date) - 1) / 3
            let startMonth = quarter * 3 + 1
            var components = calendar.dateComponents([.year], from: date)
            components.month = startMonth
            components.day = 1
            let start = calendar.date(from: components) ?? date
            let end = calendar.date(byAdding: .month, value: 3, to: start)?.addingTimeInterval(-1) ?? date
            return (start, end)
        case .year:
            let start = calendar.dateInterval(of: .year, for: date)?.start ?? date
            let end = calendar.date(byAdding: .year, value: 1, to: start)?.addingTimeInterval(-1) ?? date
            return (start, end)
        }
    }
}

// MARK: - Cashflow Trend
struct CashflowTrend {
    let currentPeriod: CashflowSummary
    let previousPeriod: CashflowSummary?

    var incomeChange: Decimal? {
        guard let prev = previousPeriod, prev.totalIncome > 0 else { return nil }
        return (currentPeriod.totalIncome - prev.totalIncome) / prev.totalIncome * 100
    }

    var expenseChange: Decimal? {
        guard let prev = previousPeriod, prev.totalExpenses > 0 else { return nil }
        return (currentPeriod.totalExpenses - prev.totalExpenses) / prev.totalExpenses * 100
    }

    var netCashflowChange: Decimal? {
        guard let prev = previousPeriod else { return nil }
        return currentPeriod.netCashflow - prev.netCashflow
    }

    var isImproving: Bool {
        guard let change = netCashflowChange else { return true }
        return change >= 0
    }
}
