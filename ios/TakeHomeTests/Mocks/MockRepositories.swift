import Foundation
import Combine
@testable import TakeHome

// MARK: - Mock Financial Profile Repository
final class MockFinancialProfileRepository: FinancialProfileRepositoryProtocol {
    private var storedProfile: FinancialProfile?
    private let subject = CurrentValueSubject<FinancialProfile?, Never>(nil)

    var saveCallCount = 0
    var loadCallCount = 0
    var deleteCallCount = 0
    var shouldThrowError: Error?

    var profilePublisher: AnyPublisher<FinancialProfile?, Never> {
        subject.eraseToAnyPublisher()
    }

    func save(_ profile: FinancialProfile) async throws {
        saveCallCount += 1
        if let error = shouldThrowError {
            throw error
        }
        storedProfile = profile
        subject.send(profile)
    }

    func load() async throws -> FinancialProfile? {
        loadCallCount += 1
        if let error = shouldThrowError {
            throw error
        }
        return storedProfile
    }

    func delete(_ id: UUID) async throws {
        deleteCallCount += 1
        if let error = shouldThrowError {
            throw error
        }
        if storedProfile?.id == id {
            storedProfile = nil
            subject.send(nil)
        }
    }

    func reset() {
        storedProfile = nil
        subject.send(nil)
        saveCallCount = 0
        loadCallCount = 0
        deleteCallCount = 0
        shouldThrowError = nil
    }

    func setProfile(_ profile: FinancialProfile) {
        storedProfile = profile
        subject.send(profile)
    }
}

// MARK: - Mock Expense Repository
final class MockExpenseRepository: ExpenseRepositoryProtocol {
    private var expenses: [UUID: Expense] = [:]
    private let subject = CurrentValueSubject<[Expense], Never>([])

    var saveCallCount = 0
    var updateCallCount = 0
    var deleteCallCount = 0
    var loadAllCallCount = 0
    var shouldThrowError: Error?

    var expensesPublisher: AnyPublisher<[Expense], Never> {
        subject.eraseToAnyPublisher()
    }

    func save(_ expense: Expense) async throws {
        saveCallCount += 1
        if let error = shouldThrowError {
            throw error
        }
        expenses[expense.id] = expense
        notifyChange()
    }

    func update(_ expense: Expense) async throws {
        updateCallCount += 1
        if let error = shouldThrowError {
            throw error
        }
        expenses[expense.id] = expense
        notifyChange()
    }

    func delete(_ id: UUID) async throws {
        deleteCallCount += 1
        if let error = shouldThrowError {
            throw error
        }
        expenses.removeValue(forKey: id)
        notifyChange()
    }

    func loadAll() async throws -> [Expense] {
        loadAllCallCount += 1
        if let error = shouldThrowError {
            throw error
        }
        return Array(expenses.values).sorted { $0.createdAt < $1.createdAt }
    }

    func loadByCategory(_ category: ExpenseCategory) async throws -> [Expense] {
        if let error = shouldThrowError {
            throw error
        }
        return expenses.values.filter { $0.category == category }.sorted { $0.createdAt < $1.createdAt }
    }

    private func notifyChange() {
        subject.send(Array(expenses.values).sorted { $0.createdAt < $1.createdAt })
    }

    func reset() {
        expenses.removeAll()
        subject.send([])
        saveCallCount = 0
        updateCallCount = 0
        deleteCallCount = 0
        loadAllCallCount = 0
        shouldThrowError = nil
    }

    func addExpenses(_ newExpenses: [Expense]) {
        for expense in newExpenses {
            expenses[expense.id] = expense
        }
        notifyChange()
    }
}

// MARK: - Mock Scenario Repository
final class MockScenarioRepository: ScenarioRepositoryProtocol {
    private var scenarios: [UUID: Scenario] = [:]
    private let subject = CurrentValueSubject<[Scenario], Never>([])

    var saveCallCount = 0
    var updateCallCount = 0
    var deleteCallCount = 0
    var loadAllCallCount = 0
    var shouldThrowError: Error?

    var scenariosPublisher: AnyPublisher<[Scenario], Never> {
        subject.eraseToAnyPublisher()
    }

    func save(_ scenario: Scenario) async throws {
        saveCallCount += 1
        if let error = shouldThrowError {
            throw error
        }
        scenarios[scenario.id] = scenario
        notifyChange()
    }

    func update(_ scenario: Scenario) async throws {
        updateCallCount += 1
        if let error = shouldThrowError {
            throw error
        }
        scenarios[scenario.id] = scenario
        notifyChange()
    }

    func delete(_ id: UUID) async throws {
        deleteCallCount += 1
        if let error = shouldThrowError {
            throw error
        }
        scenarios.removeValue(forKey: id)
        notifyChange()
    }

    func loadAll() async throws -> [Scenario] {
        loadAllCallCount += 1
        if let error = shouldThrowError {
            throw error
        }
        return Array(scenarios.values).sorted { $0.createdAt < $1.createdAt }
    }

    private func notifyChange() {
        subject.send(Array(scenarios.values).sorted { $0.createdAt < $1.createdAt })
    }

    func reset() {
        scenarios.removeAll()
        subject.send([])
        saveCallCount = 0
        updateCallCount = 0
        deleteCallCount = 0
        loadAllCallCount = 0
        shouldThrowError = nil
    }

    func addScenarios(_ newScenarios: [Scenario]) {
        for scenario in newScenarios {
            scenarios[scenario.id] = scenario
        }
        notifyChange()
    }
}
