# VitalBrief Copilot Instructions

**Project**: iOS health insights app reading Apple HealthKit data for observational analytics.

## Architecture Overview

VitalBrief uses **MVVM + Service Layer** (no logic in Views):
- **Domain/**: Pure models (`DailySnapshot`, `Baselines`, `SnapshotDeltas`, `InsightCard`) + `SnapshotBuilder` (deterministic aggregation logic)
- **Services/**: `HealthKitService` (async read-only HK queries) + `PersistenceManager` (local JSON cache)
- **ViewModels/**: `AppStateViewModel` (auth + sync), `TodayViewModel` (today metrics + insights), `TrendsViewModel` (28-day history)
- **Views/**: `ConnectView`, `TodayView`, `TrendsView`, `SettingsView` + components (`MetricRowView`, `InsightCardView`)
- **Utils/**: `DateHelper`, `NumberFormatter`, `MockData` for previews

## Critical Patterns

### Data Aggregation (SnapshotBuilder)
- **Sleep**: Sum "asleep" minutes (ignore "in bed"); handle midnight boundaries by calendar day
- **HRV**: Daily median of SDNN samples (prefer sleep window), output in milliseconds
- **Resting HR**: Daily average of resting HR samples
- **Steps/Energy**: Use `HKStatisticsQuery` with `.cumulativeSum` per day
- **Workouts**: Sum duration + count workouts by startDate within daily boundary
- **Baselines**: Compute 28-day medians; nil if <7 data points for that metric
- **Deltas**: `snapshot_value - baseline_value`; nil if baseline is nil

### Insights (Deterministic)
Three insight types generated for today:
1. **Recovery signals**: HRV + RHR + sleep deltas vs. baseline (only if all three present)
2. **Activity/load**: steps + energy vs. baseline
3. **Notable change**: largest absolute delta across all metrics

Confidence = High (3+ core metrics), Medium (2), Low (1).

### HealthKit Permissions (MVP)
Read-only access to: `sleepAnalysis`, `heartRateVariabilitySDNN`, `restingHeartRate`, `stepCount`, `activeEnergyBurned`, `workoutType`. No ECG/AFib or write permissions.

### Persistence
- Local cache in `ApplicationSupport/VitalBrief/snapshots.json` (28-day history)
- Last sync timestamp in `syncDate.json`
- `PersistenceManager` is an `actor` (thread-safe)

## Workflows

### Startup Flow
1. `VitalBriefApp` initializes services → checks `lastSyncDate`
2. If not authorized: show `ConnectView`
3. If authorized: load cached snapshots → show `MainTabView` (tabs: Today, Trends, Settings)

### Refresh Flow
Settings → "Refresh from Apple Health" → `AppStateViewModel.refreshData()` → fetch 28 days → cache → reload ViewModels

### Testing
- Unit tests in `Tests/SnapshotBuilderTests.swift`
- Test median, baselines with <7 data points, deltas, insight confidence
- Use `MockData.sampleSnapshots()` for UI previews (no HK required)

## Non-Goals (Don't Implement)
- No vendor APIs (Garmin, Polar, etc.)
- No AI/LLM or training recommendations
- No cloud sync, login, ads, analytics
- No background notifications or writing to HealthKit
- No chat or prescription logic

## Key Files to Understand
- `Domain/SnapshotBuilder.swift`: Core aggregation + insight logic (pure functions)
- `Services/HealthKitService.swift`: All HK queries (actor-based, async/await)
- `ViewModels/TodayViewModel.swift`: Snapshot + baseline + delta + insight orchestration
- `Views/TodayView.swift`: Main metrics display + insight cards
- `Utils/Formatters.swift`: Number/date formatting + mock data

## Common Tasks
- **Add a new health metric**: Add to `DailySnapshot` → update `HealthKitService.fetchSnapshot()` → add to `SnapshotBuilder.computeBaselines/Deltas()` → add UI row in `TodayView`
- **Update insight logic**: Modify `SnapshotBuilder.generateInsights()`; test in `SnapshotBuilderTests`
- **Change baseline threshold**: Edit `threshold = 7` in `SnapshotBuilder.computeBaselines()`
- **Adjust HK query date range**: Change `lastDays: Int` parameter in `HealthKitService.fetchSnapshots()`

## Assumptions & Limitations
- Daily boundary = `Calendar.current.startOfDay()` (user's local timezone)
- Sleep overlapping midnight: simple time slicing by calendar day
- HRV prefers sleep window; falls back to daily median
- Baseline nil + deltas nil if <7 data points (prevents spurious patterns)
- No real-time sync (manual "Refresh" button in Settings)
- Mock data in previews uses deterministic variation ±10% around mean
