# **TakeHome PRD v2.0**
### *iOS Financial Planning App Based on Patrick's Proven System*

---

## **Executive Summary**

This PRD is based on a **battle-tested Google Sheets system** used since 2015 to manage complex household finances, including:
- Dual-income household planning with proportional expense sharing
- Multi-timeframe income breakdowns (annual → hourly)
- Precise tax calculations using progressive bracket formulas
- Retirement planning with compound growth projections
- Salary trajectory modeling
- Credit card debt management
- Expense ratio analysis

**The Goal**: Transform this proven spreadsheet methodology into an intuitive iOS app that helps people understand their **real take-home pay** and plan their financial future.

---

## **1. Core Value Proposition**

### **"Your Spreadsheet. In Your Pocket. Smarter."**

**What Makes This Different:**
- Not another spending tracker - this is a **financial planning engine**
- Shows income across ALL timeframes simultaneously (vital for hourly negotiation, monthly budgeting, annual planning)
- Handles complex household scenarios (dual income, proportional sharing)
- Projects your financial future with real salary growth models
- Calculates taxes with progressive bracket precision

---

## **2. Core Features - Extracted from Your Sheet**

### **2.1 Multi-Timeframe Income View** ⭐ UNIQUE DIFFERENTIATOR

Your sheet shows income in 6 simultaneous views:
- **Annual**: $165,000
- **Monthly**: $13,750
- **Bi-Weekly**: $6,346.15
- **Weekly**: $3,173.08
- **Daily**: $634.62
- **Hourly**: $79.33

**Why This Matters:**
- Salary negotiations happen in annual terms
- Budgets happen in monthly terms
- Paychecks come bi-weekly
- PTO planning needs daily rates
- Contractors think hourly

**App Feature**: Synchronized income display that updates across all timeframes in real-time as you adjust one.

---

### **2.2 Progressive Tax Calculation Engine**

Your "Tax stuff" sheet uses VLOOKUP to calculate taxes across progressive brackets.

**Current Tax Calculations:**
```
Federal Withholding: $39,066.10 (23.68%)
Social Security: $8,853.60 (capped at $142,800)
Medicare: $2,310.00 (1.45%)
Colorado State: $7,639.50
SDI: $458.90
Total Tax: $61,752.82 (37.43% effective rate)
```

**App Feature**: 
- State-specific tax calculations (all 50 states)
- Automatic Social Security wage base cap
- Real-time "what if" scenarios:
  - "What if I move to Texas?" (no state tax)
  - "What if I get a $20K raise?" (marginal vs effective rate education)
  - "What if I max out 401k?" (pre-tax reduction impact)

---

### **2.3 Retirement Contribution Modeling**

Your sheet tracks:
- **401k Roth**: $11,550 (post-tax)
- **401k Traditional**: $11,550 (pre-tax)
- **Employer Match**: $693 (3% match)

**App Feature**:
- Visual slider to adjust contributions
- Show impact on:
  - Current paycheck
  - Tax savings (for traditional)
  - Employer match maximization
  - Future retirement projections
- Alert when leaving employer match on table

---

### **2.4 Household Income Management** ⭐ UNDERSERVED MARKET

Your sheet handles dual income elegantly:
- **Total Household Income**: $202,440
- **Patrick's Share**: 81.51%
- **Jensina's Share**: 18.49%
- **Shared Expenses**: $4,014/month allocated proportionally

**App Feature**:
- "Household Mode" for couples/roommates
- Fair expense splitting based on income ratios
- Track "my expenses" vs "our expenses" vs "their expenses"
- Prevent financial friction in relationships

**Target Market**: This is HUGE for:
- Cohabiting couples
- Married couples with income disparity
- Roommate expense sharing

---

### **2.5 Expense Categories from Your Sheet**

**Debt/Fixed:**
- Rent/Mortgage: $39,259/year ($3,271/month) - 47.79% of net

**Home:**
- Utilities (water, electric, waste): $1,982/year
- Internet: $900/year

**Necessities:**
- Groceries: $4,800/year
- Gym: $4,800/year

**Tech/Tools:**
- TradingView: $600
- 1Password: $35
- ChatGPT: $240
- AWS: $300

**Entertainment:**
- Golf: $1,800
- Streaming (Netflix, Apple, Prime, Audible): $1,377

**Vehicle:**
- Fuel: $1,200
- Insurance: $1,980
- Starlink: $600

**Education:**
- Certs: $600
- LeetCode: $200

