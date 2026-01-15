import Foundation

enum DateHelper {
    static func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    static func fullDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    static func timeAgoString(from date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let days = components.day, days > 0 {
            return "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "just now"
        }
    }
}

enum NumberFormatter {
    static func format(_ value: Double?, decimals: Int = 0) -> String {
        guard let value = value else { return "—" }
        let formatter = Foundation.NumberFormatter()
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: value)) ?? "—"
    }
    
    static func formatDelta(_ delta: Double?, decimals: Int = 0) -> String {
        guard let delta = delta else { return "—" }
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(format(delta, decimals: decimals))"
    }
    
    static func deltaColor(_ delta: Double?) -> String {
        guard let delta = delta else { return "gray" }
        return delta > 0 ? "green" : delta < 0 ? "red" : "gray"
    }
}

enum MockData {
    static let sampleSnapshot = DailySnapshot(
        id: "2025-01-15",
        date: Calendar.current.startOfDay(for: Date()),
        sleepMinutes: 420,
        hrvSDNNms: 45.2,
        restingHRBpm: 58,
        steps: 8234,
        activeEnergyKcal: 542,
        workoutMinutes: 45,
        workoutCount: 1,
        sources: SnapshotSources(
            sleepSource: "com.apple.health",
            hrvSource: "com.apple.health",
            restingHRSource: "com.apple.health",
            stepsSource: "com.apple.health",
            activeEnergySource: "com.apple.health",
            workoutSource: "com.apple.health"
        )
    )
    
    static func sampleSnapshots(count: Int) -> [DailySnapshot] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return (0..<count).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let id = dateFormatter.string(from: date)
            
            // Vary values slightly to show baselines and deltas
            let sleepVariation = Double.random(in: -30...30)
            let stepVariation = Double.random(in: -1000...1000)
            
            return DailySnapshot(
                id: id,
                date: date,
                sleepMinutes: 420 + sleepVariation,
                hrvSDNNms: 45 + Double.random(in: -5...5),
                restingHRBpm: 58 + Double.random(in: -3...3),
                steps: 8000 + stepVariation,
                activeEnergyKcal: 500 + Double.random(in: -50...50),
                workoutMinutes: Bool.random() ? Double.random(in: 20...60) : nil,
                workoutCount: Bool.random() ? 1 : 0,
                sources: SnapshotSources(
                    sleepSource: "com.apple.health",
                    hrvSource: "com.apple.health",
                    restingHRSource: "com.apple.health",
                    stepsSource: "com.apple.health",
                    activeEnergySource: "com.apple.health",
                    workoutSource: "com.apple.health"
                )
            )
        }
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}
