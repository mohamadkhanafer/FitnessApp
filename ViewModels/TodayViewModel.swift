import Foundation

/// ViewModel for the Today tab.
@MainActor
class TodayViewModel: ObservableObject {
    @Published var todaySnapshot: DailySnapshot?
    @Published var baselines: Baselines?
    @Published var deltas: SnapshotDeltas?
    @Published var insights: [InsightCard] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let persistenceManager: PersistenceManager
    private let healthKitService: HealthKitService
    
    init(
        persistenceManager: PersistenceManager,
        healthKitService: HealthKitService
    ) {
        self.persistenceManager = persistenceManager
        self.healthKitService = healthKitService
    }
    
    func loadTodayData() {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let snapshots = try await persistenceManager.loadSnapshots()
                
                if let today = snapshots.first {
                    self.todaySnapshot = today
                    let baselines = SnapshotBuilder.computeBaselines(from: snapshots)
                    self.baselines = baselines
                    
                    let deltas = SnapshotBuilder.computeDeltas(for: today, against: baselines)
                    self.deltas = deltas
                    
                    self.insights = SnapshotBuilder.generateInsights(
                        for: today,
                        deltas: deltas,
                        baselines: baselines
                    )
                } else {
                    self.todaySnapshot = nil
                    self.baselines = nil
                    self.deltas = nil
                    self.insights = []
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            
            isLoading = false
        }
    }
}
