import WatchConnectivity

class WatchMotionBridge: NSObject, WCSessionDelegate {
    private var motionSamples: [MotionSample] = []

    func start() {
        motionSamples.removeAll()
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        if s.activationState != .activated { s.activate() }
        s.sendMessage(["command": "startTracking"], replyHandler: nil)
    }

    func stop() -> [MotionSample] {
        WCSession.default.sendMessage(["command": "stopTracking"], replyHandler: nil)
        return motionSamples
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let batch = message["motionBatch"] as? [[String: Any]] {
            let parsed = parse(batch)
            DispatchQueue.main.async { self.motionSamples.append(contentsOf: parsed) }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        if let batch = userInfo["motionBatch"] as? [[String: Any]] {
            let parsed = parse(batch)
            DispatchQueue.main.async { self.motionSamples.append(contentsOf: parsed) }
        }
    }

    private func parse(_ batch: [[String: Any]]) -> [MotionSample] {
        batch.compactMap { dict in
            guard let ts = dict["ts"] as? Double, let mag = dict["mag"] as? Double else { return nil }
            return MotionSample(timestamp: Date(timeIntervalSince1970: ts), magnitude: mag)
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
