import SwiftUI
import WatchKit
import Combine

@main
struct LoopWatchAppApp: App {
    @WKApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = GlucoseViewModel()
    private let reader = GlucoseReader()
    private let writer = HealthKitWriter()
    private let runtime = ExtendedRuntimeCoordinator()

    // B.2.c: phone↔watch coordinator. Stored as a property so its lifetime
    // matches the App's. Wired into viewModel.phoneConnected via a Combine
    // sink in `bootstrap()`.
    @State private var phoneWatchCoordinator: PhoneWatchSessionCoordinator?
    @State private var phoneWatchCancellables = Set<AnyCancellable>()

    // App Group identifier — must match Loop iOS's App Group. Stand-in value
    // per user instruction for B.2.a; real Loop iOS bundle may differ. If so,
    // adjust this single line.
    private let appGroupID = "group.com.threecee.loopGroup"

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .task { await bootstrap() }
                .onChange(of: scenePhase) { _, newPhase in
                    runtime.onScenePhaseChange(newPhase)
                }
        }
    }

    private func bootstrap() async {
        // B.2.c: start phone↔watch coordinator and wire its isConnected state
        // into viewModel.phoneConnected. Done first — independent of G7
        // bootstrap, so the phone-connection subtitle surfaces even before
        // the sensor handshake.
        await MainActor.run {
            let coordinator = PhoneWatchSessionCoordinator(
                transport: WCSessionPhoneWatchTransport()
            )
            coordinator.$lastHeartbeatReceivedAt
                .receive(on: DispatchQueue.main)
                .sink { _ in
                    viewModel.phoneConnected = coordinator.isConnected
                }
                .store(in: &phoneWatchCancellables)
            coordinator.start()
            phoneWatchCoordinator = coordinator
        }

        // 1. HealthKit auth
        do { try await writer.requestAuthorization() }
        catch {
            viewModel.setStatus("HealthKit auth denied")
            return
        }

        // 2. Load shared state from App Group UserDefaults
        guard let bridge = SharedStateBridge.forAppGroup(appGroupID),
              let rawState = bridge.loadG7RawState() else {
            viewModel.setStatus("Pair G7 in Loop on iPhone first")
            return
        }

        // 3. Attach GlucoseReader to a G7CGMManager reconstructed from rawState
        if !reader.attach(rawState: rawState) {
            viewModel.setStatus("Couldn't init G7 from shared state")
            return
        }

        // 4. Prime cached readings so UI isn't blank
        var cache = GlucoseCache(fileURL: GlucoseCache.defaultURL)
        viewModel.recent = cache.readings
        viewModel.latest = cache.readings.last

        // 5. Consume readings forever
        for await reading in reader.readings {
            viewModel.ingest(reading)
            try? cache.append(reading)
            do { try await writer.write(reading) }
            catch { /* log-only for now; auth rejection is the main failure mode */ }
        }
    }
}

/// Handles watchOS background-refresh tasks. `G7CGMManager` maintains its own
/// BLE connection in background (via the `bluetooth-central` background mode);
/// our job in `handle(_:)` is mainly to re-schedule the next refresh wake-up so
/// the OS keeps us alive if BLE delivery lapses.
final class AppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            if let refreshTask = task as? WKApplicationRefreshBackgroundTask {
                scheduleNextRefresh()
                refreshTask.setTaskCompletedWithSnapshot(false)
            } else {
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    func applicationDidFinishLaunching() {
        scheduleNextRefresh()
    }

    private func scheduleNextRefresh() {
        let next = Date().addingTimeInterval(10 * 60)
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: next,
            userInfo: nil
        ) { error in
            if let error { NSLog("scheduleBackgroundRefresh error: \(error)") }
        }
    }
}
