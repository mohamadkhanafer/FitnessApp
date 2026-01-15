import SwiftUI

struct TrendsView: View {
    @ObservedObject var trendsVM: TrendsViewModel
    @State private var selectedSnapshot: DailySnapshotWithDeltas?
    
    var body: some View {
        NavigationStack {
            if trendsVM.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !trendsVM.snapshotsWithDeltas.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("28-Day Trends")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(trendsVM.snapshotsWithDeltas) { item in
                            TrendRowView(snapshot: item.snapshot, deltas: item.deltas)
                                .onTapGesture {
                                    selectedSnapshot = item
                                }
                        }
                    }
                    .padding(.vertical)
                }
                .navigationTitle("Trends")
                .sheet(item: $selectedSnapshot) { item in
                    TrendDetailView(snapshot: item.snapshot, deltas: item.deltas)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "calendar")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No Trends Yet")
                        .font(.headline)
                    
                    Text("Data will appear here as you sync Apple Health information.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Trends")
            }
        }
        .onAppear {
            trendsVM.loadTrendsData()
        }
    }
}

struct TrendRowView: View {
    let snapshot: DailySnapshot
    let deltas: SnapshotDeltas
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(DateHelper.dayString(from: snapshot.date))
                    .font(.headline)
                
                Spacer()
                
                // Summary metrics
                HStack(spacing: 12) {
                    if let sleep = snapshot.sleepMinutes {
                        Label("\(Int(sleep / 60))h", systemImage: "moon.zzz")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    if let steps = snapshot.steps {
                        Label("\(Int(steps / 1000))k", systemImage: "figure.walk")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            HStack(spacing: 16) {
                // Metrics with delta indicators
                if let hrv = snapshot.hrvSDNNms, let delta = deltas.hrvDelta {
                    DeltaIndicator(
                        label: "HRV",
                        value: Int(hrv),
                        delta: Int(delta)
                    )
                }
                
                if let rhr = snapshot.restingHRBpm, let delta = deltas.restingHRDelta {
                    DeltaIndicator(
                        label: "RHR",
                        value: Int(rhr),
                        delta: Int(delta)
                    )
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct DeltaIndicator: View {
    let label: String
    let value: Int
    let delta: Int
    
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("\(value)")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            HStack(spacing: 2) {
                Image(systemName: delta >= 0 ? "arrow.up" : "arrow.down")
                    .font(.caption2)
                Text("\(abs(delta))")
                    .font(.caption2)
            }
            .foregroundColor(delta >= 0 ? .green : .red)
        }
    }
}

struct TrendDetailView: View {
    @Environment(\.dismiss) var dismiss
    let snapshot: DailySnapshot
    let deltas: SnapshotDeltas
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(DateHelper.fullDateString(from: snapshot.date))
                            .font(.headline)
                        Spacer()
                        Button("Done") { dismiss() }
                    }
                    .padding()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        if let sleep = snapshot.sleepMinutes {
                            MetricRowView(
                                label: "Sleep",
                                value: "\(Int(sleep / 60))h \(Int(sleep.truncatingRemainder(dividingBy: 60)))m",
                                unit: "",
                                delta: NumberFormatter.formatDelta(deltas.sleepMinutesDelta),
                                deltaColor: NumberFormatter.deltaColor(deltas.sleepMinutesDelta)
                            )
                        }
                        
                        if let hrv = snapshot.hrvSDNNms {
                            MetricRowView(
                                label: "HRV (SDNN)",
                                value: NumberFormatter.format(hrv, decimals: 1),
                                unit: "ms",
                                delta: NumberFormatter.formatDelta(deltas.hrvDelta, decimals: 1),
                                deltaColor: NumberFormatter.deltaColor(deltas.hrvDelta)
                            )
                        }
                        
                        if let rhr = snapshot.restingHRBpm {
                            MetricRowView(
                                label: "Resting HR",
                                value: NumberFormatter.format(rhr),
                                unit: "bpm",
                                delta: NumberFormatter.formatDelta(deltas.restingHRDelta),
                                deltaColor: NumberFormatter.deltaColor(deltas.restingHRDelta)
                            )
                        }
                        
                        if let steps = snapshot.steps {
                            MetricRowView(
                                label: "Steps",
                                value: NumberFormatter.format(steps),
                                unit: "steps",
                                delta: NumberFormatter.formatDelta(deltas.stepsDelta),
                                deltaColor: NumberFormatter.deltaColor(deltas.stepsDelta)
                            )
                        }
                        
                        if let energy = snapshot.activeEnergyKcal {
                            MetricRowView(
                                label: "Active Energy",
                                value: NumberFormatter.format(energy),
                                unit: "kcal",
                                delta: NumberFormatter.formatDelta(deltas.activeEnergyDelta),
                                deltaColor: NumberFormatter.deltaColor(deltas.activeEnergyDelta)
                            )
                        }
                        
                        if let workout = snapshot.workoutMinutes, snapshot.workoutCount > 0 {
                            MetricRowView(
                                label: "Workouts",
                                value: "\(snapshot.workoutCount)",
                                unit: "(\(Int(workout))m)",
                                delta: NumberFormatter.formatDelta(deltas.workoutMinutesDelta),
                                deltaColor: NumberFormatter.deltaColor(deltas.workoutMinutesDelta)
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

#Preview {
    TrendsView(
        trendsVM: {
            let vm = TrendsViewModel(persistenceManager: try! PersistenceManager())
            let snapshots = MockData.sampleSnapshots(count: 28)
            let baselines = SnapshotBuilder.computeBaselines(from: snapshots)
            vm.snapshotsWithDeltas = snapshots.map { snapshot in
                let deltas = SnapshotBuilder.computeDeltas(for: snapshot, against: baselines)
                return DailySnapshotWithDeltas(snapshot: snapshot, deltas: deltas)
            }
            return vm
        }()
    )
}
