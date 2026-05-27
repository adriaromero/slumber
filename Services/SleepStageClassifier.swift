import Foundation
import CoreMotion

// MARK: - Motion Sample
struct MotionSample {
    let timestamp: Date
    let magnitude: Double  // resultant acceleration magnitude
}

// MARK: - Sleep Stage Classifier
/// Classifies sleep stages from wrist accelerometer data.
/// Series 1 has no dedicated sleep sensors; we infer stages from movement magnitude.
///
/// Algorithm overview:
///   1. Bin raw samples into 1-minute epochs
///   2. Compute activity score (mean magnitude delta) per epoch
///   3. Apply threshold rules to assign a provisional stage
///   4. Smooth with a 5-epoch median filter to remove single-epoch outliers
///   5. Insert REM windows heuristically (Series 1 cannot detect REM directly)
class SleepStageClassifier {

    // MARK: Thresholds (tunable)
    private let awakeThreshold: Double   = 0.18   // g — clear movement
    private let lightThreshold: Double   = 0.06   // g — mild restlessness
    // Below lightThreshold → deep sleep candidate
    private let epochDuration: TimeInterval = 60  // seconds per epoch

    // MARK: Public API

    func classify(samples: [MotionSample], sessionStart: Date, sessionEnd: Date) -> [SleepSegment] {
        guard !samples.isEmpty else { return [] }

        let epochs = buildEpochs(samples: samples, start: sessionStart, end: sessionEnd)
        let rawStages = epochs.map { assignStage(activityScore: $0.activityScore) }
        let smoothed = medianSmooth(rawStages, windowSize: 5)
        let withREM = injectREM(stages: smoothed, epochs: epochs)

        return buildSegments(stages: withREM, epochs: epochs)
    }

    // MARK: - Epoch building

    private struct Epoch {
        let startDate: Date
        let endDate: Date
        let activityScore: Double   // mean |Δmagnitude| within the minute
    }

    private func buildEpochs(samples: [MotionSample], start: Date, end: Date) -> [Epoch] {
        var epochs: [Epoch] = []
        var cursor = start

        while cursor < end {
            let epochEnd = cursor.addingTimeInterval(epochDuration)
            let window = samples.filter { $0.timestamp >= cursor && $0.timestamp < epochEnd }
            let score = activityScore(for: window)
            epochs.append(Epoch(startDate: cursor, endDate: epochEnd, activityScore: score))
            cursor = epochEnd
        }
        return epochs
    }

    private func activityScore(for samples: [MotionSample]) -> Double {
        guard samples.count > 1 else { return 0 }
        var totalDelta = 0.0
        for i in 1..<samples.count {
            totalDelta += abs(samples[i].magnitude - samples[i - 1].magnitude)
        }
        return totalDelta / Double(samples.count - 1)
    }

    // MARK: - Stage assignment

    private func assignStage(activityScore score: Double) -> SleepStage {
        if score >= awakeThreshold { return .awake }
        if score >= lightThreshold { return .light }
        return .deep
    }

    // MARK: - Smoothing

    private func medianSmooth(_ stages: [SleepStage], windowSize: Int) -> [SleepStage] {
        guard stages.count >= windowSize else { return stages }
        var result = stages
        let half = windowSize / 2

        for i in half..<(stages.count - half) {
            let window = stages[(i - half)...(i + half)].map(\.rawValue).sorted()
            let medianRaw = window[half]
            result[i] = SleepStage(rawValue: medianRaw) ?? stages[i]
        }
        return result
    }

    // MARK: - REM injection
    /// Series 1 cannot detect REM directly. We use a standard sleep-cycle heuristic:
    /// REM occurs roughly every 90 minutes. We replace the last ~20 min of each
    /// deep-sleep block (if it falls in a plausible REM window) with REM.
    private func injectREM(stages: [SleepStage], epochs: [Epoch]) -> [SleepStage] {
        guard let firstEpoch = epochs.first else { return stages }
        var result = stages
        let remWindowMinutes = 20         // minutes to convert to REM at end of each cycle
        let cycleMinutes = 90             // standard sleep cycle length
        let firstREMOffsetMinutes = 70    // first REM typically ~70-90 min after sleep onset

        // Find sleep onset (first non-awake epoch)
        guard let onsetIndex = stages.firstIndex(where: { $0 != .awake }) else { return stages }
        let onsetTime = epochs[onsetIndex].startDate

        var cycleStart = onsetTime.addingTimeInterval(Double(firstREMOffsetMinutes) * 60)

        while cycleStart < (epochs.last?.endDate ?? Date()) {
            let remStart = cycleStart
            let remEnd = remStart.addingTimeInterval(Double(remWindowMinutes) * 60)

            for (i, epoch) in epochs.enumerated() {
                if epoch.startDate >= remStart && epoch.endDate <= remEnd {
                    // Only replace deep or light (not awake)
                    if result[i] != .awake {
                        result[i] = .rem
                    }
                }
            }
            cycleStart = cycleStart.addingTimeInterval(Double(cycleMinutes) * 60)
        }
        return result
    }

    // MARK: - Segment building

    private func buildSegments(stages: [SleepStage], epochs: [Epoch]) -> [SleepSegment] {
        guard !stages.isEmpty else { return [] }
        var segments: [SleepSegment] = []
        var currentStage = stages[0]
        var segStart = epochs[0].startDate

        for i in 1..<stages.count {
            if stages[i] != currentStage {
                segments.append(SleepSegment(
                    stage: currentStage,
                    startDate: segStart,
                    endDate: epochs[i].startDate
                ))
                currentStage = stages[i]
                segStart = epochs[i].startDate
            }
        }
        // Close last segment
        if let lastEpoch = epochs.last {
            segments.append(SleepSegment(
                stage: currentStage,
                startDate: segStart,
                endDate: lastEpoch.endDate
            ))
        }
        return segments
    }
}
