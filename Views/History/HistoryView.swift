import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject var sleepStore: SleepDataStore

    var recentSessions: [SleepSession] {
        Array(sleepStore.sessions.prefix(14))
    }

    var last7: [SleepSession] {
        Array(sleepStore.sessions.prefix(7))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Weekly overview chart
                    WeeklyBarChart(sessions: last7)

                    // Averages summary
                    if !last7.isEmpty {
                        averagesRow
                    }

                    // Session list
                    VStack(spacing: 10) {
                        ForEach(recentSessions) { session in
                            NavigationLink(destination: SessionDetailView(session: session)) {
                                SessionRow(session: session)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if recentSessions.isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Color("BackgroundPrimary").ignoresSafeArea())
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: Averages

    private var averagesRow: some View {
        let avgScore = last7.map(\.sleepScore).reduce(0, +) / last7.count
        let avgDuration = last7.map(\.totalDuration).reduce(0, +) / Double(last7.count)
        let hours = Int(avgDuration) / 3600
        let minutes = (Int(avgDuration) % 3600) / 60

        return HStack(spacing: 12) {
            StatCard(value: "\(avgScore)", label: "Avg score")
            StatCard(value: "\(hours)h \(minutes)m", label: "Avg duration")
            StatCard(
                value: last7.compactMap(\.averageHeartRate).isEmpty ? "—" :
                    "\(Int(last7.compactMap(\.averageHeartRate).reduce(0,+) / Double(last7.compactMap(\.averageHeartRate).count))) bpm",
                label: "Avg HR"
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.2))
            Text("No history yet")
                .font(.system(size: 18, weight: .light))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Weekly Bar Chart

struct WeeklyBarChart: View {
    let sessions: [SleepSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 nights")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.8)

            Chart(sessions) { session in
                BarMark(
                    x: .value("Day", session.startDate, unit: .day),
                    y: .value("Hours", session.totalDuration / 3600)
                )
                .foregroundStyle(scoreGradient(session.sleepScore))
                .cornerRadius(6)
            }
            .frame(height: 140)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        Text("\(value.as(Double.self).map { Int($0) } ?? 0)h")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }

            // Score legend
            HStack(spacing: 16) {
                legendDot(color: Color("AccentGreen"), label: "Great (85+)")
                legendDot(color: Color("AccentBlue"),  label: "Good (70–84)")
                legendDot(color: Color("AccentAmber"), label: "Fair (<70)")
            }
            .font(.system(size: 10))
            .foregroundColor(.white.opacity(0.4))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func scoreGradient(_ score: Int) -> LinearGradient {
        let color: Color = score >= 85 ? Color("AccentGreen") :
                           score >= 70 ? Color("AccentBlue") : Color("AccentAmber")
        return LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .top, endPoint: .bottom)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: SleepSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.startDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Text(session.durationString)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(session.sleepScore)")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white)
                ScoreBadge(label: session.scoreLabel, score: session.sleepScore)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.2))
                .padding(.leading, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
        )
    }
}

// MARK: - Score Badge

struct ScoreBadge: View {
    let label: String
    let score: Int

    var color: Color {
        score >= 85 ? Color("AccentGreen") :
        score >= 70 ? Color("AccentBlue") : Color("AccentAmber")
    }

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .medium))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Session Detail

struct SessionDetailView: View {
    let session: SleepSession

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ScoreRingView(score: session.sleepScore, label: session.scoreLabel)
                    .frame(height: 200)

                HypnogramView(
                    segments: session.segments,
                    startDate: session.startDate,
                    endDate: session.endDate
                )

                StageBreakdownView(session: session)

                if !session.heartRateSamples.isEmpty {
                    HeartRateChartView(samples: session.heartRateSamples)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color("BackgroundPrimary").ignoresSafeArea())
        .navigationTitle(session.startDate.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }
}
