import IntervalCore
import SwiftUI

/// Dienste, die es nur einmal in der App gibt.
final class AppServices: ObservableObject {
    let speech = SpeechService()
    let location = LocationService()
}

@main
struct IntervalltrainerApp: App {
    @StateObject private var planStore = PlanStore()
    @StateObject private var settings = SettingsStore()
    @StateObject private var services = AppServices()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            PlanListView()
                .environmentObject(planStore)
                .environmentObject(settings)
                .environmentObject(services)
                .onAppear {
                    applyIdleTimer()
                }
                .onChange(of: settings.keepScreenOn) {
                    applyIdleTimer()
                }
                .onChange(of: scenePhase) {
                    applyIdleTimer()
                }
        }
    }

    /// Verhindert die automatische Bildschirmsperre, solange die App offen ist.
    private func applyIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = settings.keepScreenOn
    }
}