**Finance:**
- IRA Fees: $350

**Total Annual Expenses**: $61,024.21
**Monthly**: $5,085.35

**App Feature**:
- Pre-built category templates based on your proven structure
- Customizable categories
- Percentage of net income for each category
- Alerts when categories exceed healthy thresholds

---

### **2.6 Salary Projection Model** ⭐ POWERFUL PLANNING TOOL

Your "Salary Prediction" sheet projects 10 years forward with:
- Year 1-3: 3.5% growth
- Year 4-8: 3.0% growth
- Year 9-10: 2.9% growth

**Example from Your Sheet:**
- Current: $165,000
- Year 5: $190,982
- Year 10: $221,584

**App Feature**:
- Customizable growth rates (conservative/moderate/aggressive)
- Job change scenario modeling
- Promotion impact calculator
- Side income addition
- Visual 10-year trajectory chart

---

### **2.7 Retirement Projection Engine**

Your "Retirement" sheet compounds:
- Annual contributions
- Employer match
- 15% annual return assumption
- Salary growth over time

**App Feature**:
- Retirement calculator showing:
  - Current balance
  - Monthly contribution
  - Projected balance at retirement age
  - Years until retirement
- Adjustable return rates (conservative: 7%, moderate: 10%, aggressive: 15%)
- "Am I on track?" indicator

---

### **2.8 Credit Card Debt Management**

Your sheets (CHASE, CITI, DISCOVER) calculate:
- Daily interest compounding
- Payment schedule impact
- Payoff timeline

**App Feature**:
- Add multiple credit cards
- Track balances and APRs
- Calculate daily interest
- Payoff strategies:
  - Avalanche (highest interest first)
  - Snowball (smallest balance first)
- Show total interest saved by different strategies

---

### **2.9 Ratio Analysis** ⭐ FINANCIAL HEALTH DASHBOARD

Your "Ratio Percentages" sheet tracks expenses as % of income:
- Housing: 47.79% (recommended: 30%)
- Total expenses vs net income

**App Feature**:
- Financial health dashboard showing:
  - Housing ratio (with color coding: green <30%, yellow 30-35%, red >35%)
  - Debt-to-income ratio
  - Savings rate
  - Expense categories as % of take-home
- Benchmarks from financial planning best practices
- Personalized recommendations

---

## **3. User Experience Flow**

### **Onboarding (5 minutes)**

**Step 1: Tell Us About Your Income**
- Annual salary: $______
- Pay frequency: [Bi-weekly ▼]
- Do you get bonuses? [Yes/No]

**Step 2: Where Do You Live?**
- State: [Colorado ▼]
- (Auto-loads state tax rules)

**Step 3: Deductions**
- Health insurance: $____/month
- 401k contribution: ____%
- Other pre-tax deductions

**Step 4: The Big Reveal**
```
┌─────────────────────────────────┐
│  Your Gross Salary              │
│  $165,000/year                  │
│                                 │
│  After Taxes & Deductions       │
│  YOU TAKE HOME                  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  $103,247/year                  │
│  $8,604/month                   │
│  $3,918 per paycheck            │
│                                 │
│  That's 62.6% of your salary    │
└─────────────────────────────────┘
```

**Step 5: Add Your Expenses** (Optional)
- Quick start with common categories
- Or import from bank (Plaid)
- Or skip and add later

---

### **Main Dashboard**

```
┌─────────────────────────────────────────┐
│ MONTHLY VIEW               [▼]          │
│                                         │
│ 💰 Take-Home: $8,604                   │
│ 💸 Expenses:  $5,085                   │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│ 🎯 Left Over: $3,519                   │
│                                         │
│ [Annual] [Bi-Weekly] [Daily] [Hourly]  │
│                                         │
│ ┌─────────────────────────────────┐   │
│ │ Expense Breakdown               │   │
│ │ 🏠 Housing      $3,272  (38%)  │   │
│ │ 🍔 Food         $400    (5%)   │   │
│ │ 🚗 Transport    $281    (3%)   │   │
│ │ 📺 Subscr.      $173    (2%)   │   │
│ │ ⛳ Golf         $150    (2%)   │   │
│ │ ... See all                     │   │
│ └─────────────────────────────────┘   │
│                                         │
│ 🎓 Scenarios    💳 Debt    📊 Trends   │
└─────────────────────────────────────────┘
```

---

### **Scenario Planner** 🔮

