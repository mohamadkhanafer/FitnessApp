import SwiftUI

struct TodayView: View {
    @ObservedObject var todayVM: TodayViewModel
    @ObservedObject var appState: AppStateViewModel
    
    var body: some View {
        NavigationStack {
            if todayVM.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let snapshot = todayVM.todaySnapshot {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Freshness indicator
                        if let syncDate = appState.lastSyncDate {
                            Text("Updated: \(DateHelper.timeAgoString(from: syncDate))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Key metrics
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Today's Metrics")
                                .font(.headline)
                            
                            MetricRowView(
                                label: "Sleep",
                                value: formatSleep(snapshot.sleepMinutes),
                                unit: "",
                                delta: formatDelta(todayVM.deltas?.sleepMinutesDelta),
                                deltaColor: NumberFormatter.deltaColor(todayVM.deltas?.sleepMinutesDelta)
                            )
                            
                            MetricRowView(
                                label: "HRV (SDNN)",
                                value: NumberFormatter.format(snapshot.hrvSDNNms, decimals: 1),
                                unit: "ms",
                                delta: formatDelta(todayVM.deltas?.hrvDelta, decimals: 1),
                                deltaColor: NumberFormatter.deltaColor(todayVM.deltas?.hrvDelta)
                            )
                            
                            MetricRowView(
                                label: "Resting HR",
                                value: NumberFormatter.format(snapshot.restingHRBpm),
                                unit: "bpm",
                                delta: formatDelta(todayVM.deltas?.restingHRDelta),
                                deltaColor: NumberFormatter.deltaColor(todayVM.deltas?.restingHRDelta)
                            )
                            
                            MetricRowView(
                                label: "Steps",
                                value: NumberFormatter.format(snapshot.steps),
                                unit: "steps",
                                delta: formatDelta(todayVM.deltas?.stepsDelta),
                                deltaColor: NumberFormatter.deltaColor(todayVM.deltas?.stepsDelta)
                            )
                            
                            MetricRowView(
                                label: "Active Energy",
                                value: NumberFormatter.format(snapshot.activeEnergyKcal),
                                unit: "kcal",
                                delta: formatDelta(todayVM.deltas?.activeEnergyDelta),
                                deltaColor: NumberFormatter.deltaColor(todayVM.deltas?.activeEnergyDelta)
                            )
                            
                            if let workoutMinutes = snapshot.workoutMinutes, snapshot.workoutCount > 0 {
                                MetricRowView(
                                    label: "Workouts",
                                    value: "\(snapshot.workoutCount)",
                                    unit: "(\(Int(workoutMinutes))m)",
                                    delta: formatDelta(todayVM.deltas?.workoutMinutesDelta),
                                    deltaColor: NumberFormatter.deltaColor(todayVM.deltas?.workoutMinutesDelta)
                                )
                            }
                        }
                        
                        // Insights
                        if !todayVM.insights.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Insights")
                                    .font(.headline)
                                
                                ForEach(todayVM.insights) { insight in
                                    InsightCardView(insight: insight)
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Insights")
                                    .font(.headline)
                                
                                Text("Not enough data to generate insights yet. Come back as you collect more data.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Today")
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No Data Available")
                        .font(.headline)
                    
                    Text("Open Apple Health and record some data, then refresh.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Today")
            }
        }
        .onAppear {
            todayVM.loadTodayData()
        }
    }
    
    private func formatSleep(_ minutes: Double?) -> String {
        guard let minutes = minutes else { return "—" }
        let hours = Int(minutes / 60)
        let mins = Int(minutes.truncatingRemainder(dividingBy: 60))
        return "\(hours)h \(mins)m"
    }
    
    private func formatDelta(_ delta: Double?, decimals: Int = 0) -> String? {
        NumberFormatter.formatDelta(delta, decimals: decimals)
    }
}

#Preview {
    TodayView(
        todayVM: {
            let vm = TodayViewModel(
                persistenceManager: try! PersistenceManager(),
                healthKitService: HealthKitService()
            )
            // Set preview data
            vm.todaySnapshot = MockData.sampleSnapshot
            vm.baselines = Baselines(
                sleepMinutesMedian28d: 420,
                hrvSDNNmsMedian28d: 45,
                restingHRBpmMedian28d: 58,
                stepsMedian28d: 8000,
                activeEnergyKcalMedian28d: 500
            )
            vm.deltas = SnapshotDeltas(
                sleepMinutesDelta: 30,
                hrvDelta: 2,
                restingHRDelta: -1,
                stepsDelta: 234,
                activeEnergyDelta: 42
            )
            vm.insights = [
                InsightCard(
                    type: .recoverySignals,
                    title: "Recovery Signals",
                    explanation: "Today shows positive recovery markers.",
                    confidence: .high
                )
            ]
            return vm
        }(),
        appState: AppStateViewModel(
            healthKitService: HealthKitService(),
            persistenceManager: try! PersistenceManager()
        )
    )
}
