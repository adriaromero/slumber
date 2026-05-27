import SwiftUI

struct SleepNowView: View {
    @EnvironmentObject var sleepStore: SleepDataStore
    @EnvironmentObject var healthStore: HealthKitService
    @StateObject private var trackingManager = TrackingManager()

    @State private var alarmEnabled = true
    @State private var wakeTime = Calendar.current.date(
        bySettingHour: 7, minute: 0, second: 0, of: Date()
    ) ?? Date()

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                RadialGradient(
                    colors: [Color(hex: "#1a2560"), Color("BackgroundPrimary")],
                    center: .init(x: 0.5, y: 0.25),
                    startRadius: 0,
                    endRadius: 400
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        // Time display
                        timeDisplay

                        // Moon animation
                        MoonView(isTracking: trackingManager.isTracking)

                        // Status
                        statusSection

                        // Alarm row
                        alarmRow

                        // Action buttons
                        actionButtons
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
        .onReceive(trackingManager.$completedSession) { session in
            guard let session = session else { return }
            sleepStore.add(session: session)
            Task { try? await healthStore.writeSleepSession(session) }
        }
    }

    // MARK: Subviews

    private var timeDisplay: some View {
        VStack(spacing: 6) {
            Text("SLEEP TRACKING")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.35))
                .tracking(2)

            Text(Date(), style: .time)
                .font(.system(size: 52, weight: .thin, design: .monospaced))
                .foregroundColor(.white)

            Text(Date(), style: .date)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.35))
        }
        .padding(.top, 16)
    }

    private var statusSection: some View {
        VStack(spacing: 6) {
            Text(trackingManager.isProcessing ? "Analyzing sleep…"
               : trackingManager.isTracking   ? "Tracking in progress"
               : "Ready to track sleep")
                .font(.system(size: 18, weight: .light))
                .foregroundColor(.white.opacity(0.85))

            Text(trackingManager.isTracking
                 ? "Apple Watch Series 1 · \(trackingManager.elapsedString)"
                 : "Apple Watch Series 1 detected")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.35))
        }
    }

    private var alarmRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Wake-up alarm")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                DatePicker("", selection: $wakeTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .accentColor(Color("AccentBlue"))
            }
            Spacer()
            Toggle("", isOn: $alarmEnabled)
                .labelsHidden()
                .tint(Color("AccentBlue"))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.07))
        )
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                if trackingManager.isTracking {
                    trackingManager.stopTracking(healthStore: healthStore)
                } else {
                    trackingManager.startTracking()
                }
            } label: {
                Group {
                    if trackingManager.isProcessing {
                        HStack(spacing: 10) {
                            ProgressView().tint(.white)
                            Text("Analyzing…")
                        }
                    } else {
                        Text(trackingManager.isTracking ? "Stop Tracking" : "Start Sleep Tracking")
                    }
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(trackingManager.isProcessing ? Color.gray.opacity(0.4)
                            : trackingManager.isTracking   ? Color("AccentGreen").opacity(0.85)
                            : Color("AccentBlue"))
                )
            }
            .disabled(trackingManager.isProcessing)

            Button {
                // Navigate to schedule settings
            } label: {
                Text("Adjust bedtime schedule")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white.opacity(0.07))
                    )
            }
        }
    }
}

// MARK: - Moon View

struct MoonView: View {
    let isTracking: Bool
    @State private var pulsing = false

    var body: some View {
        ZStack {
            ForEach([0, 1, 2], id: \.self) { i in
                Circle()
                    .fill(Color("AccentBlue").opacity(isTracking ? 0.15 : 0.06))
                    .frame(width: CGFloat(100 + i * 30), height: CGFloat(100 + i * 30))
                    .scaleEffect(pulsing ? 1.05 : 0.97)
                    .animation(
                        isTracking
                            ? .easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(Double(i) * 0.4)
                            : .default,
                        value: pulsing
                    )
            }

            Text("🌙")
                .font(.system(size: 42))
        }
        .onAppear { pulsing = true }
        .onChange(of: isTracking) { _ in pulsing = true }
    }
}

// MARK: - Tracking Manager

import Combine

@MainActor
class TrackingManager: ObservableObject {
    @Published var isTracking  = false
    @Published var isProcessing = false   // true while classifying after stop
    @Published var elapsedString = "0:00"
    @Published var completedSession: SleepSession?

    private var startDate: Date?
    private var timer: Timer?
    private let motionService = WatchMotionBridge()

    func startTracking() {
        completedSession = nil
        startDate = Date()
        isTracking = true
        isProcessing = false
        motionService.start()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let start = self.startDate else { return }
            let elapsed = Int(Date().timeIntervalSince(start))
            let h = elapsed / 3600
            let m = (elapsed % 3600) / 60
            let s = elapsed % 60
            let str = h > 0
                ? "\(h):\(String(format: "%02d", m)):\(String(format: "%02d", s))"
                : "\(m):\(String(format: "%02d", s))"
            // Timer fires on main RunLoop so this is safe without an extra Task hop
            self.elapsedString = str
        }
    }

    func stopTracking(healthStore: HealthKitService) {
        guard let start = startDate else { return }
        isTracking  = false
        isProcessing = true
        timer?.invalidate()
        timer = nil
        startDate = nil
        let rawSamples = motionService.stop()
        let end = Date()

        // Classification can take seconds on a full night of 10 Hz samples —
        // run it off the main actor so the UI stays responsive.
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let segments  = SleepStageClassifier().classify(
                samples: rawSamples, sessionStart: start, sessionEnd: end)
            let hrSamples = await healthStore.fetchHeartRate(from: start, to: end)
            let session   = SleepSession(id: UUID(),
                                         startDate: start, endDate: end,
                                         segments: segments,
                                         heartRateSamples: hrSamples)
            await MainActor.run {
                self.isProcessing   = false
                self.completedSession = session
            }
        }
    }
}
