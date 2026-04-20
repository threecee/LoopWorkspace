//
//  SmokeTests.swift
//  WatchOSSmokeTest Watch App
//
//  Phase 5: Link-time smoke test proving LoopKit, OmniBLE, and G7SensorKit
//  link cleanly on watchOS. No BLE, no HealthKit, no runtime behavior.
//

import LoopKit
import OmniBLE
import G7SensorKit

/// Forces symbol resolution of a LoopKit public type at link time.
/// Uses GlucoseTrend — a pure-Swift enum with no iOS-only dependencies.
func smokeTestLoopKit() -> String {
    let trend = GlucoseTrend.flat
    return "GlucoseTrend.\(trend)"
}

/// Forces symbol resolution of a LoopAlgorithm type at link time.
/// LoopAlgorithm is compiled into LoopKit (not a separate module); types
/// are accessed via `import LoopKit`. Uses LoopAlgorithmSettings, a public
/// struct defined in LoopKit/LoopKit/LoopAlgorithm/.
func smokeTestAlgorithm() -> String {
    return String(describing: LoopAlgorithmSettings.self)
}

/// Forces symbol resolution of an OmniBLE public type at link time.
/// Does NOT instantiate OmniBLEPumpManager (would attempt BLE activity);
/// merely resolves its metatype.
func smokeTestOmniBLE() -> String {
    return String(describing: OmniBLEPumpManager.self)
}

/// Forces symbol resolution of a G7SensorKit public type at link time.
/// Does NOT instantiate G7CGMManager; merely resolves its metatype.
func smokeTestG7() -> String {
    return String(describing: G7CGMManager.self)
}