```
┌─────────────────────────────────────────┐
│ WHAT IF...                              │
│                                         │
│ [+] I get a raise                       │
│ [+] I move to a new state               │
│ [+] I max out my 401k                   │
│ [+] I buy a house                       │
│ [+] I have a baby                       │
│ [+] I change jobs                       │
│ [+] Custom scenario                     │
└─────────────────────────────────────────┘
```

**Example: "I get a raise"**
```
┌─────────────────────────────────────────┐
│ NEW SALARY SCENARIO                     │
│                                         │
│ Current: $165,000                       │
│ New: $185,000 [+$20,000]               │
│                                         │
│ ┌─────────────────────────────────┐   │
│ │ CURRENT      →      NEW          │   │
│ │ $8,604/mo        $10,138/mo     │   │
│ │                   +$1,534        │   │
│ └─────────────────────────────────┘   │
│                                         │
│ ⚠️ Note: Only $1,534 more per month    │
│    (not $1,667) due to higher taxes    │
│                                         │
│ 💡 Tip: Consider increasing 401k to     │
│    reduce taxes and boost retirement    │
│                                         │
│ [Save Scenario] [Discard]              │
└─────────────────────────────────────────┘
```

---

### **Household Mode** 👫

```
┌─────────────────────────────────────────┐
│ HOUSEHOLD FINANCES                      │
│                                         │
│ Patrick: $8,604/mo (81.5%)             │
│ Jensina: $1,952/mo (18.5%)             │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│ Total: $10,556/mo                      │
│                                         │
│ SHARED EXPENSES: $4,014/mo             │
│ Patrick pays: $3,271 (81.5%)           │
│ Jensina pays: $743 (18.5%)             │
│                                         │
│ [View My Budget] [View Partner Budget] │
└─────────────────────────────────────────┘
```

---

## **4. Technical Architecture**

### **4.1 Core Calculation Engine**

All formulas from your spreadsheet translated to Swift:

```swift
struct TaxBracket {
    let floor: Decimal
    let ceiling: Decimal
    let rate: Decimal
    let baseTax: Decimal
}

struct TaxCalculator {
    func federalTax(income: Decimal, filingStatus: FilingStatus) -> Decimal {
        // VLOOKUP equivalent logic
        let bracket = findBracket(income: income, status: filingStatus)
        return bracket.baseTax + (income - bracket.floor) * bracket.rate
    }
    
    func socialSecurity(income: Decimal) -> Decimal {
        let cap: Decimal = 142_800 // 2021 wage base
        let taxableIncome = min(income, cap)
        return taxableIncome * 0.062
    }
    
    func medicare(income: Decimal) -> Decimal {
        return income * 0.0145
    }
}
```

### **4.2 Multi-Timeframe Synchronization**

```swift
struct Income {
    let annual: Decimal
    
    var monthly: Decimal { annual / 12 }
    var biWeekly: Decimal { annual / 26 }
    var weekly: Decimal { annual / 52 }
    var daily: Decimal { annual / 260 } // 52 weeks * 5 days
    var hourly: Decimal { annual / 2080 } // 52 weeks * 40 hours
}
```

### **4.3 Data Model**

```swift
struct FinancialProfile {
    // Income
    var grossSalary: Decimal
    var payFrequency: PayFrequency
    var bonuses: Decimal
    
    // Location
    var state: USState
    var filingStatus: FilingStatus
    
    // Deductions
    var preTaxDeductions: [Deduction]
    var postTaxDeductions: [Deduction]
    var retirement401k: RetirementAccount
    
    // Expenses
    var expenses: [ExpenseCategory]
    
    // Household (optional)
    var household: Household?
}

struct Household {
    var partner: FinancialProfile
    var sharedExpenses: [Expense]
    var splitMethod: SplitMethod // .proportional or .equal or .custom
}
```

### **4.4 Platform**

- **iOS 16+** (SwiftUI)
- **Local-first** (Core Data)
- **iCloud sync** (CloudKit)
- **Zero-knowledge encryption** for sensitive data
- **Offline-first**: All calculations happen on device

### **4.5 Integration Strategy**

**Phase 1: Standalone**
- No external dependencies
- Manual data entry
- CSV import/export

**Phase 2: Bank Integration**
- Plaid for transaction sync
- Auto-categorization
- Reconciliation

**Phase 3: Ecosystem**
- Monarch partnership (API if available)
- Export to other apps
- Financial advisor sharing portal

---

## **5. Unique Features Based on Your Sheet**

### **5.1 The "Patrick Special" Features**

