# TakeHome Go-Live PRD

Product Requirements Document for shipping TakeHome V1 to the App Store.

**Document Version:** 1.0
**Date:** February 7, 2026
**Target Ship Date:** February 21-28, 2026 (2-3 weeks)

---

## 1. Executive Summary

TakeHome is an iOS financial planning app that calculates real take-home pay across six simultaneous timeframes (annual, monthly, bi-weekly, weekly, daily, hourly), with household proportional expense splitting and scenario planning for raises, state moves, and retirement contributions.

### Current State

**Technical Readiness: ~70%**
- Rust tax engine: complete. All 50 states + DC, federal income tax, FICA (Social Security + Medicare), progressive bracket calculations. 53 passing tests with benchmarks.
- UniFFI Swift bindings generated and working. XCFramework (`TakeHomeCore.xcframework`) built for ios-arm64 and ios-arm64-simulator.
- iOS app: 27 SwiftUI views across MVVM architecture. Full onboarding flow (12 steps with conditional branching), dashboard with cashflow gauge, expense management (9 categories), scenario planner, household mode with proportional splitting, retirement calculator, and settings/profile views.
- Core Data local persistence via in-memory repositories (protocol-based, ready for Core Data swap).
- XcodeGen project configuration (`project.yml`), unit tests for all ViewModels, integration tests for Rust core.

**Release Readiness: ~30%**
- No paywall integration (Superwall SDK not added at all).
- Code signing disabled in both Debug and Release configurations (`CODE_SIGNING_ALLOWED: "NO"`).
- No app icon (AppIcon.appiconset exists but contains no image file).
- No screenshots, no App Store metadata, no privacy policy.
- ViewModel wiring from onboarding to dashboard has not been verified end-to-end on a device.
- Tax year disclaimer exists in Settings but is not prominent enough in the calculation views.

### What Must Happen

Eight work items must be completed before App Store submission. All are achievable within 2-3 weeks by a solo developer. This PRD specifies each item with acceptance criteria, priority, and estimated effort.

---

## 2. Scope -- Go-Live Only

### In Scope (V1)

- Superwall paywall integration (SDK, initialization, paywall placement, App Store Connect product configuration)
- End-to-end ViewModel wiring verification and bug fixes
- Production code signing (certificates + provisioning profiles)
- Tax year disclaimer in calculation output views
- App icon (1024x1024)
- App Store screenshots (minimum 3)
- App Store metadata (name, subtitle, description, keywords, category, privacy URL)
- Privacy policy (hosted URL)
- App Store rating prompt after repeated use

### Explicitly Out of Scope for V1

| Feature | Reason |
|---------|--------|
| CloudKit sync | Post-launch; local-only is fine for V1 |
| WASM web calculator | SEO landing page strategy; requires separate build pipeline |
| Fastlane automation | Nice-to-have; manual Xcode upload is acceptable for first submission |
| CI/CD workflows | No GitHub Actions configured; not blocking |
| Bank account connection (Plaid) | Dashboard shows "Connect Bank Account" CTA but this is a V2+ feature |
| State-specific SEO landing pages | Distribution strategy, not app feature |
| Push notifications | No notification use case in V1 |
| iPad-optimized layout | iPhone-first; iPad will work in compatibility mode |
| Widget / Live Activities | Post-launch enhancement |
| Dark mode polish | SwiftUI system colors already provide basic dark mode support |
| Accessibility audit | VoiceOver works with standard SwiftUI controls; formal audit is post-launch |
| Localization | English-only for V1 |

---

## 3. Feature Requirements

### P0 -- Ship Blockers

These items will cause App Store rejection or make the app non-viable if not completed.

---

#### P0-1: Superwall Paywall Integration

**Description:**
Add Superwall SDK to the project and gate premium features behind a paywall. The paywall must appear after the user completes their first tax calculation during onboarding (the "reveal" step), so they experience the core value before being asked to pay. Users who dismiss the paywall get a limited free tier (single calculation, no scenarios, no household mode).

**Current State:**
- Zero Superwall code exists in the project. No SDK dependency, no initialization, no placement events.
- `DependencyContainer.swift` handles app lifecycle but has no paywall logic.
- `TakeHomeApp.swift` is the `@main` entry point (18 lines, no third-party SDK init).

**Implementation Steps:**

1. **Add Superwall SDK via Swift Package Manager**
   - URL: `https://github.com/superwall/Superwall-iOS`
   - Add to `project.yml` under the TakeHome target dependencies:
     ```yaml
     dependencies:
       - package: SuperwallSwiftUI
         url: https://github.com/superwall/Superwall-iOS
         from: "4.0.0"
     ```
   - Alternatively, add directly in Xcode via File > Add Package Dependencies.

2. **Initialize Superwall in TakeHomeApp.swift**
   - Call `Superwall.configure(apiKey:)` in the app's `init()` method.
   - API key is obtained from the Superwall dashboard after creating the TakeHome project.
   ```swift
   @main
   struct TakeHomeApp: App {
       init() {
           Superwall.configure(apiKey: "YOUR_API_KEY")
       }
       // ... existing body
   }
   ```

3. **Define placement events**
   - Primary: `first_calculation_complete` -- triggered after the reveal step in onboarding
   - Secondary: `scenario_feature_gate` -- triggered when free users tap Scenarios tab
   - Secondary: `household_feature_gate` -- triggered when free users tap Household tab

