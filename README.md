# Slumber — Sleep Monitor for Apple Watch Series 1

A SwiftUI sleep tracking app for iPhone + Apple Watch Series 1.

## Project Structure

```
Slumber/
├── App/
│   ├── SlumberApp.swift          # @main entry point
│   └── ContentView.swift         # TabView root
│
├── Models/
│   └── SleepModels.swift         # SleepSession, SleepSegment, SleepStage, SleepDataStore
│
├── Services/
│   ├── HealthKitService.swift    # HealthKit read/write (HR, sleep analysis, steps)
│   └── SleepStageClassifier.swift# Accelerometer → sleep stage inference
│
├── Views/
│   ├── Dashboard/
│   │   └── DashboardView.swift   # Today tab: score ring, hypnogram, HR chart
│   ├── History/
│   │   └── HistoryView.swift     # 7-day bar chart + session list + detail
│   ├── SleepNow/
│   │   └── SleepNowView.swift    # Start/stop tracking, alarm, moon animation
│   └── Settings/
│       └── SettingsView.swift    # Device, tracking config, notifications
│
└── WatchApp/
    └── SlumberWatchApp.swift     # watchOS 4 extension + CoreMotion sampler + WCSession
```

## Xcode Setup

1. Create a new **iOS App** project in Xcode 15+, Swift, SwiftUI lifecycle.
2. Add a **watchOS App** target (File → New Target → watchOS App).
   - Set deployment target to **watchOS 4.0** (Series 1 maximum).
3. Copy source files into their respective targets.
4. Add **HealthKit** capability to both the iOS and watchOS targets.
5. Add **Background Modes** → `workout-processing` to the watchOS target.
6. Add usage strings to `Info.plist`:
   - `NSHealthShareUsageDescription`
   - `NSHealthUpdateUsageDescription`
   - `NSMotionUsageDescription`

## Asset Catalog Colors

Add these to `Assets.xcassets`:

| Name             | Light              | Dark               |
|------------------|--------------------|--------------------|
| BackgroundPrimary| #0a0c14            | #0a0c14            |
| AccentBlue       | #4B6FFF            | #4B6FFF            |
| AccentPurple     | #8B5CF6            | #8B5CF6            |
| AccentGreen      | #06D6A0            | #06D6A0            |
| AccentAmber      | #FFAA2B            | #FFAA2B            |
| AccentRed        | #FF6B6B            | #FF6B6B            |

## Apple Watch Series 1 Constraints

| Feature              | Status on Series 1                          |
|----------------------|---------------------------------------------|
| Sleep tracking app   | Not supported natively (maxes at watchOS 4) |
| Accelerometer        | ✅ Available via CoreMotion                  |
| Heart rate (cont.)   | ⚠️ Periodic only — no continuous monitoring  |
| Blood oxygen (SpO2)  | ❌ Not available (Series 6+)                 |
| Background execution | Requires HKWorkoutSession workaround        |
| Always-on display    | ❌ Not available (Series 5+)                 |

## Sleep Stage Algorithm

```
Raw accelerometer @ 10 Hz
        ↓
  1-minute epochs
        ↓
  Activity score (mean |Δmagnitude|)
        ↓
  Threshold classification
    ≥0.18g → Awake
    ≥0.06g → Light
     <0.06g → Deep
        ↓
  5-epoch median smoothing
        ↓
  REM injection (90-min cycle heuristic)
        ↓
  SleepSegment array → SleepSession
```

## Data Flow

```
Apple Watch Series 1
  CMMotionManager (10 Hz accel)
        ↓ WCSession (every 5 min)
iPhone App
  WatchMotionBridge
        ↓
  SleepStageClassifier
        ↓
  SleepSession → SleepDataStore (UserDefaults)
        ↓
  HealthKitService.writeSleepSession()
        ↓
  Apple Health
```
