import SwiftUI
import WatchKit

@main
struct LoopWatchAppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = GlucoseViewModel()
    private let reader = GlucoseReader()
    private let writer = HealthKitWriter()
    private let runtime = ExtendedRuntimeCoordinator()

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