**Time-Value Calculator**
- "Is this subscription worth it?"
- Enter: $240/year (ChatGPT)
- See: $20/month, $0.66/day, $0.08/hour of work
- "You work 3 hours per year to pay for this"

**Salary Negotiation Assistant**
- Enter offer: $180,000
- See real impact: +$1,000/month take-home
- Compare: "That's 12.5 hours of work per month more"

**The "One Year From Now" Widget**
- Based on your salary projection sheet
- Shows projected income/net worth in 1 year
- Motivational tracking

**Expense Audit Mode**
- Pull up each expense category
- "You spend $1,800/year on golf - that's 23 hours of work"
- "Keep it?" [Yes] [Reduce] [Eliminate]

---

## **6. Monetization**

### **Free Tier**
- Single income profile
- Basic tax calculator
- Manual expense tracking
- 3 scenarios
- Annual/monthly views only

### **Pro ($6.99/month or $59/year)**
- Household mode (dual income)
- All 6 timeframe views
- Unlimited scenarios
- Bank sync (Plaid)
- Retirement projections
- Salary growth modeling
- Credit card payoff planner
- Export data
- Priority support

### **Business ($14.99/month)**
- Multiple income sources
- Contractor/1099 support
- Quarterly tax estimates
- Advanced tax optimization
- Financial advisor sharing
- API access

**Revenue Projection:**
- 10K free users
- 15% conversion to Pro (1,500 users)
- 5% conversion to Business (500 users)

**MRR**: (1,500 × $6.99) + (500 × $14.99) = **$17,980/month**

---

## **7. Competitive Advantages**

| Feature | Mint | YNAB | Monarch | TakeHome |
|---------|------|------|---------|----------|
| Multi-timeframe view | ❌ | ❌ | ❌ | ✅ |
| Progressive tax calc | ❌ | ❌ | Basic | ✅ Advanced |
| Household proportional | ❌ | Manual | ❌ | ✅ Auto |
| Salary projections | ❌ | ❌ | ❌ | ✅ |
| Retirement modeling | Basic | ❌ | Basic | ✅ Advanced |
| Scenario planning | ❌ | ❌ | ❌ | ✅ |
| Time-value analysis | ❌ | ❌ | ❌ | ✅ |
| Privacy-first | ❌ | ✅ | ✅ | ✅ |
| Credit card payoff | ❌ | Manual | ❌ | ✅ |

---

## **8. Development Roadmap**

### **Phase 1: Core Calculator (12 weeks)**
**Weeks 1-4: Foundation**
- SwiftUI app architecture
- Core data models
- Tax calculation engine (all 50 states)
- Multi-timeframe calculator

**Weeks 5-8: User Experience**
- Onboarding flow
- Main dashboard
- Expense management
- Scenario planner

**Weeks 9-12: Polish**
- Household mode
- Retirement calculator
- TestFlight beta
- Bug fixes

**Deliverable**: MVP with core Patrick system features

---

### **Phase 2: Intelligence (8 weeks)**
**Weeks 13-16: Banking**
- Plaid integration
- Transaction categorization
- Auto-reconciliation
- Smart insights

**Weeks 17-20: Advanced Features**
- Salary projection models
- Credit card payoff planner
- Financial health dashboard
- Ratio analysis

**Deliverable**: Full-featured app, App Store launch

---

### **Phase 3: Scale (12 weeks)**
**Weeks 21-24: Optimization**
- Performance tuning
- Advanced tax scenarios
- State-to-state comparison
- Life event models

**Weeks 25-28: Ecosystem**
- Widget support
- Watch app
- Shortcuts integration
- CSV/Excel import/export

**Weeks 29-32: Growth**
- Referral program
- Financial advisor portal
- API for partners
- Web companion app

**Deliverable**: Platform, not just app

---

## **9. Success Metrics**

### **User Acquisition (Month 6)**
- 25K downloads
- 12% free-to-paid conversion
- 3,000 paid subscribers

### **Engagement**
- 70% weekly active users
- Average 4+ sessions per week
- 85% 30-day retention
- 60% 90-day retention

### **Revenue**
- $20K MRR by month 6
- $75K MRR by month 12
- LTV:CAC ratio of 4:1
- Churn < 5% monthly

### **Customer Satisfaction**
- "Finally understand my paycheck": >85%
- "Made better financial decision": >75%
- NPS > 60
- 4.7+ App Store rating

---

## **10. Key Risks & Mitigation**

