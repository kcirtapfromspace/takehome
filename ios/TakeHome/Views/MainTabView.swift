import SwiftUI
import SuperwallKit

struct MainTabView: View {
    @EnvironmentObject private var container: DependencyContainer
    @State private var selectedTab: Tab = .dashboard

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
                .tag(Tab.dashboard)

            IncomeView()
                .tabItem {
                    Label("Income", systemImage: "dollarsign.circle.fill")
                }
                .tag(Tab.income)

            ExpensesView()
                .tabItem {
                    Label("Expenses", systemImage: "creditcard.fill")
                }
                .tag(Tab.expenses)

            ScenariosView()
                .tabItem {
                    Label("Scenarios", systemImage: "slider.horizontal.3")
                }
                .tag(Tab.scenarios)

            HouseholdView()
                .tabItem {
                    Label("Household", systemImage: "person.2.fill")
                }
                .tag(Tab.household)

            SettingsView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
                .tag(Tab.settings)
        }
        .onChange(of: selectedTab) { _, newTab in
            guard !container.isSubscribed else { return }
            switch newTab {
            case .scenarios:
                Superwall.shared.register(placement: "scenario_feature_gate")
            case .household:
                Superwall.shared.register(placement: "household_feature_gate")
            default:
                break
            }
        }
    }

    enum Tab: String {
        case dashboard
        case income
        case expenses
        case scenarios
        case household
        case settings
    }
}

#Preview {
    MainTabView()
        .environmentObject(DependencyContainer())
}
