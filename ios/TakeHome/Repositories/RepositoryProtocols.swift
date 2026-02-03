import Foundation
import Combine

// MARK: - Financial Profile Repository
protocol FinancialProfileRepositoryProtocol {
    func save(_ profile: FinancialProfile) async throws
    func load() async throws -> FinancialProfile?
    func delete(_ id: UUID) async throws
    var profilePublisher: AnyPublisher<FinancialProfile?, Never> { get }
}

// MARK: - Expense Repository
protocol ExpenseRepositoryProtocol {
    func save(_ expense: Expense) async throws
    func update(_ expense: Expense) async throws
    func delete(_ id: UUID) async throws
    func loadAll() async throws -> [Expense]
    func loadByCategory(_ category: ExpenseCategory) async throws -> [Expense]
    var expensesPublisher: AnyPublisher<[Expense], Never> { get }
}

// MARK: - Scenario Repository
protocol ScenarioRepositoryProtocol {
    func save(_ scenario: Scenario) async throws
    func update(_ scenario: Scenario) async throws
    func delete(_ id: UUID) async throws
    func loadAll() async throws -> [Scenario]
    var scenariosPublisher: AnyPublisher<[Scenario], Never> { get }
}

// MARK: - In-Memory Implementations (for MVP)

/// In-memory implementation of FinancialProfileRepository
final class InMemoryFinancialProfileRepository: FinancialProfileRepositoryProtocol {
    private var profile: FinancialProfile?
    private let profileSubject = CurrentValueSubject<FinancialProfile?, Never>(nil)

    var profilePublisher: AnyPublisher<FinancialProfile?, Never> {
        profileSubject.eraseToAnyPublisher()
    }

    func save(_ profile: FinancialProfile) async throws {
        self.profile = profile
        profileSubject.send(profile)
    }

    func load() async throws -> FinancialProfile? {
        return profile
    }

    func delete(_ id: UUID) async throws {
        if profile?.id == id {
            profile = nil
            profileSubject.send(nil)
        }
    }
}

/// In-memory implementation of ExpenseRepository
final class InMemoryExpenseRepository: ExpenseRepositoryProtocol {
    private var expenses: [UUID: Expense] = [:]
    private let expensesSubject = CurrentValueSubject<[Expense], Never>([])

    var expensesPublisher: AnyPublisher<[Expense], Never> {
        expensesSubject.eraseToAnyPublisher()
    }

    func save(_ expense: Expense) async throws {
        expenses[expense.id] = expense
        notifyChange()
    }

    func update(_ expense: Expense) async throws {
        expenses[expense.id] = expense
        notifyChange()
    }

    func delete(_ id: UUID) async throws {
        expenses.removeValue(forKey: id)
        notifyChange()
    }

    func loadAll() async throws -> [Expense] {
        return Array(expenses.values).sorted { $0.createdAt < $1.createdAt }
    }

    func loadByCategory(_ category: ExpenseCategory) async throws -> [Expense] {
        return expenses.values.filter { $0.category == category }.sorted { $0.createdAt < $1.createdAt }
    }

    private func notifyChange() {
        expensesSubject.send(Array(expenses.values).sorted { $0.createdAt < $1.createdAt })
    }
}

/// In-memory implementation of ScenarioRepository
final class InMemoryScenarioRepository: ScenarioRepositoryProtocol {
    private var scenarios: [UUID: Scenario] = [:]
    private let scenariosSubject = CurrentValueSubject<[Scenario], Never>([])

    var scenariosPublisher: AnyPublisher<[Scenario], Never> {
        scenariosSubject.eraseToAnyPublisher()
    }

    func save(_ scenario: Scenario) async throws {
        scenarios[scenario.id] = scenario
        notifyChange()
    }

    func update(_ scenario: Scenario) async throws {
        scenarios[scenario.id] = scenario
        notifyChange()
    }

    func delete(_ id: UUID) async throws {
        scenarios.removeValue(forKey: id)
        notifyChange()
    }

    func loadAll() async throws -> [Scenario] {
        return Array(scenarios.values).sorted { $0.createdAt < $1.createdAt }
    }

    private func notifyChange() {
        scenariosSubject.send(Array(scenarios.values).sorted { $0.createdAt < $1.createdAt })
    }
}
