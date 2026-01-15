import Foundation

/// Pure functions for building snapshots and computing aggregates.
enum SnapshotBuilder {
    
    /// Computes median of non-nil values. Returns nil if array is empty.
    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let count = sorted.count
        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
        } else {
            return sorted[count / 2]
        }
    }
    
    /// Computes baselines from 28 days of snapshots.
    /// If fewer than 7 data points for a metric, its baseline is nil.
    static func computeBaselines(from snapshots: [DailySnapshot]) -> Baselines {
        let threshold = 7
        
        let sleepValues = snapshots.compactMap { $0.sleepMinutes }
        let hrvValues = snapshots.compactMap { $0.hrvSDNNms }
        let restingHRValues = snapshots.compactMap { $0.restingHRBpm }
        let stepsValues = snapshots.compactMap { $0.steps }
        let energyValues = snapshots.compactMap { $0.activeEnergyKcal }
        let workoutValues = snapshots.compactMap { $0.workoutMinutes }
        
        return Baselines(
            sleepMinutesMedian28d: sleepValues.count >= threshold ? median(sleepValues) : nil,
            hrvSDNNmsMedian28d: hrvValues.count >= threshold ? median(hrvValues) : nil,
            restingHRBpmMedian28d: restingHRValues.count >= threshold ? median(restingHRValues) : nil,
            stepsMedian28d: stepsValues.count >= threshold ? median(stepsValues) : nil,
            activeEnergyKcalMedian28d: energyValues.count >= threshold ? median(energyValues) : nil,
            workoutMinutesMedian28d: workoutValues.count >= threshold ? median(workoutValues) : nil
        )
    }
    
    /// Computes deltas for a snapshot against baselines.
    static func computeDeltas(for snapshot: DailySnapshot, against baselines: Baselines) -> SnapshotDeltas {
        let sleepDelta = zip(snapshot.sleepMinutes, baselines.sleepMinutesMedian28d).map { $0 - $1 }
        let hrvDelta = zip(snapshot.hrvSDNNms, baselines.hrvSDNNmsMedian28d).map { $0 - $1 }
        let restingHRDelta = zip(snapshot.restingHRBpm, baselines.restingHRBpmMedian28d).map { $0 - $1 }
        let stepsDelta = zip(snapshot.steps, baselines.stepsMedian28d).map { $0 - $1 }
        let energyDelta = zip(snapshot.activeEnergyKcal, baselines.activeEnergyKcalMedian28d).map { $0 - $1 }
        let workoutDelta = zip(snapshot.workoutMinutes, baselines.workoutMinutesMedian28d).map { $0 - $1 }
        
        return SnapshotDeltas(
            sleepMinutesDelta: sleepDelta,
            hrvDelta: hrvDelta,
            restingHRDelta: restingHRDelta,
            stepsDelta: stepsDelta,
            activeEnergyDelta: energyDelta,
            workoutMinutesDelta: workoutDelta
        )
    }
    
    /// Generates deterministic insight cards for today.
    static func generateInsights(
        for todaySnapshot: DailySnapshot,
        deltas: SnapshotDeltas,
        baselines: Baselines
    ) -> [InsightCard] {
        var insights: [InsightCard] = []
        
        // Count available core metrics for confidence determination
        let coreMetricsPresent = [
            todaySnapshot.sleepMinutes,
            todaySnapshot.hrvSDNNms,
            todaySnapshot.restingHRBpm
        ].compactMap { $0 }.count
        
        let confidence: InsightCard.Confidence = {
            if coreMetricsPresent >= 3 { return .high }
            else if coreMetricsPresent >= 2 { return .medium }
            else { return .low }
        }()
        
        // Insight 1: Recovery signals
        if let sleepDelta = deltas.sleepMinutesDelta,
           let hrvDelta = deltas.hrvDelta,
           let restingDelta = deltas.restingHRDelta,
           let sleepBaseline = baselines.sleepMinutesMedian28d,
           let hrvBaseline = baselines.hrvSDNNmsMedian28d,
           let restingBaseline = baselines.restingHRBpmMedian28d {
            
            var signals: [String] = []
            if sleepDelta > 30 { signals.append("improved sleep") }
            if hrvDelta > 2 { signals.append("elevated HRV") }
            if restingDelta < -3 { signals.append("lower resting HR") }
            
            if !signals.isEmpty {
                let joinedSignals = signals.joined(separator: ", ")
                let explanation = "Today shows positive recovery markers: \(joinedSignals) vs. your 28-day baseline."
                insights.append(InsightCard(
                    type: .recoverySignals,
                    title: "Recovery Signals",
                    explanation: explanation,
                    confidence: confidence
                ))
            }
        }
        
        // Insight 2: Activity/load
        if let stepsDelta = deltas.stepsDelta,
           let energyDelta = deltas.activeEnergyDelta,
           let stepsBaseline = baselines.stepsMedian28d,
           let energyBaseline = baselines.activeEnergyKcalMedian28d {
            
            var activityMarks: [String] = []
            if stepsDelta > 2000 { activityMarks.append("higher step count") }
            if energyDelta > 100 { activityMarks.append("more energy burn") }
            if stepsDelta < -2000 { activityMarks.append("lower step count") }
            if energyDelta < -100 { activityMarks.append("less energy burn") }
            
            if !activityMarks.isEmpty {
                let joinedMarks = activityMarks.joined(separator: ", ")
                let explanation = "Your activity today shows \(joinedMarks) compared to baseline."
                insights.append(InsightCard(
                    type: .activityLoad,
                    title: "Activity & Load",
                    explanation: explanation,
                    confidence: confidence
                ))
            }
        }
        
        // Insight 3: Notable change (largest absolute delta)
        let allDeltas: [(name: String, value: Double)] = [
            ("sleep", deltas.sleepMinutesDelta),
            ("HRV", deltas.hrvDelta),
            ("resting HR", deltas.restingHRDelta),
            ("steps", deltas.stepsDelta),
            ("energy", deltas.activeEnergyDelta),
            ("workouts", deltas.workoutMinutesDelta)
        ].compactMap { name, value in
            value.map { (name, abs($0)) }
        }
        
        if let largest = allDeltas.max(by: { $0.value < $1.value }) {
            let direction = (allDeltas.first { $0.name == largest.name }?.value ?? 0) >= 0 ? "higher" : "lower"
            let explanation = "Your \(largest.name) is noticeably \(direction) today vs. your recent average."
            insights.append(InsightCard(
                type: .notableChange,
                title: "Notable Change",
                explanation: explanation,
                confidence: confidence
            ))
        }
        
        return Array(insights.prefix(3))
    }
}

// Helper extension for optional zip
extension Optional {
    fileprivate func zip<T>(_ other: Optional<T>) -> Optional<(Wrapped, T)> {
        guard let self = self, let other = other else { return nil }
        return (self, other)
    }
}
