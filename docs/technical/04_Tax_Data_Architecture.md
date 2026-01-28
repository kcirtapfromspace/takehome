# TakeHome Technical Architecture: Tax Data Architecture

## Overview

This document defines the hybrid tax data system that combines embedded defaults with remote updates, ensuring the app always has valid tax data while supporting annual updates without app store releases.

---

## 1. Design Principles

1. **Offline-First**: App must work without network connectivity
2. **Always Valid**: Embedded data ensures calculations always work
3. **Updateable**: Remote config allows annual updates without app releases
4. **Versioned**: Clear versioning for tax years and data formats
5. **Fallback Safe**: Graceful degradation if remote data is corrupted

---

## 2. Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         App Launch                               │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Load Embedded Tax Data                          │
│                  (Always available)                              │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Check Cached Remote Data                        │
│         (UserDefaults or file cache)                            │
└─────────────────────────────────────────────────────────────────┘
                                │
              ┌─────────────────┴─────────────────┐
              │                                   │
              ▼                                   ▼
┌──────────────────────┐            ┌──────────────────────┐
│   Cache Valid?       │            │   Cache Expired?     │
│   Use cached data    │            │   Fetch remote       │
└──────────────────────┘            └──────────────────────┘
                                              │
                                              ▼
                                    ┌──────────────────────┐
                                    │  Validate Remote     │
                                    │  Data                │
                                    └──────────────────────┘
                                              │
                              ┌───────────────┴───────────────┐
                              │                               │
                              ▼                               ▼
                    ┌──────────────────┐          ┌──────────────────┐
                    │   Valid?         │          │   Invalid?       │
                    │   Cache & Use    │          │   Use Fallback   │
                    └──────────────────┘          └──────────────────┘
```

---

## 3. Embedded Tax Data Structure

### Bundle Location

```
TakeHome.app/
└── Resources/
    └── TaxData/
        ├── federal_2024.json
        ├── fica_2024.json
        ├── states_2024.json
        ├── retirement_2024.json
        └── manifest.json
