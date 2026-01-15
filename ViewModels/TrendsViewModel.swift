import Foundation

/// ViewModel for the Trends tab.
@MainActor
class TrendsViewModel: ObservableObject {
    @Published var snapshotsWithDeltas: [DailySnapshotWithDeltas] = []
    @Published var baselines: Baselines?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let persistenceManager: PersistenceManager
    
    init(persistenceManager: PersistenceManager) {
        self.persistenceManager = persistenceManager
    }
    
    func loadTrendsData() {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let snapshots = try await persistenceManager.loadSnapshots()
                let baselines = SnapshotBuilder.computeBaselines(from: snapshots)
                
                self.baselines = baselines
                self.snapshotsWithDeltas = snapshots.map { snapshot in
                    let deltas = SnapshotBuilder.computeDeltas(for: snapshot, against: baselines)
                    return DailySnapshotWithDeltas(snapshot: snapshot, deltas: deltas)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            
            isLoading = false
        }
    }
}
