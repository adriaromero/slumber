import HealthKit
import Combine

class HealthKitService: ObservableObject {
    let store = HKHealthStore()

    @Published var isAuthorized = false
    @Published var authorizationError: String?

    // MARK: - Types

    private let readTypes: Set<HKObjectType> = [
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!
    ]

    private let writeTypes: Set<HKSampleType> = [
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    ]

    // MARK: - Authorization

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationError = "HealthKit is not available on this device."
            return
        }

        store.requestAuthorization(toShare: writeTypes, read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isAuthorized = success
                if let error = error {
                    self?.authorizationError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Read Heart Rate

    /// Fetches heart rate samples between two dates, sorted ascending.
    func fetchHeartRate(from start: Date, to end: Date) async -> [HeartRateSample] {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard error == nil, let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let hrSamples = samples.map {
                    HeartRateSample(
                        bpm: $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                        timestamp: $0.startDate
                    )
                }
                continuation.resume(returning: hrSamples)
            }
            store.execute(query)
        }
    }

    // MARK: - Write Sleep Analysis

    /// Writes a completed SleepSession's segments to HealthKit as HKCategorySamples.
    func writeSleepSession(_ session: SleepSession) async throws {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        var samples: [HKCategorySample] = []

        for segment in session.segments {
            let value: Int
            if #available(iOS 16.0, *) {
                switch segment.stage {
                case .awake: value = HKCategoryValueSleepAnalysis.awake.rawValue
                case .light: value = HKCategoryValueSleepAnalysis.asleepCore.rawValue
                case .deep:  value = HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                case .rem:   value = HKCategoryValueSleepAnalysis.asleepREM.rawValue
                }
            } else {
                switch segment.stage {
                case .awake:              value = HKCategoryValueSleepAnalysis.awake.rawValue
                case .light, .deep, .rem: value = HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                }
            }

            let sample = HKCategorySample(
                type: sleepType,
                value: value,
                start: segment.startDate,
                end: segment.endDate
            )
            samples.append(sample)
        }

        try await store.save(samples)
    }

    // MARK: - Read Step Count (movement proxy)

    /// Returns total step count for a time window — used as a wrist-movement proxy on Series 1.
    func fetchStepCount(from start: Date, to end: Date) async -> Double {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                continuation.resume(returning: steps)
            }
            store.execute(query)
        }
    }
}
