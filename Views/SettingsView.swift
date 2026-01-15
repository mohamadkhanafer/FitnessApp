import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppStateViewModel
    @ObservedObject var todayVM: TodayViewModel
    @ObservedObject var trendsVM: TrendsViewModel
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Authorization status
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("HealthKit Authorization")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Text(appState.isAuthorized ? "Authorized" : "Not Authorized")
                                    .font(.caption)
                                    .foregroundColor(appState.isAuthorized ? .green : .red)
                            }
                            
                            if appState.isAuthorized {
                                Text("Data access enabled")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    // Last sync
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Last Sync")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            if let syncDate = appState.lastSyncDate {
                                Text(DateHelper.fullDateString(from: syncDate))
                                    .font(.body)
                                
                                Text(DateHelper.timeAgoString(from: syncDate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("No sync recorded")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    // Refresh button
                    Section {
                        Button(action: refreshData) {
                            if trendsVM.isLoading {
                                HStack {
                                    ProgressView()
                                    Text("Syncing...")
                                }
                            } else {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Refresh from Apple Health")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(!appState.isAuthorized || trendsVM.isLoading)
                    }
                    
                    // Info
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text("VitalBrief reads your Apple Health data (last 28 days) and provides observational insights about your health trends.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(nil)
                            
                            Text("Version 1.0")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Settings")
        }
    }
    
    private func refreshData() {
        Task {
            do {
                try await appState.refreshData()
                // Reload views after sync
                todayVM.loadTodayData()
                trendsVM.loadTrendsData()
            } catch {
                print("Refresh failed: \(error)")
            }
        }
    }
}

#Preview {
    SettingsView(
        appState: AppStateViewModel(
            healthKitService: HealthKitService(),
            persistenceManager: try! PersistenceManager()
        ),
        todayVM: TodayViewModel(
            persistenceManager: try! PersistenceManager(),
            healthKitService: HealthKitService()
        ),
        trendsVM: TrendsViewModel(persistenceManager: try! PersistenceManager())
    )
}
