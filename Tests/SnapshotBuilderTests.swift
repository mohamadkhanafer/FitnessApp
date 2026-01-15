import XCTest
@testable import VitalBrief

final class SnapshotBuilderTests: XCTestCase {
    
    // MARK: - Median Tests
    
    func testMedianWithOddCount() {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let result = SnapshotBuilder.median(values)
        XCTAssertEqual(result, 3.0)
    }
    
    func testMedianWithEvenCount() {
        let values = [1.0, 2.0, 3.0, 4.0]
        let result = SnapshotBuilder.median(values)
        XCTAssertEqual(result, 2.5)
    }
    
    func testMedianWithSingleValue() {
        let values = [42.0]
        let result = SnapshotBuilder.median(values)
        XCTAssertEqual(result, 42.0)
    }
    
    func testMedianWithEmptyArray() {
        let values: [Double] = []
        let result = SnapshotBuilder.median(values)
        XCTAssertNil(result)
    }
    
    // MARK: - Baselines Tests
    
    func testBaselinesWithSufficientData() {
        let snapshots = (0..<28).map { i in
            DailySnapshot(
                id: "day-\(i)",
                date: Date(),
                sleepMinutes: 420 + Double(i * 2),
                hrvSDNNms: 45 + Double(i) / 2,
                restingHRBpm: 60 + Double(i),
                steps: 8000 + Double(i * 100),
                activeEnergyKcal: 500 + Double(i * 5),
                workoutMinutes: Double(i % 3 == 0 ? 30 : 0)
            )
        }
        
        let baselines = SnapshotBuilder.computeBaselines(from: snapshots)
        
        XCTAssertNotNil(baselines.sleepMinutesMedian28d)
        XCTAssertNotNil(baselines.hrvSDNNmsMedian28d)
        XCTAssertNotNil(baselines.restingHRBpmMedian28d)
        XCTAssertNotNil(baselines.stepsMedian28d)
        XCTAssertNotNil(baselines.activeEnergyKcalMedian28d)
    }
    
    func testBaselinesWithInsufficientData() {
        let snapshots = (0..<5).map { i in
            DailySnapshot(
                id: "day-\(i)",
                date: Date(),
                sleepMinutes: 420 + Double(i),
                hrvSDNNms: nil
            )
        }
        
        let baselines = SnapshotBuilder.computeBaselines(from: snapshots)
        
        XCTAssertNil(baselines.hrvSDNNmsMedian28d)
    }
    
    func testBaselinesWithNilValues() {
        let snapshots = [
            DailySnapshot(id: "1", date: Date(), sleepMinutes: 420),
            DailySnapshot(id: "2", date: Date(), sleepMinutes: nil),
            DailySnapshot(id: "3", date: Date(), sleepMinutes: 450),
            DailySnapshot(id: "4", date: Date(), sleepMinutes: 400),
            DailySnapshot(id: "5", date: Date(), sleepMinutes: nil),
            DailySnapshot(id: "6", date: Date(), sleepMinutes: 430),
            DailySnapshot(id: "7", date: Date(), sleepMinutes: 440),
        ]
        
        let baselines = SnapshotBuilder.computeBaselines(from: snapshots)
        
        // Should have median of non-nil values: [420, 450, 400, 430, 440] = 430
        XCTAssertEqual(baselines.sleepMinutesMedian28d, 430)
    }
    
    // MARK: - Deltas Tests
    
    func testDeltasComputation() {
        let snapshot = DailySnapshot(
            id: "today",
            date: Date(),
            sleepMinutes: 450,
            hrvSDNNms: 48,
            restingHRBpm: 55
        )
        
        let baselines = Baselines(
            sleepMinutesMedian28d: 420,
            hrvSDNNmsMedian28d: 45,
            restingHRBpmMedian28d: 58
        )
        
        let deltas = SnapshotBuilder.computeDeltas(for: snapshot, against: baselines)
        
        XCTAssertEqual(deltas.sleepMinutesDelta, 30)
        XCTAssertEqual(deltas.hrvDelta, 3)
        XCTAssertEqual(deltas.restingHRDelta, -3)
    }
    
    func testDeltasWithNilBaseline() {
        let snapshot = DailySnapshot(
            id: "today",
            date: Date(),
            sleepMinutes: 450
        )
        
        let baselines = Baselines(sleepMinutesMedian28d: nil)
        let deltas = SnapshotBuilder.computeDeltas(for: snapshot, against: baselines)
        
        XCTAssertNil(deltas.sleepMinutesDelta)
    }
    
    // MARK: - Insights Tests
    
    func testInsightsWithHighConfidence() {
        let snapshot = DailySnapshot(
            id: "today",
            date: Date(),
            sleepMinutes: 450,
            hrvSDNNms: 48,
            restingHRBpm: 55,
            steps: 10000
        )
        
        let baselines = Baselines(
            sleepMinutesMedian28d: 420,
            hrvSDNNmsMedian28d: 45,
            restingHRBpmMedian28d: 58,
            stepsMedian28d: 8000
        )
        
        let deltas = SnapshotBuilder.computeDeltas(for: snapshot, against: baselines)
        let insights = SnapshotBuilder.generateInsights(
            for: snapshot,
            deltas: deltas,
            baselines: baselines
        )
        
        XCTAssertFalse(insights.isEmpty)
        let confidences = insights.map { $0.confidence }
        XCTAssertTrue(confidences.contains(.high))
    }
    
    func testInsightsWithLowConfidence() {
        let snapshot = DailySnapshot(
            id: "today",
            date: Date(),
            sleepMinutes: nil,
            hrvSDNNms: nil,
            restingHRBpm: nil,
            steps: 5000
        )
        
        let baselines = Baselines(
            stepsMedian28d: 8000
        )
        
        let deltas = SnapshotBuilder.computeDeltas(for: snapshot, against: baselines)
        let insights = SnapshotBuilder.generateInsights(
            for: snapshot,
            deltas: deltas,
            baselines: baselines
        )
        
        let confidences = insights.map { $0.confidence }
        XCTAssertTrue(confidences.allSatisfy { $0 == .low })
    }
    
    func testNotableChangeInsight() {
        let snapshot = DailySnapshot(
            id: "today",
            date: Date(),
            sleepMinutes: 300,  // Large negative delta
            steps: 8100
        )
        
        let baselines = Baselines(
            sleepMinutesMedian28d: 420,
            stepsMedian28d: 8000
        )
        
        let deltas = SnapshotBuilder.computeDeltas(for: snapshot, against: baselines)
        let insights = SnapshotBuilder.generateInsights(
            for: snapshot,
            deltas: deltas,
            baselines: baselines
        )
        
        let notableChange = insights.first { $0.type == .notableChange }
        XCTAssertNotNil(notableChange)
    }
}
