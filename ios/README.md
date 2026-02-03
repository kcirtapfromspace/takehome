# TakeHome iOS App

iOS financial planning app built with SwiftUI and a Rust calculation engine.

## Prerequisites

- Xcode 15.0+
- iOS 16.0+ deployment target
- Rust (with iOS targets installed)
- XcodeGen (for project generation)

## Setup

### 1. Build Rust Core Library

```bash
cd ../core

# Install iOS targets (if not already installed)
rustup target add aarch64-apple-ios aarch64-apple-ios-sim

# Build for iOS
make ios

# Generate Swift bindings
make bindings-swift

# Create XCFramework
make xcframework
```

### 2. Generate Xcode Project

Using XcodeGen (recommended):

```bash
# Install XcodeGen if needed
brew install xcodegen

# Generate the project
cd ios
xcodegen generate
```

### 3. Open and Build

```bash
open TakeHome.xcodeproj
```

Or build from command line:

```bash
xcodebuild -scheme TakeHome -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Project Structure

```
ios/
├── TakeHome/
│   ├── App/                    # App entry point
│   │   ├── TakeHomeApp.swift
│   │   └── DependencyContainer.swift
│   ├── Core/                   # FFI wrapper
│   │   ├── TakeHomeCoreWrapper.swift
│   │   ├── DecimalConversions.swift
│   │   ├── takehome_core.swift     # Generated
│   │   └── takehome_coreFFI.h      # Generated
│   ├── Models/                 # Domain models
│   ├── ViewModels/             # MVVM ViewModels
│   ├── Views/                  # SwiftUI views
│   ├── Repositories/           # Data repositories
│   └── Resources/              # Assets, Info.plist
├── TakeHomeTests/              # Unit tests
│   ├── Core/
│   ├── ViewModels/
│   └── Mocks/
├── TakeHomeUITests/            # UI tests
└── project.yml                 # XcodeGen configuration
```

## Architecture

- **MVVM Pattern**: ViewModels contain business logic, Views are purely declarative
- **Dependency Injection**: `DependencyContainer` provides all dependencies
- **Protocol-based**: Core services use protocols for testability
- **Rust FFI**: Tax calculations powered by embedded Rust library

## Testing

Run unit tests:

```bash
xcodebuild test \
  -scheme TakeHome \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Run UI tests:

```bash
xcodebuild test \
  -scheme TakeHome \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:TakeHomeUITests
```

## Key Features

1. **Multi-Timeframe Income View**: See take-home pay as annual, monthly, bi-weekly, weekly, daily, hourly
2. **Tax Breakdown**: Federal, state, FICA taxes with effective rates
3. **Expense Tracking**: 9 categories with frequency conversion
4. **Scenario Planner**: What-if comparisons for raises, state moves, retirement contributions
5. **Household Mode**: Proportional expense splitting for couples

## License

MIT