```

### Manifest File

```json
{
  "schemaVersion": "1.0",
  "taxYear": 2024,
  "effectiveDate": "2024-01-01",
  "expirationDate": "2024-12-31",
  "files": {
    "federal": "federal_2024.json",
    "fica": "fica_2024.json",
    "states": "states_2024.json",
    "retirement": "retirement_2024.json"
  },
  "checksums": {
    "federal_2024.json": "sha256:abc123...",
    "fica_2024.json": "sha256:def456...",
    "states_2024.json": "sha256:ghi789...",
    "retirement_2024.json": "sha256:jkl012..."
  }
}
```

### Federal Tax Data (federal_2024.json)

```json
{
  "year": 2024,
  "standardDeduction": {
    "single": 14600,
    "married_filing_jointly": 29200,
    "married_filing_separately": 14600,
    "head_of_household": 21900,
    "qualifying_widower": 29200
  },
  "brackets": {
    "single": [
      {"floor": 0, "ceiling": 11600, "rate": 0.10, "baseTax": 0},
      {"floor": 11600, "ceiling": 47150, "rate": 0.12, "baseTax": 1160},
      {"floor": 47150, "ceiling": 100525, "rate": 0.22, "baseTax": 5426},
      {"floor": 100525, "ceiling": 191950, "rate": 0.24, "baseTax": 17168.50},
      {"floor": 191950, "ceiling": 243725, "rate": 0.32, "baseTax": 39110.50},
      {"floor": 243725, "ceiling": 609350, "rate": 0.35, "baseTax": 55678.50},
      {"floor": 609350, "ceiling": null, "rate": 0.37, "baseTax": 183647.25}
    ],
    "married_filing_jointly": [
      {"floor": 0, "ceiling": 23200, "rate": 0.10, "baseTax": 0},
      {"floor": 23200, "ceiling": 94300, "rate": 0.12, "baseTax": 2320},
      {"floor": 94300, "ceiling": 201050, "rate": 0.22, "baseTax": 10852},
      {"floor": 201050, "ceiling": 383900, "rate": 0.24, "baseTax": 34337},
      {"floor": 383900, "ceiling": 487450, "rate": 0.32, "baseTax": 78221},
      {"floor": 487450, "ceiling": 731200, "rate": 0.35, "baseTax": 111357},
      {"floor": 731200, "ceiling": null, "rate": 0.37, "baseTax": 196669.50}
    ],
    "married_filing_separately": [
      {"floor": 0, "ceiling": 11600, "rate": 0.10, "baseTax": 0},
      {"floor": 11600, "ceiling": 47150, "rate": 0.12, "baseTax": 1160},
      {"floor": 47150, "ceiling": 100525, "rate": 0.22, "baseTax": 5426},
      {"floor": 100525, "ceiling": 191950, "rate": 0.24, "baseTax": 17168.50},
      {"floor": 191950, "ceiling": 243725, "rate": 0.32, "baseTax": 39110.50},
      {"floor": 243725, "ceiling": 365600, "rate": 0.35, "baseTax": 55678.50},
      {"floor": 365600, "ceiling": null, "rate": 0.37, "baseTax": 98334.75}
    ],
    "head_of_household": [
      {"floor": 0, "ceiling": 16550, "rate": 0.10, "baseTax": 0},
      {"floor": 16550, "ceiling": 63100, "rate": 0.12, "baseTax": 1655},
      {"floor": 63100, "ceiling": 100500, "rate": 0.22, "baseTax": 7241},
      {"floor": 100500, "ceiling": 191950, "rate": 0.24, "baseTax": 15469},
      {"floor": 191950, "ceiling": 243700, "rate": 0.32, "baseTax": 37417},
      {"floor": 243700, "ceiling": 609350, "rate": 0.35, "baseTax": 53977},
      {"floor": 609350, "ceiling": null, "rate": 0.37, "baseTax": 181954.50}
    ]
  }
}
```

### FICA Data (fica_2024.json)

```json
{
  "year": 2024,
  "socialSecurity": {
    "rate": 0.062,
    "wageBase": 168600,
    "maxTax": 10453.20
  },
  "medicare": {
    "rate": 0.0145,
    "additionalRate": 0.009,
    "thresholds": {
      "single": 200000,
      "married_filing_jointly": 250000,
      "married_filing_separately": 125000,
      "head_of_household": 200000,
      "qualifying_widower": 250000
    }
  }
}
```

### State Tax Data (states_2024.json)

```json
{
  "year": 2024,
  "states": {
    "AL": {
      "name": "Alabama",
      "type": "progressive",
      "standardDeduction": {
        "single": 2500,
        "married_filing_jointly": 7500
      },
      "brackets": {
        "single": [
          {"floor": 0, "ceiling": 500, "rate": 0.02, "baseTax": 0},
          {"floor": 500, "ceiling": 3000, "rate": 0.04, "baseTax": 10},
          {"floor": 3000, "ceiling": null, "rate": 0.05, "baseTax": 110}
        ],
        "married_filing_jointly": [
          {"floor": 0, "ceiling": 1000, "rate": 0.02, "baseTax": 0},
          {"floor": 1000, "ceiling": 6000, "rate": 0.04, "baseTax": 20},
          {"floor": 6000, "ceiling": null, "rate": 0.05, "baseTax": 220}
        ]
      },
      "localTax": {
        "hasLocalTax": true,
        "averageRate": 0.02,
        "cities": [
          {"name": "Birmingham", "rate": 0.01}
        ]
      }
    },
    "AK": {
      "name": "Alaska",
      "type": "no_tax"
    },
    "CA": {
      "name": "California",
      "type": "progressive",
      "standardDeduction": {
        "single": 5363,
        "married_filing_jointly": 10726
      },
      "brackets": {
        "single": [
          {"floor": 0, "ceiling": 10412, "rate": 0.01, "baseTax": 0},
          {"floor": 10412, "ceiling": 24684, "rate": 0.02, "baseTax": 104.12},
          {"floor": 24684, "ceiling": 38959, "rate": 0.04, "baseTax": 389.56},
          {"floor": 38959, "ceiling": 54081, "rate": 0.06, "baseTax": 960.56},
          {"floor": 54081, "ceiling": 68350, "rate": 0.08, "baseTax": 1867.88},
          {"floor": 68350, "ceiling": 349137, "rate": 0.093, "baseTax": 3009.40},
          {"floor": 349137, "ceiling": 418961, "rate": 0.103, "baseTax": 29122.59},
          {"floor": 418961, "ceiling": 698271, "rate": 0.113, "baseTax": 36314.46},
          {"floor": 698271, "ceiling": 1000000, "rate": 0.123, "baseTax": 67876.49},
          {"floor": 1000000, "ceiling": null, "rate": 0.133, "baseTax": 104989.12}
        ]
      },
      "sdi": {
        "rate": 0.011,
        "wageBase": 153164,
        "maxTax": 1684.80
      },
      "mentalHealthTax": {
        "threshold": 1000000,
        "rate": 0.01
      }
    },
    "CO": {
      "name": "Colorado",
      "type": "flat",
      "rate": 0.044
    },
    "FL": {
      "name": "Florida",
      "type": "no_tax"
    },
    "TX": {
      "name": "Texas",
      "type": "no_tax"
    },
    "NY": {
      "name": "New York",
      "type": "progressive",
      "standardDeduction": {
        "single": 8000,
        "married_filing_jointly": 16050
      },
      "brackets": {
        "single": [
          {"floor": 0, "ceiling": 8500, "rate": 0.04, "baseTax": 0},
          {"floor": 8500, "ceiling": 11700, "rate": 0.045, "baseTax": 340},
          {"floor": 11700, "ceiling": 13900, "rate": 0.0525, "baseTax": 484},
          {"floor": 13900, "ceiling": 80650, "rate": 0.055, "baseTax": 599.50},
          {"floor": 80650, "ceiling": 215400, "rate": 0.06, "baseTax": 4270.75},
          {"floor": 215400, "ceiling": 1077550, "rate": 0.0685, "baseTax": 12355.75},
          {"floor": 1077550, "ceiling": 5000000, "rate": 0.0965, "baseTax": 71413.03},
          {"floor": 5000000, "ceiling": 25000000, "rate": 0.103, "baseTax": 449929.28},
          {"floor": 25000000, "ceiling": null, "rate": 0.109, "baseTax": 2509929.28}
        ]
      },
      "sdi": {
        "rate": 0.005,
        "maxWeekly": 0.60
      },
      "nycTax": {
        "brackets": {
          "single": [
            {"floor": 0, "ceiling": 12000, "rate": 0.03078, "baseTax": 0},
            {"floor": 12000, "ceiling": 25000, "rate": 0.03762, "baseTax": 369.36},
            {"floor": 25000, "ceiling": 50000, "rate": 0.03819, "baseTax": 858.42},
            {"floor": 50000, "ceiling": null, "rate": 0.03876, "baseTax": 1813.17}
          ]
        }
      }
    }
  }
}
```

### Retirement Limits (retirement_2024.json)

```json
{
  "year": 2024,
  "401k": {
    "employeeLimit": 23000,
    "catchUpContribution": 7500,
    "catchUpAge": 50,
    "totalLimit": 69000
  },
  "403b": {
    "employeeLimit": 23000,
    "catchUpContribution": 7500,
    "catchUpAge": 50
  },
  "457b": {
    "employeeLimit": 23000,
    "catchUpContribution": 7500,
    "catchUpAge": 50
  },
  "ira": {
    "traditionalLimit": 7000,
    "rothLimit": 7000,
    "catchUpContribution": 1000,
    "catchUpAge": 50
  },
  "rothIncomePhaseout": {
    "single": {
      "start": 146000,
      "end": 161000
    },
    "married_filing_jointly": {
      "start": 230000,
      "end": 240000
    }
  },
  "simpleIra": {
    "employeeLimit": 16000,
    "catchUpContribution": 3500
  },
  "sepIra": {
    "limit": 69000,
    "maxCompensation": 345000,
    "maxPercentage": 0.25
  },
  "hsa": {
    "individual": 4150,
    "family": 8300,
    "catchUpContribution": 1000,
    "catchUpAge": 55
  }
}
```

---

## 4. Embedded Data Loader

```swift
import Foundation

