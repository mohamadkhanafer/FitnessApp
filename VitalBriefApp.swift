import SwiftUI

@main
struct VitalBriefApp: App {
    @State private var healthKitService: HealthKitService?
    @State private var persistenceManager: PersistenceManager?
    @State private var appState: AppStateViewModel?
    @State private var todayVM: TodayViewModel?
    @State private var trendsVM: TrendsViewModel?
    @State private var initError: String?
    
    var body: some Scene {
        WindowGroup {
            if let error = initError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    
                    Text("Initialization Error")
                        .font(.headline)
                    
                    Text(error)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if let appState = appState,
                      let todayVM = todayVM,
                      let trendsVM = trendsVM {
                if appState.isAuthorized {
                    MainTabView(
                        appState: appState,
                        todayVM: todayVM,
                        trendsVM: trendsVM
                    )
                } else {
                    ConnectView(appState: appState)
                }
            } else {
                ProgressView()
                    .onAppear(perform: initializeServices)
            }
        }
    }
    
    private func initializeServices() {
        do {
            let hkService = HealthKitService()
            let persistence = try PersistenceManager()
            let appStateVM = AppStateViewModel(
                healthKitService: hkService,
                persistenceManager: persistence
            )
            let todayVM = TodayViewModel(
                persistenceManager: persistence,
                healthKitService: hkService
            )
            let trendsVM = TrendsViewModel(persistenceManager: persistence)
            
            self.healthKitService = hkService
            self.persistenceManager = persistence
            self.appState = appStateVM
            self.todayVM = todayVM
            self.trendsVM = trendsVM
            
            // Load cached sync date
            appStateVM.loadSyncDate()
        } catch {
            self.initError = error.localizedDescription
        }
    }
}

struct MainTabView: View {
    @ObservedObject var appState: AppStateViewModel
    @ObservedObject var todayVM: TodayViewModel
    @ObservedObject var trendsVM: TrendsViewModel
    
    var body: some View {
        TabView {
            TodayView(todayVM: todayVM, appState: appState)
                .tabItem {
                    Label("Today", systemImage: "calendar")
                }
            
            TrendsView(trendsVM: trendsVM)
                .tabItem {
                    Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                }
            
            SettingsView(
                appState: appState,
                todayVM: todayVM,
                trendsVM: trendsVM
            )
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}

#Preview {
    VitalBriefApp()
}
