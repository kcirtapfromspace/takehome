import SwiftUI

@main
struct TakeHomeApp: App {
    @StateObject private var container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            if container.hasCompletedOnboarding {
                MainTabView()
                    .environmentObject(container)
            } else {
                OnboardingView()
                    .environmentObject(container)
            }
        }
    }
}