4. **Add paywall gate in OnboardingViewModel.swift**
   - After `calculateTakeHome()` succeeds and the result is displayed on the reveal step, when the user taps "Continue" to proceed to expenses, trigger the Superwall placement.
   - In the `next()` method, after the `.reveal` case calls `saveProfile()` and before advancing:
     ```swift
     case .reveal:
         await saveProfile()
         Superwall.shared.register(placement: "first_calculation_complete")
         advanceToNextVisibleStep(from: currentStep, context: context, steps: allSteps)
         return
     ```

5. **Gate premium tabs in MainTabView.swift**
   - Scenarios tab: check subscription status before allowing access
   - Household tab: check subscription status before allowing access
   - Free tier gets: Dashboard (single profile view) + Income + Expenses + Settings

6. **Configure products in App Store Connect**
   - Create auto-renewable subscription group: "TakeHome Pro"
   - Product 1: `com.takehome.app.pro.monthly` -- $6.99/month
   - Product 2: `com.takehome.app.pro.yearly` -- $39.99/year (52% savings)
   - Set subscription group localization and pricing

7. **Configure Superwall dashboard**
   - Create paywall template with pricing options
   - Map placement events to paywall
   - Set up paywall copy emphasizing: "Unlock All 6 Timeframes, Scenarios & Household Mode"

**Acceptance Criteria:**
- [ ] Superwall SDK compiles and initializes without crash on app launch
- [ ] Paywall appears after first calculation reveal when user taps Continue
- [ ] Paywall displays both monthly ($6.99) and yearly ($39.99) options
- [ ] Purchasing either option dismisses paywall and grants full access
- [ ] Restoring purchases works for returning subscribers
- [ ] Free users can view Dashboard, Income, Expenses, and Settings tabs
- [ ] Free users see paywall when tapping Scenarios or Household tabs
- [ ] Paywall does not appear for subscribed users

**Estimated Effort:** 1.5-2 days

**Dependencies:** Apple Developer account with App Store Connect access, Superwall account.

---

#### P0-2: ViewModel Wiring Verification

**Description:**
Verify that the complete user flow works end-to-end: app launch -> onboarding (all step combinations) -> calculation -> dashboard display -> tab navigation -> settings. Fix any broken wiring between views and ViewModels.

**Current State:**
- `DependencyContainer.swift` provides lazy-initialized ViewModels for all views.
- `TakeHomeApp.swift` switches between `OnboardingView` and `MainTabView` based on `hasCompletedOnboarding` (UserDefaults).
- Onboarding saves profile via `profileRepository.save()`, which currently uses `InMemoryFinancialProfileRepository`.
- Unit tests exist for all ViewModels but do not test the integration between them.
- `completeOnboarding()` saves expenses from onboarding VM to expense repository, then sets the flag.

**Known Risks:**
- After onboarding completes and `MainTabView` loads, `DashboardViewModel.loadData()` must find the saved profile. Since both onboarding and dashboard use the same `profileRepository` instance from `DependencyContainer`, this should work -- but needs device verification.
- The `InMemoryFinancialProfileRepository` stores data in memory only. App restart loses all data. This is acceptable for V1 launch (users re-onboard), but must be documented.
- `SettingsView` has a "Reset Profile" button that calls `resetOnboarding()`, which clears all cached ViewModels. Verify this transitions back to onboarding cleanly.
- The `ExpenseViewModel` must reload after onboarding completes to show expenses added during onboarding.

**Test Matrix:**

| Flow | Steps | Expected |
|------|-------|----------|
| Single, Quick Deductions | Welcome -> Household (single) -> Income ($100K) -> Location (CA) -> Deduction Setup (quick, 6% 401k) -> Reveal -> Expenses (skip) -> Complete -> Dashboard | Dashboard shows net income for CA single filer with 401k deduction |
| Single, Detailed Deductions | Welcome -> Household (single) -> Income ($80K) -> Location (TX) -> Deduction Setup (detailed) -> Pre-Tax -> Post-Tax -> Reveal -> Expenses (add rent $1500) -> Complete -> Dashboard | Dashboard shows TX net income, Expenses tab shows Rent $1500/mo |
| Two Incomes, Quick | Welcome -> Household (two incomes) -> Income ($120K) -> Partner Income (Partner, $90K) -> Household Summary -> Location (NY, MFJ) -> Deduction Setup (quick) -> Reveal -> Complete -> Dashboard | Dashboard shows household toggle, partner split bar, combined income |
| Skip Onboarding | Welcome -> tap X -> "Exit Without Saving" -> Dashboard (empty state) | Dashboard shows "No Profile Yet" with "Create Profile" button |
| Create Profile from Dashboard | (After skip) Dashboard empty state -> "Create Profile" -> goes back to onboarding | Onboarding restarts fresh |
| Reset Profile | Settings -> Reset Profile -> confirm | App returns to onboarding, all data cleared |
| App Restart | Complete onboarding -> force quit -> relaunch | App shows MainTabView (UserDefaults flag persists), but profile data lost (in-memory repo). Dashboard shows empty state. |

**Acceptance Criteria:**
- [ ] All 7 flows in the test matrix complete without crashes
- [ ] Dashboard correctly displays calculated net income after onboarding
- [ ] Timeframe selector works (tapping Hourly/Daily/Weekly/Monthly/Annual updates displayed amount)
- [ ] Household toggle in dashboard correctly switches between single and household views
- [ ] Expense data entered during onboarding appears in Expenses tab
- [ ] Scenarios tab loads and allows creating a new scenario (state move, raise, 401k change)
- [ ] Settings view displays correct profile information (state, filing status, gross salary)
- [ ] Reset Profile returns to onboarding with clean state

