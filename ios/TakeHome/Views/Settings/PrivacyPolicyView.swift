import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("Last updated: February 7, 2026")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    section(
                        title: "Overview",
                        body: "CashCast (\"the App\") is a financial calculator that estimates your take-home pay after federal and state taxes. We are committed to protecting your privacy. This policy describes how the App handles your information."
                    )

                    section(
                        title: "Data Collection",
                        body: "CashCast does not collect, transmit, or store any personal data on external servers. All financial information you enter — including salary, deductions, expenses, and location — is processed and stored locally on your device only. The developer has no access to this data."
                    )

                    section(
                        title: "On-Device Processing",
                        body: "All tax calculations are performed entirely on your device using a built-in calculation engine. No network connection is required for the App's core functionality. Your financial data never leaves your phone."
                    )

                    section(
                        title: "Accounts and Registration",
                        body: "CashCast does not require any account creation, login, or registration. There is no user authentication system. You can use the App immediately after downloading."
                    )
                }

                Group {
                    section(
                        title: "Third-Party Services",
                        body: "The App uses Superwall for subscription management and paywall display. Superwall may collect anonymous usage data such as device type, OS version, and interaction events (e.g., paywall views and subscription status) to provide its service. Superwall does not receive any financial data you enter into the App. For more information, see Superwall's privacy policy at https://superwall.com/privacy."
                    )

                    section(
                        title: "Cookies and Tracking",
                        body: "CashCast does not use cookies, web tracking, advertising identifiers, or any analytics frameworks. The App does not track your behavior or build a profile about you."
                    )

                    section(
                        title: "Data Storage",
                        body: "Information you enter is stored in your device's local storage. If you delete the App, all associated data is permanently removed. There is no cloud backup or sync of your financial data in this version."
                    )

                    section(
                        title: "Children's Privacy",
                        body: "The App does not knowingly collect any information from children under the age of 13. The App is a general-purpose financial calculator rated 4+ on the App Store."
                    )

                    section(
                        title: "Changes to This Policy",
                        body: "We may update this privacy policy from time to time. Any changes will be reflected in the App with an updated \"Last updated\" date. Continued use of the App after changes constitutes acceptance of the updated policy."
                    )

                    section(
                        title: "Contact",
                        body: "If you have questions about this privacy policy or the App's data practices, please contact us at privacy@cashcast.app."
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.large)
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
