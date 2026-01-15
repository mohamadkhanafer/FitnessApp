import Foundation

/// Represents the source of a metric within a daily snapshot.
struct SnapshotSources: Codable, Equatable {
    var sleepSource: String?
    var hrvSource: String?
    var restingHRSource: String?
    var stepsSource: String?
    var activeEnergySource: String?
    var workoutSource: String?
    
    init(
        sleepSource: String? = nil,
        hrvSource: String? = nil,
        restingHRSource: String? = nil,
        stepsSource: String? = nil,
        activeEnergySource: String? = nil,
        workoutSource: String? = nil
    ) {
        self.sleepSource = sleepSource
        self.hrvSource = hrvSource
        self.restingHRSource = restingHRSource
        self.stepsSource = stepsSource
        self.activeEnergySource = activeEnergySource
        self.workoutSource = workoutSource
    }
}

/// Canonical domain model representing one day of health data.
struct DailySnapshot: Identifiable, Codable, Equatable {
    /// Unique identifier in yyyy-MM-dd format
    let id: String
    /// Start of day in user's local timezone
    let date: Date
    /// Total minutes asleep (from sleepAnalysis category, "asleep" value preferred)
    let sleepMinutes: Double?
    /// Heart Rate Variability SDNN in milliseconds (daily median if multiple samples; prefer sleep window)
    let hrvSDNNms: Double?
    /// Resting heart rate in bpm (daily average or median of restingHeartRate samples)
    let restingHRBpm: Double?
    /// Daily total step count
    let steps: Double?
    /// Daily total active energy in kilocalories
    let activeEnergyKcal: Double?
    /// Total workout duration in minutes for that day
    let workoutMinutes: Double?
    /// Number of workouts for that day
    let workoutCount: Int
    /// Source identifiers for each metric
    let sources: SnapshotSources
    
    init(
        id: String,
        date: Date,
        sleepMinutes: Double? = nil,
        hrvSDNNms: Double? = nil,
        restingHRBpm: Double? = nil,
        steps: Double? = nil,
        activeEnergyKcal: Double? = nil,
        workoutMinutes: Double? = nil,
        workoutCount: Int = 0,
        sources: SnapshotSources = SnapshotSources()
    ) {
        self.id = id
        self.date = date
        self.sleepMinutes = sleepMinutes
        self.hrvSDNNms = hrvSDNNms
        self.restingHRBpm = restingHRBpm
        self.steps = steps
        self.activeEnergyKcal = activeEnergyKcal
        self.workoutMinutes = workoutMinutes
        self.workoutCount = workoutCount
        self.sources = sources
    }
}

/// Represents baseline (median) values across 28 days.
struct Baselines: Codable, Equatable {
    let sleepMinutesMedian28d: Double?
    let hrvSDNNmsMedian28d: Double?
    let restingHRBpmMedian28d: Double?
    let stepsMedian28d: Double?
    let activeEnergyKcalMedian28d: Double?
    let workoutMinutesMedian28d: Double?
    
    init(
        sleepMinutesMedian28d: Double? = nil,
        hrvSDNNmsMedian28d: Double? = nil,
        restingHRBpmMedian28d: Double? = nil,
        stepsMedian28d: Double? = nil,
        activeEnergyKcalMedian28d: Double? = nil,
        workoutMinutesMedian28d: Double? = nil
    ) {
        self.sleepMinutesMedian28d = sleepMinutesMedian28d
        self.hrvSDNNmsMedian28d = hrvSDNNmsMedian28d
        self.restingHRBpmMedian28d = restingHRBpmMedian28d
        self.stepsMedian28d = stepsMedian28d
        self.activeEnergyKcalMedian28d = activeEnergyKcalMedian28d
        self.workoutMinutesMedian28d = workoutMinutesMedian28d
    }
}

/// Deltas represent the difference between today's value and the baseline.
struct SnapshotDeltas: Codable, Equatable {
    let sleepMinutesDelta: Double?      // snapshot value - median
    let hrvDelta: Double?               // snapshot value - median
    let restingHRDelta: Double?         // snapshot value - median
    let stepsDelta: Double?             // snapshot value - median
    let activeEnergyDelta: Double?      // snapshot value - median
    let workoutMinutesDelta: Double?    // snapshot value - median
    
    init(
        sleepMinutesDelta: Double? = nil,
        hrvDelta: Double? = nil,
        restingHRDelta: Double? = nil,
        stepsDelta: Double? = nil,
        activeEnergyDelta: Double? = nil,
        workoutMinutesDelta: Double? = nil
    ) {
        self.sleepMinutesDelta = sleepMinutesDelta
        self.hrvDelta = hrvDelta
        self.restingHRDelta = restingHRDelta
        self.stepsDelta = stepsDelta
        self.activeEnergyDelta = activeEnergyDelta
        self.workoutMinutesDelta = workoutMinutesDelta
    }
}

/// A snapshot paired with its calculated deltas relative to baselines.
struct DailySnapshotWithDeltas: Identifiable {
    let id: String { snapshot.id }
    let snapshot: DailySnapshot
    let deltas: SnapshotDeltas
}

/// Deterministic insight card for today.
struct InsightCard: Identifiable {
    enum InsightType {
        case recoverySignals
        case activityLoad
        case notableChange
    }
    
    enum Confidence: String {
        case high = "High"
        case medium = "Medium"
        case low = "Low"
    }
    
    let id: String = UUID().uuidString
    let type: InsightType
    let title: String
    let explanation: String
    let confidence: Confidence
}
