import Foundation

extension SleepDataStore {
    /// Injects 7 nights of realistic fake sessions. Safe to call multiple times —
    /// skips injection if data already exists.
    func loadSampleData() {
        guard sessions.isEmpty else { return }
        let calendar = Calendar.current
        let now = Date()

        for daysAgo in 1...7 {
            guard let night = calendar.date(byAdding: .day, value: -daysAgo, to: now),
                  let bedtime = calendar.date(
                    bySettingHour: Int.random(in: 21...23),
                    minute: [0, 15, 30, 45].randomElement()!,
                    second: 0, of: night)
            else { continue }

            let durationHours = Double.random(in: 5.8...8.8)
            let wakeTime = bedtime.addingTimeInterval(durationHours * 3600)

            let segments = Self.makeSegments(start: bedtime, end: wakeTime)
            let hrSamples = Self.makeHeartRate(segments: segments, start: bedtime, end: wakeTime)

            add(session: SleepSession(
                id: UUID(),
                startDate: bedtime,
                endDate: wakeTime,
                segments: segments,
                heartRateSamples: hrSamples
            ))
        }
    }

    // MARK: - Segment generation

    private static func makeSegments(start: Date, end: Date) -> [SleepSegment] {
        // Models a typical night: fall-asleep → light → deep → REM cycles,
        // ending with a brief wake.
        let totalSeconds = end.timeIntervalSince(start)
        typealias Block = (stage: SleepStage, fraction: Double)

        // Rough sleep architecture fractions that add to ~1.0
        let architecture: [Block] = [
            (.awake,  0.03),   // falling asleep
            (.light,  0.08),
            (.deep,   0.14),
            (.light,  0.04),
            (.rem,    0.08),
            (.light,  0.05),
            (.deep,   0.12),
            (.light,  0.04),
            (.rem,    0.09),
            (.light,  0.06),
            (.deep,   0.07),
            (.light,  0.05),
            (.rem,    0.09),
            (.light,  0.08),
            (.awake,  0.03),   // final wake
        ]

        // Add ±20 % jitter so nights look different
        var jittered = architecture.map { block -> Block in
            let jitter = Double.random(in: 0.80...1.20)
            return (block.stage, block.fraction * jitter)
        }
        let total = jittered.map(\.fraction).reduce(0, +)
        jittered = jittered.map { ($0.stage, $0.fraction / total) }

        var segments: [SleepSegment] = []
        var cursor = start
        for block in jittered {
            let duration = totalSeconds * block.fraction
            guard duration >= 60 else { continue }
            let segEnd = cursor.addingTimeInterval(duration)
            segments.append(SleepSegment(stage: block.stage,
                                         startDate: cursor,
                                         endDate: min(segEnd, end)))
            cursor = segEnd
            if cursor >= end { break }
        }
        // Close any gap
        if let last = segments.last, last.endDate < end {
            segments.append(SleepSegment(stage: .awake,
                                         startDate: last.endDate,
                                         endDate: end))
        }
        return segments
    }

    // MARK: - Heart rate generation

    private static func makeHeartRate(segments: [SleepSegment],
                                      start: Date, end: Date) -> [HeartRateSample] {
        var samples: [HeartRateSample] = []
        var cursor = start
        let interval: TimeInterval = 300  // one sample every 5 min

        while cursor <= end {
            let stage = segments.first {
                cursor >= $0.startDate && cursor < $0.endDate
            }?.stage ?? .awake

            let bpm: Double
            switch stage {
            case .awake: bpm = Double.random(in: 62...78)
            case .light: bpm = Double.random(in: 56...66)
            case .deep:  bpm = Double.random(in: 48...60)
            case .rem:   bpm = Double.random(in: 54...68)
            }

            samples.append(HeartRateSample(bpm: bpm.rounded(), timestamp: cursor))
            cursor = cursor.addingTimeInterval(interval)
        }
        return samples
    }
}
