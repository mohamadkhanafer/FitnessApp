import SwiftUI

struct ConnectView: View {
    @ObservedObject var appState: AppStateViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Connect Apple Health")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("VitalBrief reads your Apple Health data to summarize trends and provide insights.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Button(action: appState.requestHealthKitAuthorization) {
                Text(appState.isLoading ? "Authorizing..." : "Allow Access")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(appState.isLoading)
            
            if let error = appState.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    ConnectView(appState: AppStateViewModel(
        healthKitService: HealthKitService(),
        persistenceManager: try! PersistenceManager()
    ))
}