protocol EmbeddedTaxDataLoaderProtocol {
    func loadFederalData(year: Int) throws -> FederalTaxConfig
    func loadFICAData(year: Int) throws -> FICAConfig
    func loadStateData(year: Int) throws -> [String: StateTaxConfig]
    func loadRetirementData(year: Int) throws -> RetirementConfig
    func loadManifest() throws -> TaxDataManifest
}

final class EmbeddedTaxDataLoader: EmbeddedTaxDataLoaderProtocol {

    private let bundle: Bundle
    private let decoder: JSONDecoder

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func loadManifest() throws -> TaxDataManifest {
        guard let url = bundle.url(forResource: "manifest", withExtension: "json", subdirectory: "TaxData") else {
            throw TaxDataError.fileNotFound("manifest.json")
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(TaxDataManifest.self, from: data)
    }

    func loadFederalData(year: Int) throws -> FederalTaxConfig {
        let filename = "federal_\(year)"
        guard let url = bundle.url(forResource: filename, withExtension: "json", subdirectory: "TaxData") else {
            throw TaxDataError.fileNotFound("\(filename).json")
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(FederalTaxConfig.self, from: data)
    }

    func loadFICAData(year: Int) throws -> FICAConfig {
        let filename = "fica_\(year)"
        guard let url = bundle.url(forResource: filename, withExtension: "json", subdirectory: "TaxData") else {
            throw TaxDataError.fileNotFound("\(filename).json")
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(FICAConfig.self, from: data)
    }

    func loadStateData(year: Int) throws -> [String: StateTaxConfig] {
        let filename = "states_\(year)"
        guard let url = bundle.url(forResource: filename, withExtension: "json", subdirectory: "TaxData") else {
            throw TaxDataError.fileNotFound("\(filename).json")
        }
        let data = try Data(contentsOf: url)

        struct StatesWrapper: Codable {
            let year: Int
            let states: [String: StateTaxConfig]
        }

        let wrapper = try decoder.decode(StatesWrapper.self, from: data)
        return wrapper.states
    }

    func loadRetirementData(year: Int) throws -> RetirementConfig {
        let filename = "retirement_\(year)"
        guard let url = bundle.url(forResource: filename, withExtension: "json", subdirectory: "TaxData") else {
            throw TaxDataError.fileNotFound("\(filename).json")
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(RetirementConfig.self, from: data)
    }
}

// MARK: - Supporting Types

struct TaxDataManifest: Codable {
    let schemaVersion: String
    let taxYear: Int
    let effectiveDate: String
    let expirationDate: String
    let files: [String: String]
    let checksums: [String: String]
}

enum TaxDataError: Error, LocalizedError {
    case fileNotFound(String)
    case invalidData(String)
    case checksumMismatch
    case versionMismatch
    case expired

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let file):
            return "Tax data file not found: \(file)"
        case .invalidData(let reason):
            return "Invalid tax data: \(reason)"
        case .checksumMismatch:
            return "Tax data integrity check failed"
        case .versionMismatch:
            return "Tax data version incompatible"
        case .expired:
            return "Tax data has expired"
        }
    }
}
```

---

## 5. Remote Configuration Service

### API Endpoint

```
GET https://api.takehomeapp.com/v1/tax-data/{year}

Headers:
  Accept: application/json
  X-App-Version: 1.0.0
  X-Device-ID: {uuid}

Response:
{
  "version": "2024.1.2",
  "taxYear": 2024,
  "effectiveDate": "2024-01-01",
  "expirationDate": "2024-12-31",
  "federal": { ... },
  "fica": { ... },
  "states": { ... },
  "retirement": { ... }
}
```

### Remote Config Service

```swift
import Foundation
import Combine

protocol RemoteConfigServiceProtocol {
    func fetchTaxData(year: Int) -> AnyPublisher<RemoteTaxConfig, Error>
    func checkForUpdates(currentVersion: String, year: Int) -> AnyPublisher<UpdateCheckResult, Error>
}

struct UpdateCheckResult {
    let hasUpdate: Bool
    let latestVersion: String
    let isRequired: Bool
    let changeLog: String?
}

final class RemoteConfigService: RemoteConfigServiceProtocol {

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
    }

