# VitalBrief

An iOS app that reads Apple HealthKit data and provides observational health insights—no training plans, no prescriptions, just data interpretation.

## Project Overview

**MVP Features:**
- ✅ Read-only access to Apple HealthKit (sleep, HRV, resting HR, steps, active energy, workouts)
- ✅ Display today's metrics + 28-day trends with baselines and deltas
- ✅ Generate deterministic insight cards (recovery, activity load, notable changes)
- ✅ Local caching (no cloud sync)
- ✅ Full UI preview support with mock data

**Non-Goals:**
- ❌ AI/LLM recommendations
- ❌ Vendor integrations (Garmin, Polar, etc.)
- ❌ Cloud sync, login, notifications
- ❌ Writing to HealthKit
- ❌ Ads, analytics, chat

## Requirements

- **iOS 17+** (Swift 5.9+)
- **Xcode 15+**
- **Mac with Apple Silicon or Intel** (simulator compatible)

## Building & Running

### Prerequisites
```bash
# Ensure you have Xcode 15+ installed
xcode-select --install
```

### Build & Run
```bash
# Clone or navigate to the project
cd /Users/satoshinakamoto/FitnessApp

# Open in Xcode
open . -a Xcode

# Or build from CLI
xcodebuild build -scheme VitalBrief -destination "platform=iOS Simulator,name=iPhone 15"
```

### Run Tests
```bash
xcodebuild test -scheme VitalBrief -destination "platform=iOS Simulator,name=iPhone 15"
```

## Architecture

```
Domain/
  ├─ Models.swift          → DailySnapshot, Baselines, Deltas, InsightCard
  └─ SnapshotBuilder.swift → Pure aggregation & insight logic

Services/
  ├─ HealthKitService.swift    → Async read-only HK queries (actor)
  └─ PersistenceManager.swift  → Local JSON cache (actor)

ViewModels/
  ├─ AppStateViewModel.swift  → Auth + sync orchestration
  ├─ TodayViewModel.swift     → Today metrics + insights
  └─ TrendsViewModel.swift    → 28-day history

Views/
  ├─ ConnectView.swift        → HealthKit permission request
  ├─ TodayView.swift          → Today's metrics + insight cards
  ├─ TrendsView.swift         → 28-day history list + detail modal
  ├─ SettingsView.swift       → Auth status + refresh button
  └─ Components.swift         → MetricRowView, InsightCardView

Utils/
  └─ Formatters.swift → Date/number formatting + MockData

Tests/
  └─ SnapshotBuilderTests.swift → Unit tests (median, baselines, deltas, insights)

VitalBriefApp.swift → Main entry point (MVVM setup)
```

## Key Workflows

### Startup
1. App initializes `HealthKitService`, `PersistenceManager`, ViewModels
2. Checks if authorized; if not, shows `ConnectView`
3. On authorization, fetches 28 days of data and caches it

### Daily Update
- Users tap "Refresh" in Settings → fetches latest 28 days → caches → reloads tabs

### UI Layers
- **Today Tab**: Key metrics (sleep, HRV, RHR, steps, energy, workouts) with deltas vs. 28-day median + 3 insight cards
- **Trends Tab**: Compact rows for last 28 days; tap to view detailed day
- **Settings Tab**: HealthKit auth status + data freshness + refresh button + about section

## Data Model

### DailySnapshot
```swift
struct DailySnapshot: Identifiable, Codable, Equatable {
  id: String               // yyyy-MM-dd
  date: Date               // start-of-day in user's timezone
  sleepMinutes: Double?    // total asleep
  hrvSDNNms: Double?       // ms (daily median)
  restingHRBpm: Double?    // bpm (daily average)
  steps: Double?           // daily total
  activeEnergyKcal: Double?// daily total
  workoutMinutes: Double?  // total duration
  workoutCount: Int        // number of workouts
  sources: SnapshotSources // metric provenance (bundle IDs)
}
```

### Baselines (28-day medians)
If ≥7 data points exist for a metric, baseline = median; else nil.

### SnapshotDeltas
For today: `snapshot_value - baseline_value` for each metric.

### InsightCard
```swift
struct InsightCard: Identifiable {
  title: String           // "Recovery Signals", "Activity & Load", "Notable Change"
  explanation: String     // 1-2 sentences with metric names + deltas
  confidence: Confidence  // High (3+ core metrics), Medium (2), Low (1)
}
```

