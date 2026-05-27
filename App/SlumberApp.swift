import SwiftUI

@main
struct SlumberApp: App {
    @StateObject private var healthStore = HealthKitService()
    @StateObject private var sleepStore = SleepDataStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthStore)
                .environmentObject(sleepStore)
                .preferredColorScheme(.dark)
        }
    }
}
