import Foundation

// MARK: - Expense
/// A single expense entry
struct Expense: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var amount: Decimal
    var frequency: ExpenseFrequency
    var category: ExpenseCategory
    var isShared: Bool
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        frequency: ExpenseFrequency = .monthly,
        category: ExpenseCategory = .other,
        isShared: Bool = false,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.frequency = frequency
        self.category = category
        self.isShared = isShared
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Monthly equivalent of this expense
    var monthlyAmount: Decimal {
        switch frequency {
        case .oneTime:
            return amount / 12
        case .weekly:
            return amount * Decimal(52) / 12
        case .biWeekly:
            return amount * Decimal(26) / 12
        case .monthly:
            return amount
        case .quarterly:
            return amount / 3
        case .annual:
            return amount / 12
        }
    }

    /// Annual equivalent of this expense
    var annualAmount: Decimal {
        switch frequency {
        case .oneTime:
            return amount
        case .weekly:
            return amount * 52
        case .biWeekly:
            return amount * 26
        case .monthly:
            return amount * 12
        case .quarterly:
            return amount * 4
        case .annual:
            return amount
        }
    }
}

// MARK: - Expense Frequency
enum ExpenseFrequency: String, Codable, CaseIterable, Identifiable {
    case oneTime = "one_time"
    case weekly
    case biWeekly = "bi_weekly"
    case monthly
    case quarterly
    case annual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oneTime: return "One-Time"
        case .weekly: return "Weekly"
        case .biWeekly: return "Bi-Weekly"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .annual: return "Annual"
        }
    }
}

// MARK: - Expense Category
/// Categories matching PRD requirements
enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case debt
    case home
    case necessities
    case tech
    case entertainment
    case vehicle
    case education
    case finance
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .debt: return "Debt"
        case .home: return "Home"
        case .necessities: return "Necessities"
        case .tech: return "Tech"
        case .entertainment: return "Entertainment"
        case .vehicle: return "Vehicle"
        case .education: return "Education"
        case .finance: return "Finance"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .debt: return "creditcard.fill"
        case .home: return "house.fill"
        case .necessities: return "cart.fill"
        case .tech: return "desktopcomputer"
        case .entertainment: return "tv.fill"
        case .vehicle: return "car.fill"
        case .education: return "book.fill"
        case .finance: return "dollarsign.circle.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    /// Default expenses for category templates
    static var defaultExpenses: [ExpenseCategory: [String]] {
        [
            .debt: ["Credit Card", "Student Loans", "Personal Loan"],
            .home: ["Rent/Mortgage", "Utilities", "Internet", "Phone", "Home Insurance"],
            .necessities: ["Groceries", "Healthcare", "Clothing"],
            .tech: ["Subscriptions", "Software", "Hardware"],
            .entertainment: ["Streaming", "Dining Out", "Hobbies"],
            .vehicle: ["Car Payment", "Insurance", "Gas", "Maintenance"],
            .education: ["Courses", "Books", "Certifications"],
            .finance: ["Investments", "Savings", "Emergency Fund"],
            .other: ["Miscellaneous"]
        ]
    }
}