    func fetchTaxData(year: Int) -> AnyPublisher<RemoteTaxConfig, Error> {
        let url = baseURL.appendingPathComponent("tax-data/\(year)")

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(AppConfig.appVersion, forHTTPHeaderField: "X-App-Version")
        request.setValue(DeviceIdentifier.id, forHTTPHeaderField: "X-Device-ID")

        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: RemoteTaxConfig.self, decoder: decoder)
            .eraseToAnyPublisher()
    }

    func checkForUpdates(currentVersion: String, year: Int) -> AnyPublisher<UpdateCheckResult, Error> {
        let url = baseURL
            .appendingPathComponent("tax-data/\(year)/version")
            .appending(queryItems: [
                URLQueryItem(name: "current", value: currentVersion)
            ])

        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: UpdateCheckResult.self, decoder: decoder)
            .eraseToAnyPublisher()
    }
}
```

---

## 6. Cache Service

```swift
import Foundation
import Combine

protocol TaxDataCacheProtocol {
    func getCached(year: Int) -> RemoteTaxConfig?
    func cache(_ config: RemoteTaxConfig, year: Int)
    func invalidate(year: Int)
    func getCacheMetadata(year: Int) -> CacheMetadata?
}

struct CacheMetadata: Codable {
    let version: String
    let cachedAt: Date
    let expiresAt: Date
    let checksum: String
}