### **Risk 1: Tax Calculation Accuracy**
- **Mitigation**: Partner with tax software provider (TaxJar)
- Annual updates for tax law changes
- Disclaimer: "Estimates only, consult tax professional"

### **Risk 2: Market Education**
- **Mitigation**: 
  - Strong content marketing
  - "Before/After" user testimonials
  - Free calculator on website drives app downloads

### **Risk 3: Plaid Integration Costs**
- **Mitigation**:
  - Start without Plaid (manual entry)
  - Add Plaid only for paid tiers
  - Alternative: Finicity (cheaper)

### **Risk 4: Competitive Response**
- **Mitigation**:
  - First-mover on multi-timeframe + household
  - Strong IP around calculation methodology
  - Community building (exclusive for users)

---

## **11. Go-to-Market Strategy**

### **Target Audience Segments**

**Primary: "Salary Optimizers"**
- Age: 28-45
- Income: $75K-$200K
- Characteristics:
  - Earn good salary but feel broke
  - Confused by tax withholding
  - Considering job offers
  - Want to buy house/start family

**Secondary: "Household Harmonizers"**
- Couples with income disparity
- Fight about money
  - Need fair expense splitting
- Want shared financial goals

**Tertiary: "Career Switchers"**
- Evaluating offers
- Considering contractor work
- Geographic arbitrage (move to lower tax state)

### **Marketing Channels**

**1. Content Marketing**
- Blog: "Why Your $100K Salary Isn't Really $100K"
- YouTube: Tax calculator walkthrough
- TikTok: Quick money facts
- Podcast sponsorships: Finance podcasts

**2. Community**
- Reddit: r/personalfinance, r/financialindependence
- Hacker News: "Show HN: I built my budget in a spreadsheet, now it's an app"
- Twitter: Financial independence community

**3. Partnerships**
- Financial advisors (referral program)
- HR departments (employee benefit)
- Salary negotiation coaches

**4. Viral Features**
- "Share your take-home %" (anonymized leaderboard)
- "See how your state compares" (state tax rankings)
- Referral program: "Invite friend, both get 1 month free Pro"

### **Launch Strategy**

**Pre-Launch (Month -2)**
- Landing page with email capture
- Free web calculator
- Build email list: 5,000+ emails

**Soft Launch (Month 0)**
- TestFlight beta: 500 users
- Product Hunt launch
- Press: TechCrunch, Lifehacker

**Public Launch (Month 1)**
- App Store featured app (submit for consideration)
- Paid ads: Facebook/Instagram to lookalike audiences
- PR push: "The app that shows your real paycheck"

---

## **12. Future Enhancements (Post-Launch)**

**AI-Powered Insights**
- "You're spending 15% more on dining than similar users"
- "Based on your spending, you could save $12K/year"
- Anomaly detection: "Unusual $500 charge in category X"

**Investment Tracking**
- Link investment accounts
- Net worth dashboard
- Asset allocation recommendations

**Bill Negotiation**
- Identify expensive services
- Auto-negotiate: "We found you $40/month cheaper internet"
- Save automatically

**Tax Filing Integration**
- Export data for TurboTax/TaxAct
- Estimated quarterly tax reminders
- Tax loss harvesting alerts

**Coaching/Consulting**
- In-app financial coach chat
- "Office hours" with CFP
- Personalized financial plans

---

## **13. Open Questions for Patrick**

1. **Household Mode Priority**: Is dual-income planning a must-have for V1 or can it be V2?

2. **Credit Card Features**: How important are the detailed credit card payoff calculators vs. simpler debt tracking?

3. **Salary Projection**: Should we pre-set growth rates or let users customize?

4. **State Coverage**: Start with top 10 states (by population) or all 50 from day 1?

5. **Data Import**: How important is importing your existing Google Sheet data vs. starting fresh?

6. **Monetization**: Comfortable with freemium model? Any concerns about paywalling features?

7. **Platform**: iOS-first only, or iOS + web companion simultaneously?

8. **Privacy**: How sensitive is financial data? Should we avoid all cloud storage?

---

## **14. Next Steps**

### **Immediate (This Week)**
1. ✅ Review this PRD
2. ⬜ Prioritize features (must-have vs nice-to-have for MVP)
3. ⬜ Decide on monetization strategy
4. ⬜ Choose dev approach (hire, build yourself, co-founder?)

### **Short-term (Weeks 1-2)**
1. ⬜ Create wireframes for key screens
2. ⬜ Technical spike: Tax calculation accuracy testing
3. ⬜ Competitive analysis: Download and evaluate Monarch, YNAB, Copilot
4. ⬜ User research: Interview 10 people about take-home confusion

