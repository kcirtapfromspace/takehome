import Foundation
import Combine

// MARK: - Base ViewModel
/// Base class for ViewModels providing common functionality
@MainActor
class BaseViewModel: ObservableObject {
    // MARK: - Published State
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: AppError?
    @Published var showError: Bool = false

    // MARK: - Combine
    var cancellables = Set<AnyCancellable>()

    // MARK: - Error Handling
    func setError(_ error: AppError) {
        self.error = error
        self.showError = true
    }

    func clearError() {
        self.error = nil
        self.showError = false
    }

    // MARK: - Loading State
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }

    // MARK: - Async Task Helpers
    func performTask<T>(_ operation: @escaping () async throws -> T) async -> T? {
        setLoading(true)
        clearError()

        do {
            let result = try await operation()
            setLoading(false)
            return result
        } catch let error as AppError {
            setLoading(false)
            setError(error)
            return nil
        } catch let error as TaxCalcError {
            setLoading(false)
            setError(AppError(from: error))
            return nil
        } catch {
            setLoading(false)
            setError(.unknown(error.localizedDescription))
            return nil
        }
    }

    func performTaskWithoutResult(_ operation: @escaping () async throws -> Void) async {
        _ = await performTask(operation)
    }
}