final class TaxDataCache: TaxDataCacheProtocol {

    private let userDefaults: UserDefaults
    private let fileManager: FileManager
    private let cacheDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private let cacheValidityDuration: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.fileManager = .default
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()

        // Cache directory in Application Support
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.cacheDirectory = appSupport.appendingPathComponent("TaxDataCache")

        // Create directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func getCached(year: Int) -> RemoteTaxConfig? {
        guard let metadata = getCacheMetadata(year: year),
              metadata.expiresAt > Date() else {
            return nil
        }

        let fileURL = cacheDirectory.appendingPathComponent("tax_data_\(year).json")

        guard let data = try? Data(contentsOf: fileURL),
              let config = try? decoder.decode(RemoteTaxConfig.self, from: data) else {
            return nil
        }

        // Verify checksum
        let checksum = data.sha256Hash
        guard checksum == metadata.checksum else {
            invalidate(year: year)
            return nil
        }

        return config
    }

    func cache(_ config: RemoteTaxConfig, year: Int) {
        guard let data = try? encoder.encode(config) else { return }

        let fileURL = cacheDirectory.appendingPathComponent("tax_data_\(year).json")
        try? data.write(to: fileURL)

        let metadata = CacheMetadata(
            version: config.version,
            cachedAt: Date(),
            expiresAt: Date().addingTimeInterval(cacheValidityDuration),
            checksum: data.sha256Hash
        )

        if let metadataData = try? encoder.encode(metadata) {
            userDefaults.set(metadataData, forKey: "tax_cache_metadata_\(year)")
        }
    }

    func invalidate(year: Int) {
        let fileURL = cacheDirectory.appendingPathComponent("tax_data_\(year).json")
        try? fileManager.removeItem(at: fileURL)
        userDefaults.removeObject(forKey: "tax_cache_metadata_\(year)")
    }

    func getCacheMetadata(year: Int) -> CacheMetadata? {
        guard let data = userDefaults.data(forKey: "tax_cache_metadata_\(year)"),
              let metadata = try? decoder.decode(CacheMetadata.self, from: data) else {
            return nil
        }
        return metadata
    }
}

// MARK: - Data Extension for Checksum

