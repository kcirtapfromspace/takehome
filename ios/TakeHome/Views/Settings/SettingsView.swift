import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var container: DependencyContainer
    @State private var showResetConfirmation = false
    @State private var showNewProfileConfirmation = false
    @State private var profile: FinancialProfile?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Summary Card
                    profileSummaryCard

                    // Profile Actions
                    profileActionsSection

                    // App Info
                    appInfoSection

                    // Resources
                    resourcesSection

                    // Disclaimer
                    disclaimerSection
                }
                .padding()
            }
            .navigationTitle("Profile")
            .task {
                profile = try? await container.profileRepository.load()
            }
            .alert("Reset Profile?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    container.resetOnboarding()
                }
            } message: {
                Text("This will clear your current profile and take you back through the onboarding flow.")
            }
            .alert("Create New Profile?", isPresented: $showNewProfileConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Create New", role: .none) {
                    container.startNewProfile()
                }
            } message: {
                Text("This will start the onboarding process to set up a new financial profile.")
            }
        }
    }

    // MARK: - Profile Summary Card
    private var profileSummaryCard: some View {
        VStack(spacing: 16) {
            // Profile Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "person.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
            }

            if let profile = profile {
                VStack(spacing: 4) {
                    Text(profile.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(profile.location.state.displayName) • \(profile.location.filingStatus.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Income Summary
                HStack(spacing: 24) {
                    VStack {
                        Text("Gross Salary")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(profile.income.grossSalary))
                            .font(.headline)
                    }

                    Divider()
                        .frame(height: 30)

                    VStack {
                        Text("Pay Frequency")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(profile.income.payFrequency.displayName)
                            .font(.headline)
                    }
                }
                .padding(.top, 8)
            } else {
                VStack(spacing: 8) {
                    Text("No Profile")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Create a profile to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    // MARK: - Profile Actions
    private var profileActionsSection: some View {
        VStack(spacing: 12) {
            // Create New Profile - Primary Action
            Button {
                showNewProfileConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "person.badge.plus")
                        .font(.title3)
                    Text("Create New Profile")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            // Edit Current Profile
            if profile != nil {
                Button {
                    container.resetOnboarding()
                } label: {
                    HStack {
                        Image(systemName: "pencil")
                            .font(.title3)
                        Text("Edit Profile")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
            }

            // Reset Profile
            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3)
                    Text("Reset Profile")
                        .font(.headline)
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - App Info
    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App Info")
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                .padding()

                Divider()

                HStack {
                    Text("Tax Year")
                    Spacer()
                    Text("2024")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    // MARK: - Resources
    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resources")
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(.accentColor)
                        Text("Privacy Policy")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                Divider()

                Link(destination: URL(string: "https://github.com/takehome")!) {
                    HStack {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .foregroundColor(.accentColor)
                        Text("Source Code")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                Divider()

                Link(destination: URL(string: "https://www.irs.gov/filing")!) {
                    HStack {
                        Image(systemName: "building.columns.fill")
                            .foregroundColor(.accentColor)
                        Text("IRS Filing Information")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    // MARK: - Disclaimer
    private var disclaimerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Disclaimer")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Tax calculations are estimates based on 2024 federal and state tax brackets. Actual taxes may vary. Consult a tax professional for advice.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }

    // MARK: - Helpers
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

#Preview {
    SettingsView()
        .environmentObject(DependencyContainer())
}
