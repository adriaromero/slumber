import SwiftUI

struct ContentView: View {
    @EnvironmentObject var healthStore: HealthKitService
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Today", systemImage: "house.fill")
                }
                .tag(0)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "chart.bar.fill")
                }
                .tag(1)

            SleepNowView()
                .tabItem {
                    Label("Sleep", systemImage: "moon.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .accentColor(Color("AccentBlue"))
        .onAppear {
            healthStore.requestAuthorization()
        }
    }
}