extension Data {
    var sha256Hash: String {
        // Implementation using CryptoKit
        import CryptoKit
        let hash = SHA256.hash(data: self)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
```

---

## 7. Tax Data Provider (Unified Interface)

```swift
import Foundation
import Combine

protocol TaxDataProviderProtocol {
    // Federal
    func federalBrackets(for filingStatus: FilingStatus, year: Int) -> [TaxBracket]
    func standardDeduction(for filingStatus: FilingStatus, year: Int) -> Decimal

    // State
    func stateConfig(for state: USState, year: Int) -> StateTaxConfig

    // FICA
    func ficaConfig(year: Int) -> FICAConfig

    // Retirement
    func retirementLimits(year: Int) -> RetirementConfig

    // Version info
    var currentDataVersion: String { get }
    var dataEffectiveDate: Date { get }
    var isUsingCachedData: Bool { get }

    // Refresh
    func refreshIfNeeded() -> AnyPublisher<Void, Error>
}

final class TaxDataProvider: TaxDataProviderProtocol {

    private let embeddedLoader: EmbeddedTaxDataLoaderProtocol
    private let remoteService: RemoteConfigServiceProtocol
    private let cache: TaxDataCacheProtocol

    private var activeConfig: RemoteTaxConfig?
    private var embeddedConfig: RemoteTaxConfig?

    private(set) var currentDataVersion: String = "embedded"
    private(set) var dataEffectiveDate: Date = Date()
    private(set) var isUsingCachedData: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init(
        embeddedDataLoader: EmbeddedTaxDataLoaderProtocol,
        remoteConfigService: RemoteConfigServiceProtocol,
        cacheService: TaxDataCacheProtocol
    ) {
        self.embeddedLoader = embeddedDataLoader
        self.remoteService = remoteConfigService
        self.cache = cacheService

        loadInitialData()
    }

    private func loadInitialData() {
        let currentYear = Calendar.current.component(.year, from: Date())

        // 1. Load embedded data (always available)
        do {
            let federal = try embeddedLoader.loadFederalData(year: currentYear)
            let fica = try embeddedLoader.loadFICAData(year: currentYear)
            let states = try embeddedLoader.loadStateData(year: currentYear)
            let retirement = try embeddedLoader.loadRetirementData(year: currentYear)

            embeddedConfig = RemoteTaxConfig(
                version: "embedded.\(currentYear)",
                effectiveDate: "\(currentYear)-01-01",
                expirationDate: "\(currentYear)-12-31",
                federal: federal,
                fica: fica,
                states: states,
                retirement: retirement
            )
            activeConfig = embeddedConfig
        } catch {
            fatalError("Failed to load embedded tax data: \(error)")
        }

        // 2. Check cache
        if let cached = cache.getCached(year: currentYear) {
            activeConfig = cached
            currentDataVersion = cached.version
            isUsingCachedData = true
        }

        // 3. Attempt background refresh
        refreshIfNeeded()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { }
            )
            .store(in: &cancellables)
    }

    func refreshIfNeeded() -> AnyPublisher<Void, Error> {
        let currentYear = Calendar.current.component(.year, from: Date())

        return remoteService.checkForUpdates(currentVersion: currentDataVersion, year: currentYear)
            .flatMap { [weak self] result -> AnyPublisher<Void, Error> in
                guard let self = self, result.hasUpdate else {
                    return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
                }

                return self.remoteService.fetchTaxData(year: currentYear)
                    .map { [weak self] config in
                        self?.applyRemoteConfig(config, year: currentYear)
                        return ()
                    }
                    .eraseToAnyPublisher()
            }
            .catch { [weak self] error -> AnyPublisher<Void, Error> in
                // Log error but don't fail - we have embedded data
                print("Failed to refresh tax data: \(error)")
                self?.isUsingCachedData = false  // Fall back to embedded
                return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    private func applyRemoteConfig(_ config: RemoteTaxConfig, year: Int) {
        // Validate config
        guard validateConfig(config) else {
            print("Remote config validation failed, using fallback")
            return
        }

        // Cache and apply
        cache.cache(config, year: year)
        activeConfig = config
        currentDataVersion = config.version
        isUsingCachedData = true

        if let date = ISO8601DateFormatter().date(from: config.effectiveDate) {
            dataEffectiveDate = date
        }
    }

    private func validateConfig(_ config: RemoteTaxConfig) -> Bool {
        // Basic validation
        guard !config.version.isEmpty,
              !config.federal.brackets.isEmpty,
              config.fica.socialSecurityRate > 0,
              !config.states.isEmpty else {
            return false
        }

        // Validate federal brackets have required filing statuses
        let requiredStatuses = ["single", "married_filing_jointly"]
        for status in requiredStatuses {
            guard config.federal.brackets[status] != nil else {
                return false
            }
        }

        return true
    }

    // MARK: - Data Access

    func federalBrackets(for filingStatus: FilingStatus, year: Int) -> [TaxBracket] {
        guard let config = activeConfig,
              let bracketsConfig = config.federal.brackets[filingStatus.rawValue] else {
            return []
        }

        return bracketsConfig.map { bracket in
            TaxBracket(
                floor: bracket.floor,
                ceiling: bracket.ceiling,
                rate: bracket.rate,
                baseTax: bracket.baseTax
            )
        }
    }

    func standardDeduction(for filingStatus: FilingStatus, year: Int) -> Decimal {
        guard let config = activeConfig,
              let deduction = config.federal.standardDeduction[filingStatus.rawValue] else {
            return 0
        }
        return deduction
    }

    func stateConfig(for state: USState, year: Int) -> StateTaxConfig {
        guard let config = activeConfig,
              let stateConfig = config.states[state.rawValue] else {
            // Return no-tax config as fallback
            return StateTaxConfig(
                stateCode: state.rawValue,
                stateName: state.displayName,
                taxType: .noTax,
                flatRate: nil,
                brackets: nil,
                standardDeduction: nil,
                personalExemption: nil,
                localTaxInfo: nil,
                sdiRate: nil,
                sdiWageBase: nil,
                specialRules: nil
            )
        }
        return stateConfig
    }

    func ficaConfig(year: Int) -> FICAConfig {
        return activeConfig?.fica ?? FICAConfig(
            socialSecurityRate: 0.062,
            socialSecurityWageBase: 168600,
            medicareRate: 0.0145,
            additionalMedicareRate: 0.009,
            additionalMedicareThreshold: 200000
        )
    }

    func retirementLimits(year: Int) -> RetirementConfig {
        return activeConfig?.retirement ?? RetirementConfig(
            year: year,
            limit401k: 23000,
            catchUp401k: 7500,
            catchUpAge: 50,
            limitIRA: 7000,
            catchUpIRA: 1000,
            limit403b: 23000,
            limit457: 23000
        )
    }
}
```

---

## 8. Version Checking and Update Flow

```swift
import Foundation
import Combine
import UserNotifications

final class TaxDataUpdateManager {

    private let taxDataProvider: TaxDataProviderProtocol
    private let notificationCenter: UNUserNotificationCenter

    private var cancellables = Set<AnyCancellable>()

    init(
        taxDataProvider: TaxDataProviderProtocol,
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.taxDataProvider = taxDataProvider
        self.notificationCenter = notificationCenter

        setupPeriodicCheck()
    }

    private func setupPeriodicCheck() {
        // Check for updates every 24 hours
        Timer.publish(every: 24 * 60 * 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkForUpdates()
            }
            .store(in: &cancellables)
    }

    func checkForUpdates() {
        taxDataProvider.refreshIfNeeded()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Tax data update check failed: \(error)")
                    }
                },
                receiveValue: { [weak self] in
                    self?.notifyUserIfNeeded()
                }
            )
            .store(in: &cancellables)
    }