**Estimated Effort:** 2-3 days (testing + bug fixes)

**Dependencies:** Working simulator or physical device.

---

#### P0-3: Production Code Signing

**Description:**
Configure Xcode project for production code signing so the app can be archived and uploaded to App Store Connect.

**Current State:**
- `project.yml` has code signing explicitly disabled for both Debug and Release:
  ```yaml
  CODE_SIGN_IDENTITY: ""
  CODE_SIGNING_REQUIRED: "NO"
  CODE_SIGNING_ALLOWED: "NO"
  ```
- Bundle ID is `com.takehome.app` (set in `project.yml`).
- No provisioning profiles exist.

**Implementation Steps:**

1. **Create App ID in Apple Developer Portal**
   - Bundle ID: `com.takehome.app`
   - Capabilities: none required for V1 (no push notifications, no CloudKit, no HealthKit)

2. **Create Distribution Certificate**
   - Type: Apple Distribution (used for both App Store and TestFlight)
   - If a distribution certificate already exists from FaithLock/RouteSetter, reuse it

3. **Create Provisioning Profile**
   - Type: App Store Distribution
   - App ID: `com.takehome.app`
   - Certificate: the distribution certificate from step 2
   - Download and install in Xcode

4. **Update project.yml for code signing**
   ```yaml
   configs:
     Debug:
       CODE_SIGN_IDENTITY: "Apple Development"
       CODE_SIGNING_REQUIRED: "YES"
       CODE_SIGNING_ALLOWED: "YES"
       DEVELOPMENT_TEAM: "YOUR_TEAM_ID"
       PROVISIONING_PROFILE_SPECIFIER: ""
       CODE_SIGN_STYLE: "Automatic"
     Release:
       CODE_SIGN_IDENTITY: "Apple Distribution"
       CODE_SIGNING_REQUIRED: "YES"
       CODE_SIGNING_ALLOWED: "YES"
       DEVELOPMENT_TEAM: "YOUR_TEAM_ID"
       PROVISIONING_PROFILE_SPECIFIER: "TakeHome App Store"
       CODE_SIGN_STYLE: "Manual"
   ```

5. **Regenerate Xcode project**
   ```bash
   cd /Users/thinkstudio/takehome/ios
   xcodegen generate
   ```

6. **Verify archive builds**
   ```bash
   xcodebuild archive -scheme TakeHome -configuration Release \
     -archivePath build/TakeHome.xcarchive \
     -destination 'generic/platform=iOS'
   ```

**Acceptance Criteria:**
- [ ] `xcodebuild archive` succeeds without code signing errors
- [ ] Archive can be exported for App Store upload
- [ ] TestFlight upload succeeds (validates signing)
- [ ] App runs on a physical iOS device (not just simulator)

**Estimated Effort:** 1-2 hours (assuming Apple Developer account is active and team ID is known)

**Dependencies:** Active Apple Developer Program membership ($99/year).

---

#### P0-4: Tax Year Disclaimer

**Description:**
Add a prominent disclaimer that tax rates are based on 2024 data. This must be visible anywhere the app displays calculated tax amounts to avoid user confusion and potential legal issues.

**Current State:**
- `SettingsView.swift` line 264: `"Tax calculations are estimates based on 2024 federal and state tax brackets. Actual taxes may vary. Consult a tax professional for advice."` -- this exists but is buried in the Settings tab.
- The Rust engine hardcodes `2024` as the tax year (`TaxCalculationEngine::new(&data, 2024)`).
- The `TakeHomeCoreWrapper` exposes `taxYear` as a `UInt32` property.
- No disclaimer appears on the reveal step, dashboard, or scenario views.

**Implementation Steps:**

1. **Add disclaimer banner to RevealStepView** (in `OnboardingView.swift`)
   - Below the tax breakdown (total taxes, effective rate), add:
     ```
     Tax rates as of 2024. Estimates only -- consult a tax professional.
     ```
   - Style: `.font(.caption2)`, `.foregroundColor(.secondary)`, with an info icon.

2. **Add disclaimer to DashboardView income summary card**
   - Below the single income details or household breakdown:
     ```
     Based on 2024 tax rates
     ```
   - Style: `.font(.caption2)`, `.foregroundColor(.secondary)`.

3. **Add disclaimer to ScenariosView comparison results**
   - At the bottom of each scenario comparison card.

4. **Dynamic year from Rust engine**
   - Use `taxCore.taxYear` to display the year dynamically rather than hardcoding "2024".
   - Format: `"Based on \(taxCore.taxYear) tax rates"`

**Acceptance Criteria:**
- [ ] Tax year disclaimer is visible on the onboarding reveal step
- [ ] Tax year disclaimer is visible on the dashboard income summary
- [ ] Tax year disclaimer is visible on scenario comparison results
- [ ] Disclaimer text uses the tax year from the Rust engine (not hardcoded)
- [ ] Disclaimer does not obstruct primary content or feel intrusive

**Estimated Effort:** 2-3 hours

**Dependencies:** None.

---

### P1 -- Required for App Store Submission

These items will not cause technical failures but are required by Apple's App Store Review Guidelines.

---

#### P1-1: App Icon

**Description:**
Design and add a 1024x1024 app icon for the App Store and device home screen.

**Current State:**
- `Assets.xcassets/AppIcon.appiconset/Contents.json` exists with the correct structure but references no image file.
- The app will crash or show a blank icon without this.

