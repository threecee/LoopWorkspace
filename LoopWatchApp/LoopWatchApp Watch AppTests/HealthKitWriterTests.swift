import XCTest
import HealthKit
@testable import LoopWatchApp_Watch_App

final class HealthKitWriterTests: XCTestCase {

    func testWriteSuccess() async throws {
        let store = MockHealthStore()
        store.saveResult = .success(())
        let writer = HealthKitWriter(store: store)

        let reading = GlucoseReading(valueMgDl: 120, timestamp: Date(), trend: .flat, sensorId: "X")
        try await writer.write(reading)

        XCTAssertEqual(store.savedSamples.count, 1)
        let sample = store.savedSamples[0] as? HKQuantitySample
        XCTAssertNotNil(sample)
        XCTAssertEqual(sample?.quantity.doubleValue(for: HKUnit(from: "mg/dL")), 120)
    }

    func testWriteAuthDeniedThrows() async {
        let store = MockHealthStore()
        store.saveResult = .failure(NSError(domain: HKErrorDomain, code: HKError.errorAuthorizationDenied.rawValue))
        let writer = HealthKitWriter(store: store)

        let reading = GlucoseReading(valueMgDl: 120, timestamp: Date(), trend: .flat, sensorId: "X")
        do {
            try await writer.write(reading)
            XCTFail("expected error")
        } catch {
            // Expected
        }
    }

    func testRequestAuthorization() async throws {
        let store = MockHealthStore()
        store.authResult = .success(())
        let writer = HealthKitWriter(store: store)

        try await writer.requestAuthorization()
        XCTAssertEqual(store.requestedTypes.count, 1)
    }
}

// Minimal mock conforming to the protocol we define on HealthKitWriter.
final class MockHealthStore: HealthStoreProtocol {
    var savedSamples: [HKSample] = []
    var requestedTypes: Set<HKSampleType> = []
    var saveResult: Result<Void, Error> = .success(())
    var authResult: Result<Void, Error> = .success(())

    func save(_ sample: HKSample) async throws {
        savedSamples.append(sample)
        try saveResult.get()
    }

    func requestAuthorization(toShare: Set<HKSampleType>, read: Set<HKObjectType>) async throws {
        requestedTypes.formUnion(toShare)
        try authResult.get()
    }
}