## Aggregation Rules (MVP, Deterministic)

| Metric | Logic |
|--------|-------|
| **Sleep** | Sum "asleep" minutes (exclude "in bed"); handle midnight by calendar day |
| **HRV** | Daily median of SDNN samples; prefer sleep window if available |
| **Resting HR** | Daily average (or median) of resting HR samples |
| **Steps** | `HKStatisticsQuery(.cumulativeSum)` per day |
| **Active Energy** | `HKStatisticsQuery(.cumulativeSum)` per day |
| **Workouts** | Sum duration + count by startDate within daily boundary |
| **Baseline** | 28-day median of non-nil values; nil if <7 data points |
| **Deltas** | snapshot – baseline; nil if baseline is nil |

## HealthKit Permissions

**Read-Only Access:**
- `HKCategoryTypeIdentifier.sleepAnalysis`
- `HKQuantityTypeIdentifier.heartRateVariabilitySDNN`
- `HKQuantityTypeIdentifier.restingHeartRate`
- `HKQuantityTypeIdentifier.stepCount`
- `HKQuantityTypeIdentifier.activeEnergyBurned`
- `HKObjectType.workoutType()`

**No Restricted Types:** ECG, AFib, etc.

## Configuration

### Info.plist
```xml
<key>NSHealthShareUsageDescription</key>
<string>VitalBrief reads your Apple Health data to summarize trends and provide insights.</string>
```

## Testing

### Unit Tests
Located in `Tests/SnapshotBuilderTests.swift`:
- ✅ Median calculation (odd, even, single, empty arrays)
- ✅ Baselines: sufficient data, insufficient data, nil filtering
- ✅ Deltas computation with nil handling
- ✅ Insight confidence levels (high, medium, low)
- ✅ Notable change detection

### UI Previews
All views support `#Preview` blocks with `MockData.sampleSnapshots()`:
```swift
// Automatic variation: ±10% around mean for each day
let mockSnapshots = MockData.sampleSnapshots(count: 28)
```

## Code Style & Practices

- **MVVM**: No logic in Views; business logic in ViewModels and Services
- **Async/Await**: `HealthKitService` and `PersistenceManager` are actors
- **Pure Functions**: `SnapshotBuilder` functions are deterministic, testable
- **Error Handling**: Typed `HealthKitError` and `PersistenceError` enums
- **Date Handling**: Always use `Calendar.current.startOfDay()` for daily boundaries
- **Formatting**: Centralized in `Utils/Formatters.swift`

## Common Tasks

### Add a New Health Metric
1. Add field to `DailySnapshot`
2. Add fetch function in `HealthKitService.fetchSnapshot()`
3. Update `SnapshotBuilder.computeBaselines()` and `computeDeltas()`
4. Add UI row in `TodayView` and `TrendsView`
5. Update tests

### Update Insight Logic
1. Modify `SnapshotBuilder.generateInsights()`
2. Add test case in `SnapshotBuilderTests`
3. Verify in preview

### Adjust Baseline Threshold
- Edit `threshold = 7` in `SnapshotBuilder.computeBaselines()`
- Re-run tests to verify nil behavior

## Assumptions & Limitations

- **Daily Boundary**: `Calendar.current.startOfDay(for: Date())` (user's local timezone)
- **Sleep Overlapping Midnight**: Simple time slicing by calendar day (no carry-over)
- **HRV Selection**: Prefer samples during sleep window; fall back to daily median
- **Baseline Stability**: <7 data points → baseline is nil, deltas are nil
- **No Real-Time Sync**: Manual "Refresh" button only
- **Read-Only**: App never writes to HealthKit
- **Local Cache Only**: No cloud sync; cache expires only on manual clear

## Future Roadmap (Out of MVP Scope)

- Cloud sync with HealthKit data
- Vendor API integrations (Garmin, Oura, Polar)
- AI-powered recommendations
- Push notifications for anomalies
- Custom baselines (e.g., "last 7 days" vs. 28-day)
- Export data to CSV/PDF
- Wearable complications (watchOS)

## License

MIT (placeholder)

## Support

For issues or feature requests, contact the development team.
