import Foundation

// MARK: - Sleep Stage
enum SleepStage: Int, CaseIterable, Codable {
    case awake = 0
    case light = 1
    case deep = 2
    case rem = 3

    var label: String {
        switch self {
        case .awake: return "Awake"
        case .light: return "Light"
        case .deep: return "Deep"
        case .rem: return "REM"
        }
    }

    var color: String {
        switch self {
        case .awake: return "#1e2d6e"
        case .light: return "#3D52B0"
        case .deep: return "#6B85E0"
        case .rem: return "#06D6A0"
        }
    }
}

// MARK: - Sleep Segment
/// A contiguous block of one sleep stage
struct SleepSegment: Identifiable, Codable {
    let id: UUID
    let stage: SleepStage
    let startDate: Date
    let endDate: Date

    var duration: TimeInterval { endDate.timeIntervalSince(startDate) }

    init(stage: SleepStage, startDate: Date, endDate: Date) {
        self.id = UUID()
        self.stage = stage
        self.startDate = startDate
        self.endDate = endDate
    }
}

// MARK: - Heart Rate Sample
struct HeartRateSample: Identifiable, Codable {
    let id: UUID
    let bpm: Double
    let timestamp: Date

    init(bpm: Double, timestamp: Date) {
        self.id = UUID()
        self.bpm = bpm
        self.timestamp = timestamp
    }
}

// MARK: - Sleep Session
struct SleepSession: Identifiable, Codable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    var segments: [SleepSegment]
    var heartRateSamples: [HeartRateSample]

    // MARK: Computed metrics

    var totalDuration: TimeInterval { endDate.timeIntervalSince(startDate) }

    var durationString: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    var deepSleepDuration: TimeInterval {
        segments.filter { $0.stage == .deep }.reduce(0) { $0 + $1.duration }
    }

    var remDuration: TimeInterval {
        segments.filter { $0.stage == .rem }.reduce(0) { $0 + $1.duration }
    }

    var lightSleepDuration: TimeInterval {
        segments.filter { $0.stage == .light }.reduce(0) { $0 + $1.duration }
    }

    var awakeDuration: TimeInterval {
        segments.filter { $0.stage == .awake }.reduce(0) { $0 + $1.duration }
    }

    var awakeningCount: Int {
        var count = 0
        for i in 1..<segments.count {
            if segments[i].stage == .awake && segments[i - 1].stage != .awake {
                count += 1
            }
        }
        return count
    }

    var averageHeartRate: Double? {
        guard !heartRateSamples.isEmpty else { return nil }
        return heartRateSamples.map(\.bpm).reduce(0, +) / Double(heartRateSamples.count)
    }

    var restingHeartRate: Double? {
        // Lowest 10th-percentile samples taken during deep sleep window
        let deepWindows = segments.filter { $0.stage == .deep }
        let deepSamples = heartRateSamples.filter { sample in
            deepWindows.contains { seg in
                sample.timestamp >= seg.startDate && sample.timestamp <= seg.endDate
            }
        }
        guard !deepSamples.isEmpty else { return averageHeartRate }
        let sorted = deepSamples.map(\.bpm).sorted()
        let tenthPct = max(1, sorted.count / 10)
        return sorted.prefix(tenthPct).reduce(0, +) / Double(tenthPct)
    }

    /// 0–100 composite score
    var sleepScore: Int {
        let totalHrs = totalDuration / 3600

        // Duration score (target 8h)
        let durationScore: Double
        if totalHrs >= 8 { durationScore = 30 }
        else if totalHrs >= 7 { durationScore = 25 }
        else if totalHrs >= 6 { durationScore = 18 }
        else { durationScore = max(0, totalHrs / 6 * 18) }

        // Deep sleep score (target ≥1.5h = 20 pts)
        let deepScore = min(20, (deepSleepDuration / 5400) * 20)

        // REM score (target ≥1.5h = 20 pts)
        let remScore = min(20, (remDuration / 5400) * 20)

        // Continuity score (fewer awakenings = better, max 20 pts)
        let continuityScore = max(0, 20 - Double(awakeningCount) * 4)

        // HR score (lower resting HR = better, 10 pts)
        let hrScore: Double
        if let hr = restingHeartRate {
            hrScore = hr < 60 ? 10 : hr < 70 ? 7 : hr < 80 ? 4 : 2
        } else {
            hrScore = 5
        }

        return min(100, Int(durationScore + deepScore + remScore + continuityScore + hrScore))
    }

    var scoreLabel: String {
        switch sleepScore {
        case 85...: return "Great"
        case 70..<85: return "Good"
        case 55..<70: return "Fair"
        default: return "Poor"
        }
    }
}

// MARK: - Sleep Data Store
import Combine

class SleepDataStore: ObservableObject {
    @Published var sessions: [SleepSession] = []
    @Published var latestSession: SleepSession?

    private let persistenceKey = "slumber.sessions"

    init() {
        load()
    }

    func add(session: SleepSession) {
        sessions.insert(session, at: 0)
        sessions.sort { $0.startDate > $1.startDate }
        latestSession = sessions.first
        save()
    }

    // MARK: Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let decoded = try? JSONDecoder().decode([SleepSession].self, from: data)
        else { return }
        sessions = decoded
        latestSession = sessions.first
    }
}
