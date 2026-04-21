import Foundation
import HealthKit

/// Narrow protocol over HKHealthStore to keep HealthKitWriter testable
/// without depending on the concrete HealthKit sandbox.
protocol HealthStoreProtocol {
    func save(_ sample: HKSample) async throws
    func requestAuthorization(toShare: Set<HKSampleType>, read: Set<HKObjectType>) async throws
}

extension HKHealthStore: HealthStoreProtocol {
    func save(_ sample: HKSample) async throws {
        try await saveOne(sample)
    }

    private func saveOne(_ sample: HKSample) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.save([sample]) { success, error in
                if let error { cont.resume(throwing: error); return }
                if !success { cont.resume(throwing: NSError(domain: HKErrorDomain, code: -1)); return }
                cont.resume(returning: ())
            }
        }
    }

    func requestAuthorization(toShare: Set<HKSampleType>, read: Set<HKObjectType>) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.requestAuthorization(toShare: toShare, read: read) { success, error in
                if let error { cont.resume(throwing: error); return }
                if !success { cont.resume(throwing: NSError(domain: HKErrorDomain, code: HKError.errorAuthorizationDenied.rawValue)); return }
                cont.resume(returning: ())
            }
        }
    }
}

/// Writes glucose readings to HealthKit.
struct HealthKitWriter {
    static let glucoseType = HKQuantityType(.bloodGlucose)
    static let mgDL = HKUnit(from: "mg/dL")

    private let store: HealthStoreProtocol

    init(store: HealthStoreProtocol = HKHealthStore()) {
        self.store = store
    }

    /// Requests write authorization for blood glucose. Safe to call multiple times;
    /// only prompts the user the first time.
    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [Self.glucoseType], read: [Self.glucoseType])
    }

    /// Writes a single glucose reading. The sensor ID is included in metadata
    /// so future reads can distinguish readings from different sensors.
    func write(_ reading: GlucoseReading) async throws {
        let quantity = HKQuantity(unit: Self.mgDL, doubleValue: reading.valueMgDl)
        let sample = HKQuantitySample(
            type: Self.glucoseType,
            quantity: quantity,
            start: reading.timestamp,
            end: reading.timestamp,
            metadata: [
                HKMetadataKeyWasUserEntered: false,
                "com.threecee.loop.sensorId": reading.sensorId,
                "com.threecee.loop.trend": reading.trend.rawValue,
            ]
        )
        try await store.save(sample)
    }
}
