import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var healthStore: HealthKitService
    @EnvironmentObject var sleepStore: SleepDataStore

    @State private var showResetConfirm = false

    @AppStorage("smartWakeEnabled")   private var smartWakeEnabled   = true
    @AppStorage("morningNotification") private var morningNotif      = false
    @AppStorage("bedtimeReminder")    private var bedtimeReminder    = true
    @AppStorage("healthKitSync")      private var healthKitSync      = true
    @AppStorage("sleepWindowStart")   private var sleepWindowStart   = "22:00"
    @AppStorage("sleepWindowEnd")     private var sleepWindowEnd     = "08:00"
    @AppStorage("motionSensitivity")  private var motionSensitivity  = "High"

    @State private var showAbout = false

    var body: some View {
        NavigationView {
            List {
                // MARK: Device
                Section("Device") {
                    HStack {
                        Label("Apple Watch", systemImage: "applewatch")
                        Spacer()
                        Text("Series 1 · Connected")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }

                    Toggle(isOn: $healthKitSync) {
                        Label("HealthKit sync", systemImage: "heart.fill")
                    }
                    .tint(Color("AccentBlue"))
                }

                // MARK: Tracking
                Section("Tracking") {
                    HStack {
                        Label("Sleep window", systemImage: "moon.stars.fill")
                        Spacer()
                        Text("\(sleepWindowStart) – \(sleepWindowEnd)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Toggle(isOn: $smartWakeEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Smart wake alarm")
                            Text("Wake during light sleep stage")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(Color("AccentBlue"))

                    Picker(selection: $motionSensitivity) {
                        Text("Low").tag("Low")
                        Text("Medium").tag("Medium")
                        Text("High").tag("High")
                    } label: {
                        Label("Motion sensitivity", systemImage: "waveform.path")
                    }
                }

                // MARK: Notifications
                Section("Notifications") {
                    Toggle(isOn: $morningNotif) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Morning summary")
                            Text("Push notification with sleep score")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(Color("AccentBlue"))

                    Toggle(isOn: $bedtimeReminder) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bedtime reminder")
                            Text("30 minutes before target sleep")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(Color("AccentBlue"))
                }

                // MARK: About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Button("Privacy Policy") {
                        // open privacy URL
                    }

                    Button("Load sample data") {
                        sleepStore.loadSampleData()
                    }
                    .foregroundColor(Color("AccentBlue"))

                    Button("Reset all data", role: .destructive) {
                        showResetConfirm = true
                    }
                    .confirmationDialog("Delete all sleep sessions?",
                                        isPresented: $showResetConfirm,
                                        titleVisibility: .visible) {
                        Button("Delete all data", role: .destructive) {
                            sleepStore.sessions = []
                            sleepStore.latestSession = nil
                            UserDefaults.standard.removeObject(forKey: "slumber.sessions")
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color("BackgroundPrimary"))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