### **Medium-term (Month 1)**
1. ⬜ Finalize design system
2. ⬜ Set up development environment
3. ⬜ Build calculation engine
4. ⬜ Create landing page for early interest

### **Long-term (Months 2-3)**
1. ⬜ Build MVP
2. ⬜ TestFlight beta
3. ⬜ Iterate based on feedback
4. ⬜ Prepare App Store launch

---

## **Appendix A: Key Calculations from Your Sheet**

### **Federal Tax (VLOOKUP Formula)**
```
Tax = BaseTax + (Income - BracketFloor) × MarginalRate

Example for $165K (Married Filing Jointly):
- Bracket: $89,075 - $170,050
- Base Tax: $14,605.50
- Marginal Rate: 24%
- Calculation: $14,605.50 + ($165,000 - $89,075) × 0.24
- Result: $39,066.10
```

### **Social Security**
```
If Income ≤ $142,800:
    SocialSecurity = Income × 0.062
Else:
    SocialSecurity = $142,800 × 0.062 = $8,853.60
```

### **Multi-Timeframe Conversions**
```
Annual = Base
Monthly = Annual ÷ 12
BiWeekly = Annual ÷ 26
Weekly = Annual ÷ 52
Daily = Annual ÷ 260 (52 weeks × 5 days)
Hourly = Annual ÷ 2080 (52 weeks × 40 hours)
```

### **Household Split**
```
Patrick's Share = Patrick's Net ÷ Household Net
Patrick's Shared Expense = Shared Expense × Patrick's Share

Example:
Patrick: $103,247 ÷ $125,247 = 82.4%
Rent: $3,272 × 0.824 = $2,696
```

---

## **Appendix B: Design Inspiration**

**Visual Style:**
- Clean, minimal (think: Stripe Dashboard meets Apple Health)
- Color psychology:
  - Green: Savings, positive cash flow
  - Red: Debt, overspending
  - Blue: Neutral, informational
  - Gold: Premium features

**Typography:**
- SF Pro (native iOS font)
- Big, bold numbers (Gross vs Net comparison)
- Subtle secondary text for details

**Interactions:**
- Pull-to-refresh (update calculations)
- Swipe gestures (navigate timeframes)
- Haptic feedback (scenario switches)
- Smooth animations (progressive disclosure)

**Accessibility:**
- VoiceOver support
- Dynamic Type
- Reduce Motion
- High Contrast mode

---

## **Appendix C: Marketing Copy Ideas**

**App Store Description:**

"Stop living on your gross salary. Start planning with your real take-home.

TakeHome shows you exactly how much money you'll actually receive after taxes, 401k, health insurance, and all other deductions. Then it helps you budget with what's actually left.

✨ See Your Real Paycheck
View your income across annual, monthly, biweekly, weekly, daily, and hourly—all at once.

💰 Understand Your Taxes
Progressive tax calculations for all 50 states. See exactly where your money goes.

🏠 Household Mode
Fair expense splitting for couples based on income ratios. Stop fighting about money.

🎯 Plan Your Future
Salary projections, retirement modeling, and scenario planning.

💡 Make Better Decisions
Should you take that job? Move to a different state? Max out your 401k? TakeHome shows you the real impact.

Built by someone who spent 10 years perfecting the perfect spreadsheet. Now it's an app."

**Tagline Options:**
- "Your spreadsheet. In your pocket. Smarter."
- "See your real paycheck. Plan your real life."
- "Stop guessing. Start knowing."
- "The take-home calculator you've been searching for."

---

## **Final Thoughts**

Patrick, your spreadsheet system is **exceptional**. Most budgeting apps are glorified expense trackers. You've built something far more sophisticated—a complete financial planning engine.

The multi-timeframe view alone is worth building an app around. I've never seen this anywhere else, and it's genuinely useful for:
- Salary negotiations (annual)
- Monthly budgeting
- Paycheck-to-paycheck planning
- Hourly rate awareness

The household proportional split is another massive differentiator. This solves a real relationship problem that existing apps ignore.

**My Recommendation:**
Build this. Start with the core calculator (tax engine + multi-timeframe + scenario planning) and get it in people's hands quickly. Add household mode and bank sync in subsequent updates.

There's a real market here, and you have the domain expertise to make this the definitive take-home calculator.

What do you think? Ready to turn this into an app?
