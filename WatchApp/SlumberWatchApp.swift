// WatchApp/SlumberWatchApp.swift
// Target: watchOS 7.0+ build target (Series 1 hardware maxes at watchOS 4,
// but modern Xcode requires watchOS 7 minimum deployment target).
// Background execution uses HKWorkoutSession — same workaround, still required
// on all watchOS versions for non-workout apps that need extended runtime.

import SwiftUI
import WatchKit
import Foundation
import CoreMotion
import HealthKit
import WatchConnectivity

// MARK: - App Entry

@main
struct SlumberWatchApp: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        WatchSessionManager.shared.activateSession()
    }
}

// MARK: - Motion Sampler

/// Samples CMDeviceMotion at ~10 Hz during the sleep window.
/// Keeps a rolling buffer; flushes to the phone every 5 minutes via WCSession.
class WatchMotionSampler: NSObject {
    static let shared = WatchMotionSampler()

    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private var buffer: [[String: Any]] = []
    private let flushInterval: TimeInterval = 300  // 5 minutes
    private var flushTimer: Timer?
    private var workoutSession: HKWorkoutSession?
    private let healthStore = HKHealthStore()

    // MARK: Start

    func startSampling() {
        startWorkoutSession()   // keeps Watch awake on watchOS 4
        startMotion()
        scheduleFlush()
    }

    // MARK: Workout session (background execution hack for watchOS 4)

    private func startWorkoutSession() {
        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .unknown

        do {
            workoutSession = try HKWorkoutSession(configuration: config)
            workoutSession?.delegate = self
            healthStore.start(workoutSession!)
        } catch {
            print("Slumber: Could not start HKWorkoutSession — \(error)")
        }
    }

    // MARK: CoreMotion

    private func startMotion() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.1  // 10 Hz

        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            guard let self = self, let motion = motion, error == nil else { return }

            let acc = motion.userAcceleration
            let magnitude = sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z)

            let sample: [String: Any] = [
                "ts": Date().timeIntervalSince1970,
                "mag": magnitude
            ]

            DispatchQueue.main.async {
                self.buffer.append(sample)
                // Trim buffer to last 10 min max (6000 samples at 10 Hz)
                if self.buffer.count > 6000 {
                    self.buffer.removeFirst(self.buffer.count - 6000)
                }
            }
        }
    }

    // MARK: Flush

    private func scheduleFlush() {
        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { [weak self] _ in
            self?.flush()
        }
    }

    func flush() {
        guard !buffer.isEmpty else { return }
        let toSend = buffer
        buffer.removeAll()
        WatchSessionManager.shared.send(motionBatch: toSend)
    }

    // MARK: Stop

    func stopSampling() {
        flushTimer?.invalidate()
        flushTimer = nil
        flush()  // send remaining samples
        motionManager.stopDeviceMotionUpdates()
        if let session = workoutSession {
            healthStore.end(session)
        }
        workoutSession = nil
    }
}

// MARK: - WCSession Manager (Watch side)

class WatchSessionManager: NSObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    private var session: WCSession?

    func activateSession() {
        guard WCSession.isSupported() else { return }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    func send(motionBatch: [[String: Any]]) {
        guard let session = session, session.isReachable else {
            // Phone not reachable — queue in transferUserInfo for later delivery
            WCSession.default.transferUserInfo(["motionBatch": motionBatch])
            return
        }
        session.sendMessage(["motionBatch": motionBatch], replyHandler: nil) { error in
            print("Slumber Watch: WCSession send error — \(error)")
        }
    }

    // MARK: Tracking commands from phone

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let command = message["command"] as? String {
            DispatchQueue.main.async {
                switch command {
                case "startTracking": WatchMotionSampler.shared.startSampling()
                case "stopTracking":  WatchMotionSampler.shared.stopSampling()
                default: break
                }
            }
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}

// MARK: - HKWorkoutSessionDelegate (WatchMotionSampler)

extension WatchMotionSampler: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {}

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Slumber: HKWorkoutSession failed — \(error)")
    }
}
