import Foundation
import SwiftUI
import Combine

/// Observable state shared between the app and ContentView.
final class GlucoseViewModel: ObservableObject {
    @Published var latest: GlucoseReading?
    @Published var recent: [GlucoseReading] = []
    @Published var statusMessage: String = "Waiting for sensor…"

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