**Design Direction:**
- Primary concept: A stylized dollar sign ($) or a paycheck/receipt icon, conveying "take-home pay" at a glance.
- Color palette: Green (money/financial health) with a clean white or dark background. Match the app's accent color.
- Style: Modern, minimal, rounded. No text in the icon (Apple's recommendation).
- Avoid: Complex gradients, tiny details that disappear at small sizes, generic calculator imagery.
- Reference: Look at top finance apps (Mint, YNAB, Robinhood) for style cues while being distinct.

**Deliverable:**
- Single 1024x1024 PNG file, no alpha channel, no rounded corners (iOS applies these automatically).
- Place at: `/Users/thinkstudio/takehome/ios/TakeHome/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
- Update `Contents.json` to reference the filename:
  ```json
  {
    "images": [
      {
        "filename": "AppIcon.png",
        "idiom": "universal",
        "platform": "ios",
        "size": "1024x1024"
      }
    ],
    "info": {
      "author": "xcode",
      "version": 1
    }
  }
  ```

**Acceptance Criteria:**
- [ ] 1024x1024 PNG exists in AppIcon.appiconset
- [ ] No transparency/alpha channel
- [ ] Icon is legible at 60x60 (home screen size) and 29x29 (Settings size)
- [ ] Icon renders correctly in Xcode preview and on device/simulator

**Estimated Effort:** 2-4 hours (design iteration with Figma, Midjourney, or similar tool)

**Dependencies:** None.

---

#### P1-2: App Store Screenshots

**Description:**
Create screenshots showcasing TakeHome's key features for the App Store listing. Screenshots are the primary conversion asset -- they must tell a story and demonstrate value within 3 seconds of viewing.

**Specification:**

| Device | Required Size (portrait) | Notes |
|--------|--------------------------|-------|
| iPhone 16 Pro Max (6.9") | 1320 x 2868 | Required for current-gen |
| iPhone 16 Pro (6.3") | 1206 x 2622 | Required |
| iPhone SE (4.7") | 750 x 1334 | Optional but recommended |

**Minimum 3 screenshots, recommended 5-6:**

| # | Screen | Caption (overlay text) | What It Shows |
|---|--------|------------------------|---------------|
| 1 | Onboarding Reveal | "See Your Real Take-Home Pay" | The reveal step showing net annual income, monthly, bi-weekly, and hourly breakdowns. Tax breakdown visible (federal, state, FICA). |
| 2 | Dashboard Multi-Timeframe | "6 Timeframes. One Tap." | Dashboard with timeframe selector showing all 6 options. Income summary card with gross/taxes/rate breakdown. |
| 3 | Scenario Planner | "What If You Moved to Texas?" | Scenario comparison showing CA vs TX, with net difference highlighted in green. Monthly savings amount prominent. |
| 4 | Household Mode | "Fair Expense Splitting, Automatically" | Dashboard in household mode showing the proportional split bar (blue/green), partner income breakdown, combined total. |
| 5 | Expense Tracking | "Track Every Dollar" | Expenses view with multiple categories populated, monthly/annual totals, visual category breakdown. |
| 6 | Dashboard Cashflow Gauge | "Your Financial Health at a Glance" | Cashflow gauge meter, income vs expenses breakdown, financial health ratios (housing, savings, discretionary). |

**Screenshot Creation Process:**
1. Use the app's DEBUG mock data loading (Dashboard empty state -> "Load Single Profile" or "Load Household Profile") to populate realistic data.
2. Run on iPhone 16 Pro Max simulator.
3. Capture via Simulator > File > Save Screen or Cmd+S.
4. Add text overlays and device frame using Previewed.app, Screenshots.pro, or Figma.
5. Story arc for first 3: "See your pay" -> "View all timeframes" -> "Plan your future."

**Acceptance Criteria:**
- [ ] Minimum 3 screenshots at 1320x2868 resolution
- [ ] Text overlays are legible and benefit-driven (not feature-listing)
- [ ] No placeholder/debug UI visible in screenshots
- [ ] Screenshots tell a coherent story when viewed in sequence
- [ ] Mock data looks realistic (not $0 or obviously fake numbers)

**Estimated Effort:** 0.5-1 day

**Dependencies:** P0-2 (ViewModel wiring must work to capture real screens).

---

#### P1-3: App Store Metadata

**Description:**
Complete App Store Connect metadata required for submission.

**App Name (max 30 characters):**
```
TakeHome
```

**Subtitle (max 30 characters):**
```
Salary After Tax Calculator
```

**Promotional Text (max 170 characters, can be updated without review):**
```
See your real take-home pay in 6 timeframes. Plan raises, state moves, and 401k changes. Household mode splits expenses fairly.
```

**Description (max 4000 characters):**
```
TakeHome shows you what you actually earn after taxes -- not just your gross salary, but your real take-home pay displayed in six simultaneous timeframes: annual, monthly, bi-weekly, weekly, daily, and hourly.

ACCURATE TAX CALCULATIONS
- Federal income tax with 2024 progressive brackets
- State income tax for all 50 states + DC
- FICA (Social Security + Medicare)
- Pre-tax deductions: 401(k), HSA, health insurance, FSA, and more
- Post-tax deductions: Roth 401(k), union dues, and custom entries
- Filing status support: Single, Married Filing Jointly, Married Filing Separately, Head of Household

SEE YOUR PAY IN 6 TIMEFRAMES
Your salary means different things depending on how you look at it. TakeHome shows your net income as:
- Annual
- Monthly
- Bi-Weekly
- Weekly
- Daily
- Hourly
No other calculator shows all six at once.

SCENARIO PLANNER
What if you got a raise? Moved to a no-income-tax state? Maxed out your 401(k)? TakeHome lets you compare scenarios side-by-side so you can see the real impact on your take-home pay before making big decisions.

HOUSEHOLD MODE
For couples with two incomes, TakeHome calculates each partner's net income separately and splits shared expenses proportionally based on income contribution. Fair, transparent, automatic.

EXPENSE TRACKING
Track your expenses across 9 categories: housing, debt, necessities, tech, entertainment, vehicle, education, finance, and other. See your cashflow health at a glance with the built-in gauge meter and financial health ratios.

PRIVACY FIRST
All calculations happen on your device. No accounts required. No data leaves your phone. Your financial information stays private.

---
Tax calculations are estimates based on 2024 federal and state tax brackets. Actual results may vary. This app is not a substitute for professional tax advice.
```

**Keywords (max 100 characters, comma-separated):**
```
take home pay,salary calculator,paycheck,net pay,income tax,after tax,pay calculator,tax estimator
```

**Category:**
- Primary: Finance
- Secondary: Utilities

**Content Rating:**
- Age Rating: 4+
- No objectionable content

**Copyright:**
```
2026 TakeHome
```

**Support URL:**
```
https://takehome.app/support
```
(Placeholder -- create a simple page or use a GitHub Pages URL before submission.)

**Privacy Policy URL:**
```
https://takehome.app/privacy
```
(See P1-4.)

**Pricing:**
- Free download with in-app purchases
- Subscription group: "TakeHome Pro"
  - Monthly: $6.99
  - Yearly: $39.99

**App Store Connect Configuration:**
- Distribution: App Store (not Unlisted or Private)
- Availability: United States (expand later)
- Pre-order: No
- App Clips: None
- In-App Events: None for V1

**Acceptance Criteria:**
- [ ] All required metadata fields populated in App Store Connect
- [ ] Keywords total 100 characters or fewer
- [ ] Description mentions key features and includes disclaimer
- [ ] Support URL and Privacy Policy URL resolve to live pages
- [ ] Subscription products created and approved in App Store Connect

**Estimated Effort:** 2-3 hours

**Dependencies:** Privacy policy (P1-4), Superwall product IDs match App Store Connect products (P0-1).

---

#### P1-4: Privacy Policy

**Description:**
Create and host a privacy policy. Apple requires a privacy policy URL for all apps, even those that collect no data.

**Content Requirements:**
TakeHome is a local-only app. The privacy policy should state:
- No personal data is collected, transmitted, or stored on any server.
- All financial calculations happen on-device.
- No accounts, logins, or registrations are required.
- No analytics, tracking, or third-party SDKs collect user data. (Note: if Superwall collects any analytics, disclose this.)
- No cookies or web tracking.
- Data entered into the app (salary, expenses, etc.) is stored locally on the device only and is not accessible to the developer.
- Contact information for privacy inquiries.

**Hosting Options (free, $0 budget):**
1. GitHub Pages: create a `privacy.md` in a `takehome.github.io` repo
2. Notion public page (free)
3. Single HTML file hosted on GitHub Pages

**Acceptance Criteria:**
- [ ] Privacy policy is accessible at a public URL
- [ ] URL is entered in App Store Connect
- [ ] Policy accurately describes data practices
- [ ] Policy includes contact information

**Estimated Effort:** 1 hour

**Dependencies:** None.

---

### P2 -- Nice to Have for V1

These items improve the product but are not required for App Store submission or initial viability.

---

#### P2-1: App Store Rating Prompt

**Description:**
Prompt users to rate the app on the App Store after they have experienced value. Positive ratings improve ASO ranking and conversion.

**Implementation:**
- Use `SKStoreReviewController.requestReview(in:)` (UIKit) or the SwiftUI equivalent.
- Trigger after the user's 5th calculation (tracked via UserDefaults counter).
- Only prompt once per version (Apple enforces this automatically).
- Do not prompt during onboarding or within the first session.

**Placement:**
- In `DashboardViewModel`, increment a `calculationCount` in UserDefaults each time `loadData()` finds a saved profile.
- When count reaches 5, call the review prompt on next dashboard appearance.

**Acceptance Criteria:**
- [ ] Rating prompt appears after 5th dashboard load (not before)
- [ ] Prompt only appears once per app version
- [ ] No prompt during onboarding flow

**Estimated Effort:** 1-2 hours

**Dependencies:** None.

---

#### P2-2: Onboarding Polish

**Description:**
Minor UI improvements to the onboarding flow to increase completion rate and conversion.

**Items:**
1. Add haptic feedback on the reveal step when the take-home number appears (UIImpactFeedbackGenerator, `.heavy`).
2. Animate the net income number counting up from $0 on the reveal step (instead of appearing instantly).
3. Add a brief loading animation on the reveal step (the `isAnimatingReveal` state already exists -- verify it triggers correctly).
4. Remove debug options (`#if DEBUG` block in DashboardView empty state) from Release builds. (This is already handled by the `#if DEBUG` compiler directive, but verify it does not appear in Release archives.)

**Acceptance Criteria:**
- [ ] Haptic feedback fires on reveal
- [ ] Number animation is smooth and completes in under 2 seconds
- [ ] Debug "Load Single Profile" and "Load Household Profile" buttons are not visible in Release builds
- [ ] No visual glitches in onboarding transitions

**Estimated Effort:** 3-4 hours

**Dependencies:** P0-2 (wiring must work first).

---

## 4. Technical Requirements

### Superwall SDK Integration (Detailed)

**Package Addition:**

In `project.yml`, add Superwall as a Swift Package dependency:

```yaml
packages:
  SuperwallSwiftUI:
    url: https://github.com/superwall/Superwall-iOS
    from: "4.0.0"

targets:
  TakeHome:
    dependencies:
      - framework: ../bindings/TakeHomeCore.xcframework
        embed: false
        link: true
      - package: SuperwallSwiftUI
```

After modifying `project.yml`, regenerate the Xcode project:
```bash
cd /Users/thinkstudio/takehome/ios && xcodegen generate
```

**Initialization in TakeHomeApp.swift:**

```swift
import SwiftUI
import SuperwallKit

@main
struct TakeHomeApp: App {
    @StateObject private var container = DependencyContainer()

    init() {
        Superwall.configure(apiKey: "<SUPERWALL_API_KEY>")
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
```

**Placement Events:**

| Event Name | Trigger Location | Purpose |
|------------|-----------------|---------|
| `first_calculation_complete` | `OnboardingViewModel.next()` after `.reveal` step | Primary conversion point |
| `scenario_feature_gate` | `ScenariosView` on appear, when not subscribed | Gate premium feature |
| `household_feature_gate` | `HouseholdView` on appear, when not subscribed | Gate premium feature |

**Subscription Status Check:**

Add a subscription status property to `DependencyContainer`:
```swift
var isSubscribed: Bool {
    Superwall.shared.subscriptionStatus == .active
}
```

### Code Signing Setup

**Current project.yml configs must change from:**
```yaml
configs:
  Debug:
    CODE_SIGN_IDENTITY: ""
    CODE_SIGNING_REQUIRED: "NO"
    CODE_SIGNING_ALLOWED: "NO"
  Release:
    CODE_SIGN_IDENTITY: ""
    CODE_SIGNING_REQUIRED: "NO"
    CODE_SIGNING_ALLOWED: "NO"
```

**To:**
```yaml
configs:
  Debug:
    CODE_SIGN_IDENTITY: "Apple Development"
    CODE_SIGNING_REQUIRED: "YES"
    CODE_SIGNING_ALLOWED: "YES"
    DEVELOPMENT_TEAM: "<TEAM_ID>"
    CODE_SIGN_STYLE: "Automatic"
  Release:
    CODE_SIGN_IDENTITY: "Apple Distribution"
    CODE_SIGNING_REQUIRED: "YES"
    CODE_SIGNING_ALLOWED: "YES"
    DEVELOPMENT_TEAM: "<TEAM_ID>"
    CODE_SIGN_STYLE: "Automatic"
```

After changes, regenerate Xcode project: `cd /Users/thinkstudio/takehome/ios && xcodegen generate`

### Build System Notes

- Project uses XcodeGen (`project.yml`) to generate `TakeHome.xcodeproj`. Any Xcode project changes must be made in `project.yml` and regenerated.
- Rust core is pre-built as `TakeHomeCore.xcframework`. No Rust compilation is needed during normal Xcode builds.
- The pre-build script copies FFI bindings from `../bindings/swift/takehome_core.swift` to the Core directory.
- Minimum deployment target: iOS 17.0.
- Swift version: 5.9.

---

## 5. App Store Assets Specification

### App Icon

| Attribute | Requirement |
|-----------|-------------|
| Format | PNG |
| Size | 1024 x 1024 pixels |
| Color space | sRGB or Display P3 |
| Alpha channel | None (no transparency) |
| Rounded corners | Do not include (iOS adds these) |
| File location | `ios/TakeHome/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` |

**Design Brief:**
- Central motif: A stylized dollar sign or upward arrow combined with a paycheck/receipt shape, suggesting "your money, going up."
- Color: Rich green (#34C759 or similar) on a clean background (white or very dark).
- Style: Flat/modern, no gradients heavier than a subtle one. Must be recognizable at 29x29pt.
- Do not include text, borders, or the app name in the icon.

### Screenshots

**Device Sizes Required:**

| Device | Pixel Size | Points |
|--------|-----------|--------|
| 6.9" (iPhone 16 Pro Max) | 1320 x 2868 | Required |
| 6.3" (iPhone 16 Pro) | 1206 x 2622 | Required |
| 6.1" (iPhone 15) | 1179 x 2556 | Optional |
| 5.5" (iPhone 8 Plus) | 1242 x 2208 | Optional |

**Screenshot Template:**
- Background: Solid color matching the app's accent color or a complementary shade
- Device frame: Optional (frameless screenshots are trending)
- Text: Large, bold, benefit-driven headline above or below the screenshot
- Font: SF Pro Display or system equivalent, white or high-contrast text
- Layout: Phone screenshot centered, text above, 40px padding on all sides

### ASO Keyword Strategy

**Primary Keywords (highest search volume, most relevant):**

| Keyword | Est. Search Volume | Competition | Priority |
|---------|-------------------|-------------|----------|
| take home pay calculator | Very High | Medium | Target #1 |
| salary after tax | Very High | Medium | Target #2 |
| paycheck calculator | Very High | High | Target #3 |
| net pay calculator | High | Low | Target #4 |
| income tax calculator | Very High | High | In description |
| tax estimator | High | Medium | In description |
| salary calculator | Very High | Very High | In subtitle |

**Keyword Placement Strategy:**
- App Name: "TakeHome" (brand -- do not stuff keywords here)
- Subtitle: "Salary After Tax Calculator" (captures "salary", "after tax", "calculator")
- Keyword field: "take home pay,paycheck,net pay,income tax,pay calculator,tax estimator" (remaining high-value terms not in title/subtitle)
- Description: Naturally include all target keywords in the body text

**State-Specific Long-Tail (for future ASO updates):**
- "california income tax calculator"
- "texas take home pay" (no state tax -- high search from people considering moves)
- "new york salary after tax"
- These can be rotated into the keyword field seasonally.

---

## 6. Testing Requirements

### Pre-Submission Test Checklist

All items must pass before creating the App Store submission.

#### Critical Path Tests

- [ ] **Fresh install flow:** Delete app -> install -> complete onboarding (single, quick deductions, $100K salary, CA) -> verify dashboard shows correct net income
- [ ] **Paywall appears:** Complete onboarding reveal step -> tap Continue -> Superwall paywall renders
- [ ] **Purchase flow:** Tap yearly subscription -> complete purchase in sandbox -> paywall dismisses -> all tabs accessible
- [ ] **Restore purchases:** Delete app -> reinstall -> tap Restore Purchases in paywall -> subscription restored
- [ ] **Free tier limits:** Do not purchase -> verify Scenarios and Household tabs are gated
- [ ] **All 50 states:** Run calculation for at least 5 states (CA, TX, NY, FL, WA -- covering income tax, no income tax, and high tax states) and verify results are reasonable
- [ ] **Two-income household:** Complete onboarding with partner -> verify household split display -> verify proportional expense splitting
- [ ] **Expense entry:** Add expenses in 3+ categories during onboarding -> verify they appear in Expenses tab after completion
- [ ] **Scenario comparison:** Create state move scenario (CA -> TX) -> verify net difference is positive and matches expected range
- [ ] **Tax disclaimer visible:** Verify "Based on 2024 tax rates" appears on reveal step, dashboard, and scenario results

#### Device Compatibility Tests

- [ ] iPhone 16 Pro Max (simulator) -- primary screenshot device
- [ ] iPhone SE 3rd gen (simulator) -- smallest supported screen
- [ ] iPhone 15 (simulator or device) -- mid-range
- [ ] iOS 17.0 (minimum deployment target) -- verify on oldest supported version if possible

#### Edge Case Tests

- [ ] Zero income: Enter $0 salary -> verify no crash, shows $0 net
- [ ] Very high income: Enter $10,000,000 -> verify calculation completes, no overflow
- [ ] Maximum 401k: Enter $23,000 401k on $50K salary -> verify cap is applied
- [ ] All filing statuses: Test Single, MFJ, MFS, Head of Household for same salary -> verify different results
- [ ] Comma-formatted input: Enter "100,000" in salary field -> verify parses correctly
- [ ] Empty deductions: Skip all deductions (quick mode, no 401k, no health insurance) -> verify calculation works
- [ ] App backgrounding: Start onboarding -> background app -> return -> verify state preserved
- [ ] Orientation: Rotate to landscape -> verify no layout breakage (app supports landscape per Info.plist)

#### Performance Tests

- [ ] Calculation speed: Tax calculation completes in under 100ms (Rust engine is benchmarked)
- [ ] App launch time: Cold launch to onboarding welcome screen in under 2 seconds
- [ ] Memory: App uses less than 50MB in normal operation
- [ ] No memory leaks during repeated onboarding reset cycles

---

## 7. Launch Checklist

Ordered sequence of every step from current state to App Store submission.

### Phase 1: Foundation (Days 1-3)

- [ ] 1. Verify local build compiles on simulator
  ```bash
  cd /Users/thinkstudio/takehome/ios
  xcodegen generate
  xcodebuild -scheme TakeHome -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
  ```
- [ ] 2. Run existing unit tests, fix any failures
  ```bash
  xcodebuild test -scheme TakeHome \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
  ```
- [ ] 3. Run app on simulator, test all 7 flows from the P0-2 test matrix
- [ ] 4. Fix any broken ViewModel wiring discovered in step 3
- [ ] 5. Add tax year disclaimer to RevealStepView, DashboardView, and ScenariosView (P0-4)

### Phase 2: Paywall Integration (Days 3-5)

- [ ] 6. Create Superwall account and project for TakeHome
- [ ] 7. Add Superwall SDK to `project.yml`, regenerate Xcode project
- [ ] 8. Initialize Superwall in `TakeHomeApp.swift`
- [ ] 9. Add `first_calculation_complete` placement after reveal step
- [ ] 10. Add feature gates for Scenarios and Household tabs
- [ ] 11. Create subscription products in App Store Connect (`com.takehome.app.pro.monthly`, `com.takehome.app.pro.yearly`)
- [ ] 12. Configure Superwall dashboard: paywall template, pricing, placement mapping
- [ ] 13. Test paywall in sandbox: appearance, purchase, restore, dismiss

### Phase 3: Assets (Days 5-8)

- [ ] 14. Design app icon (1024x1024 PNG, no alpha)
- [ ] 15. Add icon to `Assets.xcassets/AppIcon.appiconset/`, update `Contents.json`
- [ ] 16. Capture screenshots using simulator with mock data loaded
- [ ] 17. Add text overlays to screenshots (benefit-driven headlines)
- [ ] 18. Create and host privacy policy (GitHub Pages or Notion)
- [ ] 19. Create support URL (simple contact page or GitHub Issues link)

### Phase 4: App Store Connect Setup (Days 8-10)

- [ ] 20. Create App Store Connect record for TakeHome (bundle ID `com.takehome.app`)
- [ ] 21. Fill in all metadata: name, subtitle, description, keywords, category
- [ ] 22. Upload screenshots for required device sizes
- [ ] 23. Upload app icon (App Store Connect also uses the 1024x1024 from the binary)
- [ ] 24. Set pricing: Free with In-App Purchases
- [ ] 25. Configure subscription group and products
- [ ] 26. Enter Privacy Policy URL and Support URL
- [ ] 27. Complete App Privacy questionnaire (Data Not Collected for most categories)
- [ ] 28. Set content rating (4+, no objectionable content)
- [ ] 29. Select availability (United States)

### Phase 5: Code Signing and Submission (Days 10-12)

- [ ] 30. Set up code signing in `project.yml` (P0-3)
- [ ] 31. Regenerate Xcode project
- [ ] 32. Archive the app
  ```bash
  xcodebuild archive -scheme TakeHome -configuration Release \
    -archivePath build/TakeHome.xcarchive \
    -destination 'generic/platform=iOS'
  ```
- [ ] 33. Export archive for App Store upload
- [ ] 34. Upload to App Store Connect via Xcode Organizer or `xcrun altool`
- [ ] 35. Wait for App Store Connect processing (usually 15-30 minutes)
- [ ] 36. Select the build in App Store Connect
- [ ] 37. Run through all critical path tests one final time on TestFlight build
- [ ] 38. Submit for App Review
- [ ] 39. Monitor for reviewer questions or rejection reasons (typical review: 24-48 hours)

### Phase 6: Post-Submission (While Waiting for Review)

- [ ] 40. Prepare Reddit post templates for r/personalfinance, r/cscareerquestions, r/financialindependence
- [ ] 41. Draft Product Hunt listing (title, tagline, description, images)
- [ ] 42. Set up basic analytics tracking plan for post-launch metrics (downloads, trials, conversions, retention)
- [ ] 43. Plan first ASO iteration based on initial keyword rankings

### Success Criteria for V1 Launch

| Metric | Target (30 days post-launch) |
|--------|------------------------------|
| Downloads | 200-500 organic |
| Trial starts | 40-100 (20% of downloads) |
| Paid conversions | 8-25 (20-25% of trials) |
| Day 7 retention | >30% |
| App Store rating | 4.0+ (from rating prompt) |
| Crash-free rate | >99.5% |
| MRR | $50-175 |

---

## Appendix A: File Reference

Key files that will be modified during go-live work:

| File | Path | Modification |
|------|------|-------------|
| App entry point | `/Users/thinkstudio/takehome/ios/TakeHome/App/TakeHomeApp.swift` | Superwall init |
| Dependency container | `/Users/thinkstudio/takehome/ios/TakeHome/App/DependencyContainer.swift` | Subscription status property |
| Onboarding VM | `/Users/thinkstudio/takehome/ios/TakeHome/ViewModels/OnboardingViewModel.swift` | Paywall placement after reveal |
| Onboarding view | `/Users/thinkstudio/takehome/ios/TakeHome/Views/Onboarding/OnboardingView.swift` | Tax disclaimer on reveal step |
| Dashboard view | `/Users/thinkstudio/takehome/ios/TakeHome/Views/Dashboard/DashboardView.swift` | Tax disclaimer on income card |
| Main tab view | `/Users/thinkstudio/takehome/ios/TakeHome/Views/MainTabView.swift` | Feature gates on Scenarios/Household tabs |
| Scenarios view | `/Users/thinkstudio/takehome/ios/TakeHome/Views/Scenarios/ScenariosView.swift` | Tax disclaimer |
| Settings view | `/Users/thinkstudio/takehome/ios/TakeHome/Views/Settings/SettingsView.swift` | Already has disclaimer (no change) |
| Project config | `/Users/thinkstudio/takehome/ios/project.yml` | Superwall dependency, code signing |
| App icon | `/Users/thinkstudio/takehome/ios/TakeHome/Resources/Assets.xcassets/AppIcon.appiconset/` | Add PNG + update Contents.json |
| Info.plist | `/Users/thinkstudio/takehome/ios/TakeHome/Resources/Info.plist` | No changes needed (ITSAppUsesNonExemptEncryption already set to false) |

## Appendix B: Rust Core Engine Summary

The tax calculation engine does not need any changes for V1. Summary of what is built and tested:

- **50 states + DC:** All state income tax brackets implemented, including 9 no-income-tax states (AK, FL, NV, NH, SD, TN, TX, WA, WY)
- **Federal:** 2024 progressive brackets for all filing statuses, standard deduction by filing status
- **FICA:** Social Security (6.2% up to $168,600 wage base), Medicare (1.45% + 0.9% Additional Medicare Tax above threshold)
- **Deductions:** Pre-tax (401k traditional, HSA, health insurance, FSA, dependent care FSA, transit, parking) and post-tax (Roth 401k, union dues, custom)
- **Timeframes:** Annual, monthly ($ann/12), bi-weekly ($ann/26), weekly ($ann/52), daily ($ann/260), hourly ($ann/2080)
- **Scenarios:** Side-by-side comparison with net difference and monthly difference
- **Household:** Proportional, equal, and custom split methods
- **Tests:** 53 passing tests including edge cases (zero income, max deductions, all states, all filing statuses)
- **Benchmarks:** Calculation completes in microseconds

Tax year is hardcoded to 2024. Annual update process: update bracket data in Rust source files, run tests, rebuild XCFramework. Estimated annual effort: 1-2 days.