    private func notifyUserIfNeeded() {
        // Check if we need to alert user about tax year changes
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())

        // Notify in January about new tax year data
        if currentMonth == 1 {
            scheduleNewYearNotification(year: currentYear)
        }
    }

    private func scheduleNewYearNotification(year: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Tax Data Updated"
        content.body = "TakeHome has been updated with \(year) tax rates and limits."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "tax_year_update_\(year)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request)
    }
}
```

---

## 9. Fallback Strategy

```swift
/// Fallback chain for tax data
enum TaxDataSource {
    case remote      // Latest from API
    case cached      // Previously fetched and cached
    case embedded    // Bundled with app

    var priority: Int {
        switch self {
        case .remote: return 0
        case .cached: return 1
        case .embedded: return 2
        }
    }
}

/// Fallback decision tree
func selectDataSource() -> TaxDataSource {
    // 1. Try remote if online and not recently fetched
    if NetworkMonitor.isConnected && !recentlyFetched {
        if let remote = fetchRemote() {
            return .remote
        }
    }

    // 2. Try cache if valid
    if let cached = loadFromCache(), cached.isValid {
        return .cached
    }

    // 3. Fall back to embedded (always works)
    return .embedded
}

/// Display warning when using outdated data
func showDataWarningIfNeeded() {
    guard let expirationDate = taxDataProvider.dataEffectiveDate else { return }

    let currentYear = Calendar.current.component(.year, from: Date())
    let dataYear = Calendar.current.component(.year, from: expirationDate)

    if currentYear > dataYear {
        // Show banner: "Using 2023 tax data. 2024 rates may differ."
        showOutdatedDataBanner(dataYear: dataYear, currentYear: currentYear)
    }
}
```

---

## 10. Testing Tax Data

```swift
#if DEBUG
/// Mock tax data provider for testing
final class MockTaxDataProvider: TaxDataProviderProtocol {

