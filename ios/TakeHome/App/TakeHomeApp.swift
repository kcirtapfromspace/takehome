import SwiftUI
import SuperwallKit

@main
struct TakeHomeApp: App {
    @StateObject private var container = DependencyContainer()

    init() {
        // TODO: Replace with your Superwall API key from https://superwall.com/dashboard
        Superwall.configure(apiKey: "SUPERWALL_API_KEY_PLACEHOLDER")
    }

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
