import SwiftUI

struct MetricRowView: View {
    let label: String
    let value: String
    let unit: String
    let delta: String?
    let deltaColor: String?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Text(value)
                        .font(.headline)
                    
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if let delta = delta {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("vs baseline")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(delta)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(deltaColor == "green" ? .green : deltaColor == "red" ? .red : .gray)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct InsightCardView: View {
    let insight: InsightCard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(insight.title)
                    .font(.headline)
                
                Spacer()
                
                Badge(confidence: insight.confidence)
            }
            
            Text(insight.explanation)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct Badge: View {
    let confidence: InsightCard.Confidence
    
    var body: some View {
        Text(confidence.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor)
            .foregroundColor(.white)
            .cornerRadius(6)
    }
    
    private var badgeColor: Color {
        switch confidence {
        case .high:
            return .green
        case .medium:
            return .orange
        case .low:
            return .gray
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        MetricRowView(
            label: "Sleep",
            value: "7h 0m",
            unit: "",
            delta: "+30 min",
            deltaColor: "green"
        )
        
        InsightCardView(insight: InsightCard(
            type: .recoverySignals,
            title: "Recovery Signals",
            explanation: "Today shows positive recovery markers: improved sleep, elevated HRV vs. your 28-day baseline.",
            confidence: .high
        ))
    }
    .padding()
}
