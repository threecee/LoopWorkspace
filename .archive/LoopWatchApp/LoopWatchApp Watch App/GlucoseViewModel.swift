import Foundation
import SwiftUI
import Combine
import OmniBLE

/// Observable state shared between the app and ContentView.
final class GlucoseViewModel: ObservableObject {
    @Published var latest: GlucoseReading?
    @Published var recent: [GlucoseReading] = []
    @Published var statusMessage: String = "Waiting for sensor…"
    /// B.2.c: phone↔watch connection visibility on the watch face.
    @Published var phoneConnected: Bool = false
    /// B.2.d: bonding-handoff state visibility (badge above glucose display).
    @Published var handoffState: HandoffState = .phoneDriver

    func ingest(_ reading: GlucoseReading) {
        latest = reading
        recent.append(reading)
        if recent.count > GlucoseCache.defaultCapacity {
            recent.removeFirst(recent.count - GlucoseCache.defaultCapacity)
        }
    }

    func setStatus(_ message: String) {
        statusMessage = message
    }
}
