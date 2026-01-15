import HealthKit
import Foundation

/// Handles all HealthKit interactions: permissions and data fetching.
actor HealthKitService {
    
    enum HealthKitError: LocalizedError {
        case notAvailable
        case authorizationDenied
        case queryFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "HealthKit is not available on this device."
            case .authorizationDenied:
                return "HealthKit authorization was denied. Please enable permissions in Settings."
            case .queryFailed(let reason):
                return "Failed to fetch data: \(reason)"
            }
        }
    }
    
    private let store = HKHealthStore()
    
    /// The set of types we request read permission for.
    private var typesToRead: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }
        if let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrvType)
        }
        if let rhType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(rhType)
        }
        if let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepsType)
        }
        if let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energyType)
        }
        types.insert(HKObjectType.workoutType())
        
        return types
    }
    
    /// Requests read authorization for all data types.
    func requestAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        do {
            try await store.requestAuthorization(toShare: nil, read: typesToRead)
            // Check if we got authorization for at least the core types
            let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
            let authStatus = store.authorizationStatus(for: sleepType!)
            
            if authStatus == .notDetermined {
                throw HealthKitError.authorizationDenied
            }
            
            return authStatus == .sharingAuthorized
        } catch {
            if error is HealthKitError {
                throw error
            }
            throw HealthKitError.authorizationDenied
        }
    }
    
    /// Fetches snapshots for the last N days.
    func fetchSnapshots(lastDays: Int) async throws -> [DailySnapshot] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        var snapshots: [DailySnapshot] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Fetch data for each day
        for dayOffset in 0..<lastDays {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            let snapshot = try await fetchSnapshot(for: date)
            snapshots.append(snapshot)
        }
        
        return snapshots.sorted { $0.date > $1.date }
    }
    
    // MARK: - Private Helpers
    
    private func fetchSnapshot(for date: Date) async throws -> DailySnapshot {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        
        let id = dateFormatter.string(from: date)
        
        async let sleepData = fetchSleep(startDate: dayStart, endDate: dayEnd)
        async let hrvData = fetchHRV(startDate: dayStart, endDate: dayEnd)
        async let restingHRData = fetchRestingHR(startDate: dayStart, endDate: dayEnd)
        async let stepsData = fetchSteps(startDate: dayStart, endDate: dayEnd)
        async let energyData = fetchActiveEnergy(startDate: dayStart, endDate: dayEnd)
        async let workoutData = fetchWorkouts(startDate: dayStart, endDate: dayEnd)
        
        let (sleep, sleepSource) = try await sleepData
        let (hrv, hrvSource) = try await hrvData
        let (restingHR, restingHRSource) = try await restingHRData
        let (steps, stepsSource) = try await stepsData
        let (energy, energySource) = try await energyData
        let (workoutMinutes, workoutCount, workoutSource) = try await workoutData
        
        let sources = SnapshotSources(
            sleepSource: sleepSource,
            hrvSource: hrvSource,
            restingHRSource: restingHRSource,
            stepsSource: stepsSource,
            activeEnergySource: energySource,
            workoutSource: workoutSource
        )
        
        return DailySnapshot(
            id: id,
            date: dayStart,
            sleepMinutes: sleep,
            hrvSDNNms: hrv,
            restingHRBpm: restingHR,
            steps: steps,
            activeEnergyKcal: energy,
            workoutMinutes: workoutMinutes,
            workoutCount: workoutCount,
            sources: sources
        )
    }
    
    private func fetchSleep(startDate: Date, endDate: Date) async throws -> (Double?, String?) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return (nil, nil)
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }
                
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: (nil, nil))
                    return
                }
                
                // Sum "asleep" minutes, ignoring "in bed" to avoid double-counting
                let asleepMinutes = samples
                    .filter { $0.value == HKCategoryValue.sleepAnalysisAsleep.rawValue }
                    .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 60.0 }
                
                let source = samples.first?.sourceRevision.source.bundleIdentifier
                
                continuation.resume(returning: (asleepMinutes > 0 ? asleepMinutes : nil, source))
            }
            
            store.execute(query)
        }
    }
    
    private func fetchHRV(startDate: Date, endDate: Date) async throws -> (Double?, String?) {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return (nil, nil)
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }
                
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    continuation.resume(returning: (nil, nil))
                    return
                }
                
                // Prefer samples during sleep; otherwise use daily median
                let allValues = samples.map { $0.quantity.doubleValue(for: HKUnit.millisecond()) }
                let medianHRV = SnapshotBuilder.median(allValues)
                let source = samples.first?.sourceRevision.source.bundleIdentifier
                
                continuation.resume(returning: (medianHRV, source))
            }
            
            store.execute(query)
        }
    }
    
    private func fetchRestingHR(startDate: Date, endDate: Date) async throws -> (Double?, String?) {
        guard let rhType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            return (nil, nil)
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: rhType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }
                
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    continuation.resume(returning: (nil, nil))
                    return
                }
                
                let values = samples.map { $0.quantity.doubleValue(for: HKUnit.beatsPerMinute()) }
                let avgRHR = values.reduce(0, +) / Double(values.count)
                let source = samples.first?.sourceRevision.source.bundleIdentifier
                
                continuation.resume(returning: (avgRHR, source))
            }
            
            store.execute(query)
        }
    }
    
    private func fetchSteps(startDate: Date, endDate: Date) async throws -> (Double?, String?) {
        guard let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return (nil, nil)
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }
                
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: (nil, nil))
                    return
                }
                
                let steps = sum.doubleValue(for: HKUnit.count())
                continuation.resume(returning: (steps > 0 ? steps : nil, "com.apple.health"))
            }
            
            store.execute(query)
        }
    }
    
    private func fetchActiveEnergy(startDate: Date, endDate: Date) async throws -> (Double?, String?) {
        guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return (nil, nil)
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: energyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }
                
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: (nil, nil))
                    return
                }
                
                let energy = sum.doubleValue(for: HKUnit.kilocalorie())
                continuation.resume(returning: (energy > 0 ? energy : nil, "com.apple.health"))
            }
            
            store.execute(query)
        }
    }
    
    private func fetchWorkouts(startDate: Date, endDate: Date) async throws -> (Double?, Int, String?) {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }
                
                guard let workouts = samples as? [HKWorkout], !workouts.isEmpty else {
                    continuation.resume(returning: (nil, 0, nil))
                    return
                }
                
                let totalMinutes = workouts.reduce(0) { $0 + $1.duration / 60.0 }
                let source = workouts.first?.sourceRevision.source.bundleIdentifier
                
                continuation.resume(returning: (totalMinutes, workouts.count, source))
            }
            
            store.execute(query)
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}
