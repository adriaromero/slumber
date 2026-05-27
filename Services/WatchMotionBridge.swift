import WatchConnectivity

class WatchMotionBridge: NSObject, WCSessionDelegate {
    private var motionSamples: [MotionSample] = []

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func start() {
        motionSamples.removeAll()
        send(["command": "startTracking"])
    }

    func stop() -> [MotionSample] {
        send(["command": "stopTracking"])
        return motionSamples
    }

    private func send(_ message: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        guard s.activationState == .activated, s.isReachable else { return }
        s.sendMessage(message, replyHandler: nil, errorHandler: nil)
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
