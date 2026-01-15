import Foundation
import HealthKit

/// Manages overall app state: authorization, sync state, and errors.
@MainActor
class AppStateViewModel: ObservableObject {
    @Published var isAuthorized = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastSyncDate: Date?
    
    private let healthKitService: HealthKitService
    private let persistenceManager: PersistenceManager
    
    init(
        healthKitService: HealthKitService,
        persistenceManager: PersistenceManager
    ) {
        self.healthKitService = healthKitService
        self.persistenceManager = persistenceManager
    }
    
    func requestHealthKitAuthorization() {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let authorized = try await healthKitService.requestAuthorization()
                isAuthorized = authorized
                
                if authorized {
                    // Sync data on first authorization
                    try await refreshData()
                }
            } catch {
                errorMessage = error.localizedDescription
                isAuthorized = false
            }
            
            isLoading = false
        }
    }
    
    func refreshData() async throws {
        do {
            let snapshots = try await healthKitService.fetchSnapshots(lastDays: 28)
            try await persistenceManager.saveSnapshots(snapshots)
            try await persistenceManager.saveSyncDate(Date())
            
            await MainActor.run {
                self.lastSyncDate = Date()
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    func loadSyncDate() {
        Task {
            do {
                let date = try await persistenceManager.loadSyncDate()
                self.lastSyncDate = date
            } catch {
                // Silently ignore load errors
            }
        }
    }
}