    var mockFederalBrackets: [FilingStatus: [TaxBracket]] = [:]
    var mockStateConfigs: [USState: StateTaxConfig] = [:]
    var mockFICAConfig: FICAConfig?

    var currentDataVersion: String = "test.1.0"
    var dataEffectiveDate: Date = Date()
    var isUsingCachedData: Bool = false

    func federalBrackets(for filingStatus: FilingStatus, year: Int) -> [TaxBracket] {
        return mockFederalBrackets[filingStatus] ?? defaultBrackets(for: filingStatus)
    }

    func stateConfig(for state: USState, year: Int) -> StateTaxConfig {
        return mockStateConfigs[state] ?? noTaxConfig(for: state)
    }

    func ficaConfig(year: Int) -> FICAConfig {
        return mockFICAConfig ?? FICAConfig(
            socialSecurityRate: 0.062,
            socialSecurityWageBase: 168600,
            medicareRate: 0.0145,
            additionalMedicareRate: 0.009,
            additionalMedicareThreshold: 200000
        )
    }

    func refreshIfNeeded() -> AnyPublisher<Void, Error> {
        Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }

    // ... helper methods
}

/// Tax calculation accuracy tests
class TaxCalculationTests: XCTestCase {

    func testFederalTaxSingle100K() {
        let calculator = FederalTaxCalculator(taxDataProvider: MockTaxDataProvider())
        let result = calculator.calculate(
            taxableIncome: 100000,
            filingStatus: .single,
            year: 2024
        )

        // Expected: $5,426 + ($100,000 - $47,150) × 22% = $17,053
        XCTAssertEqual(result.tax, 17053, accuracy: 1)
    }

    func testSocialSecurityCap() {
        let calculator = FICACalculator(taxDataProvider: MockTaxDataProvider())
        let result = calculator.calculate(grossIncome: 200000, year: 2024)

        // Should be capped at wage base
        XCTAssertEqual(result.socialSecurity, 10453.20, accuracy: 0.01)
    }

    func testCaliforniaTax() {
        // Verify against California FTB tables
        // ...
    }
}
#endif
```

---

## Summary

| Component | Purpose | Storage |
|-----------|---------|---------|
| **Embedded Data** | Always-available fallback | App bundle |
| **Remote Config** | Annual updates without app release | REST API |
| **Cache** | Offline access to remote data | File system |
| **Provider** | Unified data access interface | In-memory |

The hybrid approach ensures:
- ✅ App always works offline
- ✅ Tax data can be updated without App Store release
- ✅ Graceful fallback if remote data unavailable
- ✅ Version tracking and validation
- ✅ User notification of updates
