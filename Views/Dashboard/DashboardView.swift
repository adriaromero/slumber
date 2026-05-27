import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var sleepStore: SleepDataStore
    @EnvironmentObject var healthStore: HealthKitService

    var session: SleepSession? { sleepStore.latestSession }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Greeting
                    greetingHeader

                    if let s = session {
                        // Score ring
                        ScoreRingView(score: s.sleepScore, label: s.scoreLabel)
                            .frame(height: 200)

                        // Key stats
                        statsRow(session: s)

                        // Hypnogram
                        HypnogramView(segments: s.segments,
                                      startDate: s.startDate,
                                      endDate: s.endDate)

                        // Stage breakdown
                        StageBreakdownView(session: s)

                        // Heart rate chart
                        if !s.heartRateSamples.isEmpty {
                            HeartRateChartView(samples: s.heartRateSamples)
                        }
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Color("BackgroundPrimary").ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }

    // MARK: Subviews

    private var greetingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.system(size: 26, weight: .light))
                    .foregroundColor(.white)
                Text(Date(), style: .date)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
            }
            Spacer()
            SlumberLogoMark(size: 40)
        }
        .padding(.top, 8)
    }

    private func statsRow(session: SleepSession) -> some View {
        HStack(spacing: 12) {
            StatCard(value: session.durationString, label: "Total sleep")
            StatCard(
                value: session.averageHeartRate.map { "\(Int($0)) bpm" } ?? "—",
                label: "Avg HR"
            )
            StatCard(
                value: session.startDate.formatted(date: .omitted, time: .shortened),
                label: "Bedtime"
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 48))
                .foregroundColor(Color("AccentBlue").opacity(0.5))
            Text("No sleep data yet")
                .font(.system(size: 20, weight: .light))
                .foregroundColor(.white)
            Text("Tap Sleep to start tracking tonight")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
}

// MARK: - Score Ring

struct ScoreRingView: View {
    let score: Int
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 14)

            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(
                    LinearGradient(
                        colors: [Color("AccentBlue"), Color("AccentPurple")],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.0), value: score)

            VStack(spacing: 4) {
                Text("\(score)")
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .foregroundColor(.white)
                Text("Sleep score")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                    .textCase(.uppercase)
                    .tracking(1)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(scoreColor)
            }
        }
        .padding(20)
    }

    private var scoreColor: Color {
        switch score {
        case 85...: return Color("AccentGreen")
        case 70..<85: return Color("AccentBlue")
        case 55..<70: return Color("AccentAmber")
        default: return Color("AccentRed")
        }
    }
}

// MARK: - Hypnogram

struct HypnogramView: View {
    let segments: [SleepSegment]
    let startDate: Date
    let endDate: Date

    var totalDuration: TimeInterval { endDate.timeIntervalSince(startDate) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sleep stages")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.8)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 72)

                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(segments) { seg in
                            let widthFraction = seg.duration / totalDuration
                            let stageHeight: CGFloat = {
                                switch seg.stage {
                                case .awake: return 72 * 0.25
                                case .light: return 72 * 0.50
                                case .deep:  return 72 * 0.85
                                case .rem:   return 72 * 0.65
                                }
                            }()

                            VStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(stageColor(seg.stage))
                                    .frame(
                                        width: max(2, geo.size.width * widthFraction - 1),
                                        height: stageHeight
                                    )
                            }
                        }
                    }
                    .frame(height: 72)
                }
                .frame(height: 72)
            }

            // Time axis labels
            HStack {
                Text(startDate.formatted(date: .omitted, time: .shortened))
                Spacer()
                Text(endDate.formatted(date: .omitted, time: .shortened))
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(.white.opacity(0.3))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func stageColor(_ stage: SleepStage) -> Color {
        switch stage {
        case .awake: return Color(hex: "#1e2d6e")
        case .light: return Color(hex: "#3D52B0")
        case .deep:  return Color(hex: "#6B85E0")
        case .rem:   return Color(hex: "#06D6A0")
        }
    }
}

// MARK: - Stage Breakdown

struct StageBreakdownView: View {
    let session: SleepSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Breakdown")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.8)

            ForEach(SleepStage.allCases, id: \.rawValue) { stage in
                let dur = duration(for: stage)
                let pct = dur / session.totalDuration

                HStack(spacing: 10) {
                    Circle()
                        .fill(stageColor(stage))
                        .frame(width: 8, height: 8)

                    Text(stage.label)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 50, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.08))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(stageColor(stage))
                                .frame(width: geo.size.width * CGFloat(pct))
                        }
                    }
                    .frame(height: 6)

                    Text(formatDuration(dur))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 52, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func duration(for stage: SleepStage) -> TimeInterval {
        session.segments.filter { $0.stage == stage }.reduce(0) { $0 + $1.duration }
    }

    private func stageColor(_ stage: SleepStage) -> Color {
        switch stage {
        case .awake: return Color(hex: "#1e2d6e")
        case .light: return Color(hex: "#3D52B0")
        case .deep:  return Color(hex: "#6B85E0")
        case .rem:   return Color(hex: "#06D6A0")
        }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

// MARK: - Heart Rate Chart

struct HeartRateChartView: View {
    let samples: [HeartRateSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Heart rate")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.8)

            Chart(samples) { sample in
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("BPM", sample.bpm)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color("AccentRed").opacity(0.8))

                AreaMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("BPM", sample.bpm)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color("AccentRed").opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(height: 100)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisValueLabel {
                        Text("\(value.as(Int.self) ?? 0)")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.06))
        )
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.07))
        )
    }
}

// MARK: - Color helpers

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
